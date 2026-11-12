using Dapper;
using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Api.Endpoints;

public static class AuthEndpoints
{
    public static IEndpointRouteBuilder MapAuthEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/auth").WithTags("Auth");

        group.MapPost("/otp/request", async (
            RequestOtpRequest request, OtpService otp, IConfiguration config) =>
        {
            if (string.IsNullOrWhiteSpace(request.Phone) || request.Phone.Length < 8)
                return Results.BadRequest(new { error = "Số điện thoại không hợp lệ" });

            try
            {
                var (code, expiresIn) = otp.Issue(request.Phone);
                var expose = config.GetValue("Auth:ExposeOtp", true);
                return Results.Ok(new RequestOtpResponse(expiresIn, expose ? code : null));
            }
            catch (InvalidOperationException)
            {
                return Results.Json(new { error = "Bạn đã yêu cầu OTP quá nhiều lần. Thử lại sau 1 giờ." },
                    statusCode: StatusCodes.Status429TooManyRequests);
            }
        });

        group.MapPost("/otp/verify", async (
            VerifyOtpRequest request, OtpService otp, TokenService tokens, Db db,
            CancellationToken ct) =>
        {
            var phone = OtpService.Normalize(request.Phone);
            if (!otp.Verify(phone, request.Code))
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
            return Results.Ok(new AuthResponse(token, user.ToUser()));
        });

        return app;
    }
}
