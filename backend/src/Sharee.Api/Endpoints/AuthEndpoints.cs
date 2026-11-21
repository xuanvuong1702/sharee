using System.Security.Cryptography;
using System.Text;
using Dapper;
using Microsoft.AspNetCore.RateLimiting;
using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Api.Endpoints;

public static class AuthEndpoints
{
    public static IEndpointRouteBuilder MapAuthEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/auth").WithTags("Auth").RequireRateLimiting("auth");

        group.MapPost("/otp/request", async (
            RequestOtpRequest request, OtpService otp, ISmsSender sms, IConfiguration config,
            ILoggerFactory loggerFactory, OtpRateGuard guard, HttpContext http, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(request.Phone) || request.Phone.Length < 8)
                return Results.BadRequest(new { error = "Số điện thoại không hợp lệ" });
            if (!guard.Allow(http.Connection.RemoteIpAddress?.ToString()))
                return Results.Json(new { error = "Quá nhiều yêu cầu OTP. Thử lại sau." },
                    statusCode: StatusCodes.Status429TooManyRequests);

            try
            {
                var (code, expiresIn) = await otp.IssueAsync(
                    request.Phone, http.Connection.RemoteIpAddress?.ToString(), ct);
                await sms.SendAsync(OtpService.Normalize(request.Phone),
                    $"Sharee: ma xac thuc {code}, hieu luc 5 phut.", ct);
                var expose = config.GetValue("Auth:ExposeOtp", false);
                return Results.Ok(new RequestOtpResponse(expiresIn, expose ? code : null));
            }
            catch (OtpRateLimitException ex)
            {
                http.Response.Headers.RetryAfter = ex.RetryAfterSeconds.ToString();
                return Results.Json(new { error = "Bạn đã yêu cầu OTP quá nhiều lần. Thử lại sau." },
                    statusCode: StatusCodes.Status429TooManyRequests);
            }
            catch (ArgumentException ex)
            {
                return Results.BadRequest(new { error = ex.Message });
            }
            catch (Exception ex)
            {
                loggerFactory.CreateLogger("Auth").LogError(ex, "Cannot send OTP SMS");
                return Results.Json(new { error = "Không gửi được SMS xác thực. Thử lại sau." },
                    statusCode: StatusCodes.Status502BadGateway);
            }
        });

        group.MapPost("/otp/verify", async (
            VerifyOtpRequest request, OtpService otp, TokenService tokens,
            RefreshTokenService refreshTokens, Db db, CancellationToken ct) =>
        {
            var phone = OtpService.Normalize(request.Phone);
            if (!await otp.VerifyAsync(phone, request.Code ?? "", ct))
                return Results.BadRequest(new { error = "Mã OTP không đúng hoặc đã hết hạn" });

            await using var conn = await db.OpenAsync(ct);
            var user = await conn.QuerySingleOrDefaultAsync<UserRow>(
                "select * from users where phone = @phone", new { phone });

            if (user is null)
            {
                var name = "Người dùng " + phone[^4..];
                user = await conn.QuerySingleAsync<UserRow>("""
                    insert into users (phone, full_name, verified_level)
                    values (@phone, @name, 1)
                    returning *
                    """, new { phone, name });
            }

            if (user.Status == "blocked")
                return Results.Json(new { error = "Tài khoản đã bị khoá" }, statusCode: 403);

            var token = tokens.CreateToken(user.Id, user.Phone, user.FullName, user.Role);
            var refresh = await refreshTokens.IssueAsync(user.Id, ct);
            return Results.Ok(new AuthResponse(token, refresh, user.ToUser()));
        });

        group.MapPost("/refresh", async (
            RefreshRequest request, RefreshTokenService refreshTokens, TokenService tokens,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(request.RefreshToken))
                return Results.BadRequest(new { error = "Thiếu refresh token" });

            var rotated = await refreshTokens.RotateAsync(request.RefreshToken, ct);
            if (rotated is null)
                return Results.Json(new { error = "Refresh token không hợp lệ hoặc đã hết hạn" },
                    statusCode: StatusCodes.Status401Unauthorized);

            var (user, refresh) = rotated.Value;
            var access = tokens.CreateToken(user.Id, user.Phone, user.FullName, user.Role);
            return Results.Ok(new AuthResponse(access, refresh, user.ToUser()));
        });

        group.MapPost("/logout", async (
            RefreshRequest request, RefreshTokenService refreshTokens, CancellationToken ct) =>
        {
            if (!string.IsNullOrWhiteSpace(request.RefreshToken))
                await refreshTokens.RevokeAsync(request.RefreshToken, ct);
            return Results.Ok(new { status = "ok" });
        });

        group.MapPost("/bootstrap-admin", async (
            BootstrapAdminRequest request, HttpContext http, IConfiguration config,
            Db db, CancellationToken ct) =>
        {
            var expected = config["Bootstrap:Token"];
            if (string.IsNullOrWhiteSpace(expected)) return Results.NotFound();
            var provided = http.Request.Headers["X-Bootstrap-Token"].FirstOrDefault();
            if (string.IsNullOrWhiteSpace(provided) ||
                !CryptographicOperations.FixedTimeEquals(
                    Encoding.UTF8.GetBytes(provided), Encoding.UTF8.GetBytes(expected)))
            {
                return Results.Json(new { error = "Bootstrap token không hợp lệ" },
                    statusCode: StatusCodes.Status403Forbidden);
            }

            var phone = OtpService.Normalize(request.Phone ?? "");
            if (phone.Length < 9)
                return Results.BadRequest(new { error = "Số điện thoại không hợp lệ" });

            await using var conn = await db.OpenAsync(ct);
            var user = await conn.QuerySingleAsync<UserRow>("""
                insert into users (phone, full_name, role, verified_level)
                values (@phone, @name, 'admin', 3)
                on conflict (phone) do update set role = 'admin',
                    verified_level = greatest(users.verified_level, 3)
                returning *
                """, new { phone, name = request.FullName ?? "Quản trị viên" });
            return Results.Ok(new { status = "admin-ready", user = user.ToUser() });
        });

        return app;
    }
}
