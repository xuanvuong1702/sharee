using System.Text.RegularExpressions;
using Dapper;
using Microsoft.AspNetCore.Mvc;
using Npgsql;
using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Api.Endpoints;

public static partial class VerificationEndpoints
{
    [GeneratedRegex(@"^\d{9}$|^\d{12}$")]
    private static partial Regex IdNumberRegex();

    [GeneratedRegex(@"^[A-Za-z0-9]{6,20}$")]
    private static partial Regex VehicleRegistrationRegex();

    public static IEndpointRouteBuilder MapVerificationEndpoints(this IEndpointRouteBuilder app)
    {
        var me = app.MapGroup("/api/me/verification").RequireAuthorization().WithTags("Verification");

        me.MapGet("", async (HttpContext http, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            return Results.Ok(await GetStatusAsync(conn, http.User.GetUserId()));
        });

        me.MapPut("/profile", async (
            UpdateVerificationProfileRequest request, HttpContext http, Db db, CancellationToken ct) =>
        {
            var userId = http.User.GetUserId();
            var error = ValidateProfile(request, out var legalName, out var idNumber,
                out var licenseNumber, out var vehicleRegistration);
            if (error is not null) return Results.BadRequest(new { error });

            await using var conn = await db.OpenAsync(ct);
            var current = await conn.QuerySingleOrDefaultAsync<dynamic>(
                "select verification_status from users where id = @userId", new { userId });
            if (current is null) return Results.NotFound();
            var status = (string)current.verification_status;
            if (status is "pending" or "approved" or "suspended")
                return Results.Conflict(new { error = "Hồ sơ đang chờ duyệt hoặc đã xác thực, không thể sửa" });

            var duplicate = await conn.ExecuteScalarAsync<Guid?>("""
                select id from users
                where id <> @userId
                  and (id_number = @idNumber or license_number = @licenseNumber)
                limit 1
                """, new { userId, idNumber, licenseNumber });
            if (duplicate is not null)
                return Results.Conflict(new { error = "Số CCCD hoặc số GPLX đã được dùng bởi tài khoản khác" });

            await conn.ExecuteAsync("""
                update users set
                    legal_name = @legalName,
                    date_of_birth = @dateOfBirth,
                    id_number = @idNumber,
                    id_issued_at = @idIssuedAt,
                    id_expiry = @idExpiry,
                    license_number = @licenseNumber,
                    license_class = @licenseClass,
                    license_expiry = @licenseExpiry,
                    vehicle_registration = @vehicleRegistration,
                    insurance_expiry = @insuranceExpiry,
                    verification_status = 'draft',
                    verification_rejection_reason = null
                where id = @userId
                """, new
            {
                userId, legalName, idNumber, licenseNumber, vehicleRegistration,
                dateOfBirth = ToDateTime(request.DateOfBirth),
                idIssuedAt = ToDateTime(request.IdIssuedAt),
                idExpiry = ToDateTime(request.IdExpiry),
                licenseClass = request.LicenseClass.Trim().ToUpperInvariant(),
                licenseExpiry = ToDateTime(request.LicenseExpiry),
                insuranceExpiry = ToDateTime(request.InsuranceExpiry)
            });

            return Results.Ok(await GetStatusAsync(conn, userId));
        });

        me.MapPost("/documents/{type}", async (
            string type, [FromForm] IFormFile file, HttpContext http, Db db,
            VerificationStorage storage, CancellationToken ct) =>
        {
            if (!VerificationTypes.IsValid(type))
                return Results.BadRequest(new { error = "Loại giấy tờ không hợp lệ" });
            if (file is null || file.Length == 0)
                return Results.BadRequest(new { error = "Thiếu tệp" });

            var userId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            var status = await conn.ExecuteScalarAsync<string>(
                "select verification_status from users where id = @userId", new { userId });
            if (status is null) return Results.NotFound();
            if (status is "pending" or "approved" or "suspended")
                return Results.Conflict(new { error = "Không thể thay đổi giấy tờ khi hồ sơ đang chờ/đã duyệt" });

            StoredVerificationFile stored;
            try
            {
                stored = await storage.SaveAsync(userId, type, file, ct);
            }
            catch (InvalidOperationException ex)
            {
                return Results.BadRequest(new { error = ex.Message });
            }

            try
            {
                var old = await conn.ExecuteScalarAsync<string>(
                    "select stored_path from verification_documents where user_id = @userId and type = @type",
                    new { userId, type });
                await conn.ExecuteAsync("""
                    insert into verification_documents
                        (user_id, type, original_name, stored_path, mime_type, size_bytes, sha256)
                    values (@userId, @type, @originalName, @storedPath, @mimeType, @sizeBytes, @sha256)
                    on conflict (user_id, type) do update set
                        original_name = excluded.original_name,
                        stored_path = excluded.stored_path,
                        mime_type = excluded.mime_type,
                        size_bytes = excluded.size_bytes,
                        sha256 = excluded.sha256,
                        updated_at = now()
                    """, new { userId, type, stored.OriginalName, stored.StoredPath,
                    stored.MimeType, stored.SizeBytes, stored.Sha256 });
                storage.Delete(old);
            }
            catch
            {
                storage.Delete(stored.StoredPath);
                throw;
            }

            var doc = await conn.QuerySingleAsync<dynamic>(
                "select id, type, original_name, mime_type, size_bytes, created_at from verification_documents where user_id = @userId and type = @type",
                new { userId, type });
            return Results.Ok(MapDocument(doc));
        }).DisableAntiforgery();

        me.MapDelete("/documents/{type}", async (
            string type, HttpContext http, Db db, VerificationStorage storage, CancellationToken ct) =>
        {
            if (!VerificationTypes.IsValid(type))
                return Results.BadRequest(new { error = "Loại giấy tờ không hợp lệ" });
            var userId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            var status = await conn.ExecuteScalarAsync<string>(
                "select verification_status from users where id = @userId", new { userId });
            if (status is "pending" or "approved" or "suspended")
                return Results.Conflict(new { error = "Không thể thay đổi giấy tờ khi hồ sơ đang chờ/đã duyệt" });
            var path = await conn.ExecuteScalarAsync<string>(
                "delete from verification_documents where user_id = @userId and type = @type returning stored_path",
                new { userId, type });
            storage.Delete(path);
            return Results.Ok(new { status = "deleted" });
        });

        me.MapPost("/submit", async (HttpContext http, Db db, CancellationToken ct) =>
        {
            var userId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            var user = await conn.QuerySingleOrDefaultAsync<dynamic>(
                "select * from users where id = @userId", new { userId });
            if (user is null) return Results.NotFound();
            if ((string)user.verification_status == "pending")
                return Results.Conflict(new { error = "Hồ sơ đã được gửi và đang chờ duyệt" });
            if ((string)user.verification_status == "approved")
                return Results.Conflict(new { error = "Tài khoản đã được xác thực" });

            var profileError = ValidateStoredProfile(user);
            if (profileError is not null) return Results.BadRequest(new { error = profileError });
            var docs = (await conn.QueryAsync<string>(
                "select type from verification_documents where user_id = @userId", new { userId })).ToHashSet();
            var missing = VerificationTypes.RequiredForDriver.Where(t => !docs.Contains(t)).ToList();
            if (missing.Count > 0)
                return Results.BadRequest(new { error = "Thiếu giấy tờ", required = missing });

            await using var tx = await conn.BeginTransactionAsync(ct);
            await conn.ExecuteAsync("""
                update users set verification_status = 'pending',
                    verification_submitted_at = now(),
                    verification_rejection_reason = null
                where id = @userId
                """, new { userId }, tx);
            await conn.ExecuteAsync("""
                insert into verification_events (user_id, actor_id, action, detail)
                values (@userId, @userId, 'submitted', '{}'::jsonb)
                """, new { userId }, tx);
            var admins = await conn.QueryAsync<Guid>(
                "select id from users where role = 'admin' and status = 'active'", transaction: tx);
            foreach (var adminId in admins)
                await Notifier.NotifyAsync(conn, tx, adminId, "verification.submitted",
                    "Hồ sơ xác thực mới",
                    $"{user.full_name} vừa gửi hồ sơ tài xế để duyệt.");
            await tx.CommitAsync(ct);
            return Results.Ok(await GetStatusAsync(conn, userId));
        });

        var admin = app.MapGroup("/api/admin/verifications")
            .RequireAuthorization("admin").WithTags("AdminVerification");

        admin.MapGet("", async (Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var rows = await conn.QueryAsync<dynamic>("""
                select u.id as user_id, u.full_name, u.phone, u.verification_status,
                       u.verified_level, u.legal_name, u.id_number, u.license_number,
                       u.license_expiry, u.insurance_expiry, u.verification_submitted_at,
                       u.verification_expires_at,
                       (select count(*) from verification_documents d where d.user_id = u.id) as document_count
                from users u
                where u.verification_status <> 'unverified'
                order by case u.verification_status when 'pending' then 0 when 'rejected' then 1 else 2 end,
                         u.verification_submitted_at desc nulls last
                limit 200
                """);
            return Results.Ok(rows.Select(r => new VerificationQueueItemDto(
                (Guid)r.user_id, (string)r.full_name, (string)r.phone,
                (string)r.verification_status, (int)r.verified_level,
                (string?)r.legal_name, (string?)r.id_number, (string?)r.license_number,
                ToDateOnly(r.license_expiry),
                ToDateOnly(r.insurance_expiry),                (int)(long)r.document_count,
                DtoOrNull(r.verification_submitted_at),
                DtoOrNull(r.verification_expires_at))));
        });

        admin.MapGet("/{userId:guid}", async (Guid userId, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var exists = await conn.ExecuteScalarAsync<bool>(
                "select exists(select 1 from users where id = @userId)", new { userId });
            return exists ? Results.Ok(await GetStatusAsync(conn, userId)) : Results.NotFound();
        });

        admin.MapGet("/{userId:guid}/documents/{documentId:guid}", async (
            Guid userId, Guid documentId, Db db, VerificationStorage storage, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var doc = await conn.QuerySingleOrDefaultAsync<dynamic>("""
                select stored_path, original_name, mime_type from verification_documents
                where id = @documentId and user_id = @userId
                """, new { documentId, userId });
            if (doc is null) return Results.NotFound();
            var path = storage.Resolve((string)doc.stored_path);
            if (path is null || !File.Exists(path)) return Results.NotFound();
            return Results.File(path, (string)doc.mime_type, (string)doc.original_name,
                enableRangeProcessing: true);
        });

        admin.MapPost("/{userId:guid}/approve", async (
            Guid userId, ApproveVerificationRequest request, HttpContext http, Db db,
            CancellationToken ct) =>
        {
            if (userId == http.User.GetUserId())
                return Results.BadRequest(new { error = "Không thể tự duyệt hồ sơ của mình" });
            await using var conn = await db.OpenAsync(ct);
            var user = await conn.QuerySingleOrDefaultAsync<dynamic>(
                "select * from users where id = @userId", new { userId });
            if (user is null) return Results.NotFound();
            if ((string)user.verification_status != "pending")
                return Results.Conflict(new { error = "Hồ sơ không ở trạng thái chờ duyệt" });
            var profileError = ValidateStoredProfile(user);
            if (profileError is not null) return Results.BadRequest(new { error = profileError });

            var docs = (await conn.QueryAsync<string>(
                "select type from verification_documents where user_id = @userId", new { userId })).ToHashSet();
            if (VerificationTypes.RequiredForDriver.Any(t => !docs.Contains(t)))
                return Results.Conflict(new { error = "Hồ sơ chưa đủ giấy tờ bắt buộc" });

            var expiries = new List<DateOnly>();
            if (ToDateOnly(user.id_expiry) is { } idExp) expiries.Add(idExp);
            if (ToDateOnly(user.license_expiry) is { } licExp) expiries.Add(licExp);
            if (ToDateOnly(user.insurance_expiry) is { } insExp) expiries.Add(insExp);
            if (expiries.Count == 0)
                return Results.BadRequest(new { error = "Thiếu ngày hết hạn giấy tờ" });
            var maxExpiry = expiries.Min();
            DateOnly expires = request.ExpiresAt ?? maxExpiry;
            if (expires <= DateOnly.FromDateTime(DateTime.UtcNow))
                return Results.BadRequest(new { error = "Ngày hết hạn xác thực phải ở tương lai" });
            if (expires > maxExpiry)
                return Results.BadRequest(new { error = "Ngày hết hạn xác thực không được vượt quá hạn giấy tờ" });

            var expiresAt = new DateTimeOffset(expires.ToDateTime(TimeOnly.MaxValue), TimeSpan.Zero);
            await using var tx = await conn.BeginTransactionAsync(ct);
            await conn.ExecuteAsync("""
                update users set verification_status = 'approved',
                    verified_level = 3,
                    verification_expires_at = @expiresAt,
                    verification_reviewed_at = now(),
                    verification_rejection_reason = null
                where id = @userId
                """, new { userId, expiresAt }, tx);
            await conn.ExecuteAsync("""
                insert into verification_events (user_id, actor_id, action, detail)
                values (@userId, @adminId, 'approved', @detail::jsonb)
                """, new { userId, adminId = http.User.GetUserId(),
                detail = System.Text.Json.JsonSerializer.Serialize(new { expiresAt }) }, tx);
            await Notifier.NotifyAsync(conn, tx, userId, "verification.approved",
                "Hồ sơ tài xế đã được duyệt",
                $"Bạn đã được xác thực tài xế đến {expires:dd/MM/yyyy}.");
            await Audit.LogAsync(conn, tx, http.User.GetUserId(), "verification.approve",
                "user", userId.ToString(), new { expiresAt });
            await tx.CommitAsync(ct);
            return Results.Ok(await GetStatusAsync(conn, userId));
        });

        admin.MapPost("/{userId:guid}/reject", async (
            Guid userId, RejectVerificationRequest request, HttpContext http, Db db,
            CancellationToken ct) =>
        {
            var reason = request.Reason?.Trim() ?? "";
            if (reason.Length is < 5 or > 500)
                return Results.BadRequest(new { error = "Lý do từ chối phải từ 5–500 ký tự" });
            await using var conn = await db.OpenAsync(ct);
            var affected = await conn.ExecuteAsync("""
                update users set verification_status = 'rejected',
                    verification_rejection_reason = @reason,
                    verification_reviewed_at = now(),
                    verified_level = 1
                where id = @userId and verification_status = 'pending'
                """, new { userId, reason });
            if (affected == 0) return Results.Conflict(new { error = "Hồ sơ không ở trạng thái chờ duyệt" });
            await conn.ExecuteAsync("""
                insert into verification_events (user_id, actor_id, action, detail)
                values (@userId, @adminId, 'rejected', @detail::jsonb)
                """, new { userId, adminId = http.User.GetUserId(),
                detail = System.Text.Json.JsonSerializer.Serialize(new { reason }) });
            await Notifier.NotifyAsync(conn, null, userId, "verification.rejected",
                "Hồ sơ xác thực bị từ chối", reason);
            await Audit.LogAsync(conn, null, http.User.GetUserId(), "verification.reject",
                "user", userId.ToString(), new { reason });
            return Results.Ok(new { status = "rejected" });
        });

        admin.MapPost("/{userId:guid}/suspend", async (
            Guid userId, RejectVerificationRequest request, HttpContext http, Db db,
            CancellationToken ct) =>
        {
            var reason = request.Reason?.Trim() ?? "";
            if (reason.Length is < 5 or > 500)
                return Results.BadRequest(new { error = "Lý do phải từ 5–500 ký tự" });
            await using var conn = await db.OpenAsync(ct);
            await conn.ExecuteAsync("""
                update users set verification_status = 'suspended',
                    verification_rejection_reason = @reason,
                    verified_level = 1
                where id = @userId
                """, new { userId, reason });
            await Notifier.NotifyAsync(conn, null, userId, "verification.suspended",
                "Tài khoản tài xế bị tạm dừng", reason);
            await Audit.LogAsync(conn, null, http.User.GetUserId(), "verification.suspend",
                "user", userId.ToString(), new { reason });
            return Results.Ok(new { status = "suspended" });
        });

        return app;
    }

    private static async Task<VerificationStatusDto> GetStatusAsync(
        NpgsqlConnection conn, Guid userId)
    {
        var user = await conn.QuerySingleAsync<dynamic>(
            "select * from users where id = @userId", new { userId });
        var docs = await conn.QueryAsync<dynamic>("""
            select id, type, original_name, mime_type, size_bytes, created_at
            from verification_documents where user_id = @userId order by type
            """, new { userId });
        return new VerificationStatusDto(
            (string)user.verification_status, (int)user.verified_level,
            DtoOrNull(user.verification_expires_at),
            DtoOrNull(user.verification_submitted_at),
            DtoOrNull(user.verification_reviewed_at),
            (string?)user.verification_rejection_reason, (string?)user.legal_name,
            ToDateOnly(user.date_of_birth), (string?)user.id_number,
            ToDateOnly(user.id_issued_at), ToDateOnly(user.id_expiry),
            (string?)user.license_number, (string?)user.license_class,
            ToDateOnly(user.license_expiry), (string?)user.vehicle_registration,
            ToDateOnly(user.insurance_expiry),
            docs.Select(MapDocument).ToList(), VerificationTypes.RequiredForDriver);
    }

    private static VerificationDocumentDto MapDocument(dynamic row) => new(
        (Guid)row.id, (string)row.type, (string)row.original_name,
        (string)row.mime_type, (int)row.size_bytes,
        Time.ToDto((DateTime)row.created_at));

    private static DateOnly? ToDateOnly(object? value) => value switch
    {
        DateOnly d => d,
        DateTime dt => DateOnly.FromDateTime(dt),
        _ => null
    };

    private static DateTimeOffset? DtoOrNull(object? value)
        => value is DateTime dt ? Time.ToDto(dt) : null;

    private static DateTime? ToDateTime(DateOnly? value)
        => value?.ToDateTime(TimeOnly.MinValue);

    private static string? ValidateProfile(
        UpdateVerificationProfileRequest request, out string legalName,
        out string idNumber, out string licenseNumber, out string vehicleRegistration)
    {
        legalName = request.LegalName?.Trim() ?? "";
        idNumber = (request.IdNumber ?? "").Trim();
        licenseNumber = (request.LicenseNumber ?? "").Trim();
        vehicleRegistration = (request.VehicleRegistration ?? "").Trim().ToUpperInvariant();
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        if (legalName.Length is < 2 or > 100) return "Họ tên pháp lý phải từ 2–100 ký tự";
        if (request.DateOfBirth is null) return "Thiếu ngày sinh";
        var age = today.Year - request.DateOfBirth.Value.Year;
        if (request.DateOfBirth.Value > today.AddYears(-age)) age--;
        if (age is < 18 or > 80) return "Tài xế phải từ 18–80 tuổi";
        if (!IdNumberRegex().IsMatch(idNumber)) return "Số CCCD/CMND phải gồm 9 hoặc 12 chữ số";
        if (request.IdIssuedAt is null || request.IdIssuedAt > today)
            return "Ngày cấp CCCD không hợp lệ";
        if (request.IdExpiry is null || request.IdExpiry <= today)
            return "CCCD đã hết hạn hoặc thiếu ngày hết hạn";
        if (licenseNumber.Length is < 6 or > 20 || !licenseNumber.All(char.IsLetterOrDigit))
            return "Số GPLX không hợp lệ";
        var licenseClass = (request.LicenseClass ?? "").Trim().ToUpperInvariant();
        if (licenseClass is not ("A1" or "A2" or "B1" or "B2" or "C" or "D" or "E" or "FB2" or "FC" or "FD" or "FE"))
            return "Hạng GPLX không hợp lệ";
        if (request.LicenseExpiry is null || request.LicenseExpiry <= today)
            return "GPLX đã hết hạn hoặc thiếu ngày hết hạn";
        if (!VehicleRegistrationRegex().IsMatch(vehicleRegistration))
            return "Biển số/đăng ký xe không hợp lệ";
        if (request.InsuranceExpiry is null || request.InsuranceExpiry <= today)
            return "Bảo hiểm xe đã hết hạn hoặc thiếu ngày hết hạn";
        return null;
    }

    private static string? ValidateStoredProfile(dynamic user)
    {
        var legalName = (string?)user.legal_name;
        var dob = ToDateOnly(user.date_of_birth);
        var idNumber = (string?)user.id_number;
        var idExpiry = ToDateOnly(user.id_expiry);
        var license = (string?)user.license_number;
        var licenseExpiry = ToDateOnly(user.license_expiry);
        var registration = (string?)user.vehicle_registration;
        var insurance = ToDateOnly(user.insurance_expiry);
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        if (string.IsNullOrWhiteSpace(legalName) || dob is null || idNumber is null
            || idExpiry is null || license is null || licenseExpiry is null
            || registration is null || insurance is null)
            return "Hồ sơ chưa đầy đủ thông tin pháp lý";
        if (idExpiry <= today || licenseExpiry <= today || insurance <= today)
            return "Có giấy tờ đã hết hạn, vui lòng cập nhật";
        return null;
    }
}
