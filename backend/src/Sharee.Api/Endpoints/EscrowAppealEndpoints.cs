using Dapper;
using Microsoft.AspNetCore.Mvc;
using Npgsql;
using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Api.Endpoints;

public static class EscrowAppealEndpoints
{
    private static readonly HashSet<string> Methods = ["bank", "wallet", "cash"];

    public static IEndpointRouteBuilder MapEscrowAppealEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/bookings/{id:guid}").RequireAuthorization().WithTags("Escrow");

        group.MapGet("/escrow", async (Guid id, HttpContext http, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var participant = await GetParticipantAsync(conn, id, http.User.GetUserId());
            if (participant is null) return Results.NotFound();
            var escrow = await conn.QuerySingleOrDefaultAsync<dynamic>(
                "select * from escrow_holds where booking_id = @id", new { id });
            return escrow is null ? Results.NotFound() : Results.Ok(MapEscrow(escrow));
        });

        group.MapPost("/payment-method", async (
            Guid id, SetPaymentMethodRequest request, HttpContext http, Db db,
            LedgerService ledger, CancellationToken ct) =>
        {
            var method = (request.Method ?? "").Trim().ToLowerInvariant();
            if (!Methods.Contains(method))
                return Results.BadRequest(new { error = "Phương thức thanh toán không hợp lệ" });
            var userId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            var booking = await GetParticipantAsync(conn, id, userId);
            if (booking is null) return Results.NotFound();
            if ((Guid)booking.passenger_id != userId) return Results.Forbid();
            if ((string)booking.status != "pending_payment")
                return Results.Conflict(new { error = "Booking không ở trạng thái chờ thanh toán" });

            if (method != "cash")
            {
                await conn.ExecuteAsync(
                    "update bookings set payment_method = @method, updated_at = now() where id = @id",
                    new { id, method });
                return Results.Ok(new { method, next = method == "cash" ? "confirm" : "payos" });
            }

            var kyc = await conn.QuerySingleAsync<dynamic>("""
                select verified_level, verification_status, verification_expires_at
                from users where id = @userId
                """, new { userId });
            if ((int)kyc.verified_level < 2
                || (string)kyc.verification_status != "approved"
                || (kyc.verification_expires_at is not null
                    && (DateTime)kyc.verification_expires_at <= DateTime.UtcNow))
                return Results.Json(new
                {
                    error = "Cần xác thực danh tính trước khi thanh toán tiền mặt.",
                    kycRequired = true
                }, statusCode: StatusCodes.Status403Forbidden);

            await using var tx = await conn.BeginTransactionAsync(ct);
            var affected = await conn.ExecuteAsync("""
                update bookings set status = 'confirmed', payment_method = 'cash', updated_at = now()
                where id = @id and status = 'pending_payment'
                """, new { id }, tx);
            if (affected == 0)
            {
                await tx.RollbackAsync(ct);
                return Results.Conflict(new { error = "Booking đã thay đổi trạng thái" });
            }
            await conn.ExecuteAsync("""
                insert into payments (booking_id, provider, provider_ref, amount, status, captured_at)
                values (@id, 'cash', @ref, @amount, 'succeeded', now())
                on conflict (booking_id) do nothing
                """, new
            {
                id, @ref = "CASH-" + Guid.NewGuid().ToString("N")[..10],
                amount = (int)booking.price_total
            }, tx);
            await conn.ExecuteAsync("""
                insert into escrow_holds (booking_id, amount, method, status)
                values (@id, @amount, 'cash', 'cash_pending')
                on conflict (booking_id) do nothing
                """, new { id, amount = (int)booking.price_total }, tx);
            await conn.ExecuteAsync("""
                insert into conversations (booking_id) values (@id)
                on conflict (booking_id) do nothing
                """, new { id }, tx);
            await Notifier.NotifyAsync(conn, tx, (Guid)booking.driver_id, "booking.cash_confirmed",
                "Khách chọn thanh toán tiền mặt",
                "Chuyến đã được xác nhận. Thu tiền mặt khi hoàn thành chuyến.");
            await conn.ExecuteAsync("""
                insert into outbox (aggregate_type, aggregate_id, type, payload)
                values ('booking', @id, 'booking.confirmed', '{}'::jsonb)
                """, new { id }, tx);
            await tx.CommitAsync(ct);
            return Results.Ok(new { method = "cash", status = "confirmed" });
        });

        group.MapPost("/appeals", async (
            Guid id, CreateAppealRequest request, HttpContext http, Db db, CancellationToken ct) =>
        {
            var reason = request.Reason?.Trim() ?? "";
            var description = request.Description?.Trim() ?? "";
            if (reason.Length is < 3 or > 80)
                return Results.BadRequest(new { error = "Lý do khiếu nại phải từ 3–80 ký tự" });
            if (description.Length is < 10 or > 2000)
                return Results.BadRequest(new { error = "Mô tả phải từ 10–2000 ký tự" });
            var userId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            var booking = await GetParticipantAsync(conn, id, userId);
            if (booking is null) return Results.NotFound();
            if ((string)booking.status is not ("confirmed" or "completed"))
                return Results.Conflict(new { error = "Chỉ có thể khiếu nại chuyến đã xác nhận/hoàn thành" });
            var escrowStatus = await conn.ExecuteScalarAsync<string>(
                "select status from escrow_holds where booking_id = @id", new { id });
            if (escrowStatus is not ("held" or "cash_pending" or "disputed"))
                return Results.Conflict(new { error = "Chuyến đã được giải ngân, không thể mở khiếu nại" });
            var isPassenger = (Guid)booking.passenger_id == userId;
            var against = isPassenger ? (Guid)booking.driver_id : (Guid)booking.passenger_id;
            var existing = await conn.ExecuteScalarAsync<Guid?>(
                "select id from appeals where booking_id = @id and status in ('open','investigating')",
                new { id });
            if (existing is not null)
                return Results.Conflict(new { error = "Booking đã có khiếu nại đang mở", appealId = existing });

            await using var tx = await conn.BeginTransactionAsync(ct);
            var appealId = await conn.ExecuteScalarAsync<Guid>("""
                insert into appeals (booking_id, opened_by, against_id, reason, description)
                values (@id, @userId, @against, @reason, @description)
                returning id
                """, new { id, userId, against, reason, description }, tx);
            await conn.ExecuteAsync("""
                update escrow_holds set status = 'disputed', updated_at = now()
                where booking_id = @id and status in ('held','cash_pending')
                """, new { id }, tx);
            await Notifier.NotifyAsync(conn, tx, against, "appeal.opened",
                "Có khiếu nại mới", reason);
            await tx.CommitAsync(ct);
            return Results.Ok(await GetAppealAsync(conn, appealId));
        });

        group.MapGet("/appeals", async (Guid id, HttpContext http, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            if (await GetParticipantAsync(conn, id, http.User.GetUserId()) is null) return Results.NotFound();
            var rows = await conn.QueryAsync<Guid>(
                "select id from appeals where booking_id = @id order by created_at desc", new { id });
            var list = new List<AppealDto>();
            foreach (var appealId in rows)
            {
                var item = await GetAppealAsync(conn, appealId);
                if (item is not null) list.Add(item);
            }
            return Results.Ok(list);
        });

        var appeals = app.MapGroup("/api/appeals").RequireAuthorization().WithTags("Appeals");

        appeals.MapGet("/{appealId:guid}", async (
            Guid appealId, HttpContext http, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var appeal = await GetAppealAsync(conn, appealId);
            if (appeal is null) return Results.NotFound();
            var userId = http.User.GetUserId();
            if (!await IsParticipantAsync(conn, appeal.BookingId, userId)) return Results.Forbid();
            return Results.Ok(appeal);
        });

        appeals.MapPost("/{appealId:guid}/evidence", async (
            Guid appealId, [FromForm] IFormFile file, HttpContext http, Db db,
            AppealStorage storage, CancellationToken ct) =>
        {
            var userId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            var appeal = await GetAppealAsync(conn, appealId);
            if (appeal is null) return Results.NotFound();
            if (!await IsParticipantAsync(conn, appeal.BookingId, userId)) return Results.Forbid();
            if (appeal.Status is not ("open" or "investigating"))
                return Results.Conflict(new { error = "Khiếu nại đã đóng" });
            if (file is null || file.Length == 0) return Results.BadRequest(new { error = "Thiếu tệp" });
            StoredAppealEvidence stored;
            try { stored = await storage.SaveAsync(appealId, file, ct); }
            catch (InvalidOperationException ex) { return Results.BadRequest(new { error = ex.Message }); }
            var evidenceId = await conn.ExecuteScalarAsync<Guid>("""
                insert into appeal_evidence
                    (appeal_id, uploader_id, original_name, stored_path, mime_type, size_bytes, sha256)
                values (@appealId, @userId, @originalName, @storedPath, @mimeType, @size, @sha)
                returning id
                """, new
            {
                appealId, userId, stored.OriginalName, stored.StoredPath,
                stored.MimeType, size = stored.SizeBytes, sha = stored.Sha256
            });
            return Results.Ok(new { id = evidenceId, originalName = stored.OriginalName });
        }).DisableAntiforgery();

        appeals.MapPost("/{appealId:guid}/cancel", async (
            Guid appealId, HttpContext http, Db db, CancellationToken ct) =>
        {
            var userId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            var appeal = await GetAppealAsync(conn, appealId);
            if (appeal is null) return Results.NotFound();
            if (appeal.OpenedBy != userId) return Results.Forbid();
            if (appeal.Status is not ("open" or "investigating"))
                return Results.Conflict(new { error = "Khiếu nại đã đóng" });
            await using var tx = await conn.BeginTransactionAsync(ct);
            await conn.ExecuteAsync("""
                update appeals set status = 'cancelled', updated_at = now(), resolved_at = now()
                where id = @appealId and status in ('open','investigating')
                """, new { appealId }, tx);
            await conn.ExecuteAsync("""
                update escrow_holds set status = case when method = 'cash' then 'cash_pending' else 'held' end,
                    updated_at = now()
                where booking_id = @bookingId and status = 'disputed'
                """, new { bookingId = appeal.BookingId }, tx);
            await tx.CommitAsync(ct);
            return Results.Ok(new { status = "cancelled" });
        });

        var admin = app.MapGroup("/api/admin/appeals").RequireAuthorization("admin").WithTags("AdminAppeals");

        admin.MapGet("", async (Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var rows = await conn.QueryAsync<dynamic>("""
                select a.id, a.booking_id, a.opened_by, uo.full_name as opened_by_name,
                       a.against_id, ua.full_name as against_name, a.reason, a.description,
                       a.status, a.resolution, a.resolution_note, a.created_at, a.resolved_at
                from appeals a
                join users uo on uo.id = a.opened_by
                join users ua on ua.id = a.against_id
                order by case a.status when 'open' then 0 when 'investigating' then 1 else 2 end,
                         a.created_at desc
                limit 200
                """);
            return Results.Ok(rows.Select(r => new AppealDto(
                (Guid)r.id, (Guid)r.booking_id, (Guid)r.opened_by, (string)r.opened_by_name,
                (Guid)r.against_id, (string)r.against_name, (string)r.reason,
                (string)r.description, (string)r.status, (string?)r.resolution,
                (string?)r.resolution_note, Time.ToDto((DateTime)r.created_at),
                r.resolved_at is null ? null : Time.ToDto((DateTime)r.resolved_at),
                Array.Empty<AppealEvidenceDto>())));
        });

        admin.MapGet("/{appealId:guid}", async (Guid appealId, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var appeal = await GetAppealAsync(conn, appealId);
            return appeal is null ? Results.NotFound() : Results.Ok(appeal);
        });

        admin.MapGet("/{appealId:guid}/evidence/{evidenceId:guid}", async (
            Guid appealId, Guid evidenceId, Db db, AppealStorage storage, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var row = await conn.QuerySingleOrDefaultAsync<dynamic>("""
                select stored_path, original_name, mime_type from appeal_evidence
                where id = @evidenceId and appeal_id = @appealId
                """, new { evidenceId, appealId });
            if (row is null) return Results.NotFound();
            var path = storage.Resolve((string)row.stored_path);
            return path is null || !File.Exists(path)
                ? Results.NotFound()
                : Results.File(path, (string)row.mime_type, (string)row.original_name,
                    enableRangeProcessing: true);
        });

        admin.MapPost("/{appealId:guid}/resolve", async (
            Guid appealId, ResolveAppealRequest request, HttpContext http, Db db,
            LedgerService ledger, CancellationToken ct) =>
        {
            var outcome = (request.Outcome ?? "").Trim().ToLowerInvariant();
            var note = request.Note?.Trim() ?? "";
            if (outcome is not ("release" or "refund"))
                return Results.BadRequest(new { error = "Kết quả phải là release hoặc refund" });
            if (note.Length is < 5 or > 1000)
                return Results.BadRequest(new { error = "Ghi chú phải từ 5–1000 ký tự" });
            await using var conn = await db.OpenAsync(ct);
            var appeal = await GetAppealAsync(conn, appealId);
            if (appeal is null) return Results.NotFound();
            if (appeal.Status is not ("open" or "investigating"))
                return Results.Conflict(new { error = "Khiếu nại đã đóng" });
            var booking = await conn.QuerySingleAsync<dynamic>(
                "select id, amount, method, status from escrow_holds where booking_id = @bookingId",
                new { bookingId = appeal.BookingId });
            var payment = await conn.QuerySingleOrDefaultAsync<dynamic>(
                "select id, status from payments where booking_id = @bookingId",
                new { bookingId = appeal.BookingId });
            var bookingInfo = await conn.QuerySingleAsync<dynamic>(
                "select trip_id, seats, status from bookings where id = @bookingId",
                new { bookingId = appeal.BookingId });

            await using var tx = await conn.BeginTransactionAsync(ct);
            var resolution = outcome == "release" ? "released" : "refunded";
            var affected = await conn.ExecuteAsync("""
                update appeals set status = 'resolved', resolution = @outcome,
                    resolution_note = @note, resolved_by = @adminId,
                    updated_at = now(), resolved_at = now()
                where id = @appealId and status in ('open','investigating')
                """, new { appealId, outcome, note, adminId = http.User.GetUserId() }, tx);
            if (affected == 0)
            {
                await tx.RollbackAsync(ct);
                return Results.Conflict(new { error = "Khiếu nại đã được xử lý bởi người khác" });
            }
            await conn.ExecuteAsync("""
                update escrow_holds set status = @resolution, released_at = now(), updated_at = now()
                where booking_id = @bookingId
                """, new { resolution, bookingId = appeal.BookingId }, tx);

            var amount = (int)booking.amount;
            if (outcome == "release")
            {
                var alreadyPaidOut = await conn.ExecuteScalarAsync<bool>("""
                    select exists(select 1 from ledger_transactions
                                  where type = 'payout' and ref_type = 'booking' and ref_id = @bookingId)
                    """, new { bookingId = appeal.BookingId }, tx);
                if (!alreadyPaidOut && (string)booking.method != "cash")
                    await ledger.RecordAsync(conn, tx, "payout", "booking", appeal.BookingId,
                        ("escrow", 'D', amount), ("driver_payable", 'C', amount));
            }
            else
            {
                var alreadyPaidOut = await conn.ExecuteScalarAsync<bool>("""
                    select exists(select 1 from ledger_transactions
                                  where type = 'payout' and ref_type = 'booking' and ref_id = @bookingId)
                    """, new { bookingId = appeal.BookingId }, tx);
                if (alreadyPaidOut)
                {
                    await tx.RollbackAsync(ct);
                    return Results.Conflict(new
                    {
                        error = "Tiền đã được giải ngân; không thể hoàn tự động. Cần xử lý thủ công."
                    });
                }
                await conn.ExecuteAsync(
                    "update payments set status = 'refunded' where booking_id = @bookingId",
                    new { bookingId = appeal.BookingId }, tx);
                var alreadyRefunded = await conn.ExecuteScalarAsync<bool>("""
                    select exists(select 1 from ledger_transactions
                                  where type = 'refund' and ref_type = 'booking' and ref_id = @bookingId)
                    """, new { bookingId = appeal.BookingId }, tx);
                if (!alreadyRefunded && (string)booking.method != "cash")
                    await ledger.RecordAsync(conn, tx, "refund", "booking", appeal.BookingId,
                        ("escrow", 'D', amount), ("customer_receivable", 'C', amount));
                await conn.ExecuteAsync(
                    "update bookings set status = 'refunded', updated_at = now() where id = @bookingId",
                    new { bookingId = appeal.BookingId }, tx);
                if ((string)bookingInfo.status == "confirmed")
                    await conn.ExecuteAsync("""
                        update trips set seats_available = least(seats_total, seats_available + @seats),
                            status = case when status = 'full' then 'open' else status end,
                            updated_at = now()
                        where id = @tripId
                        """, new { tripId = (Guid)bookingInfo.trip_id, seats = (short)bookingInfo.seats }, tx);
            }

            await Notifier.NotifyAsync(conn, tx, appeal.OpenedBy, "appeal.resolved",
                "Khiếu nại đã được xử lý",
                outcome == "release" ? "Chuyến được giải ngân cho tài xế." : "Bạn được hoàn tiền.");
            await Notifier.NotifyAsync(conn, tx, appeal.AgainstId, "appeal.resolved",
                "Khiếu nại đã được xử lý",
                outcome == "release" ? "Tiền được giải ngân cho bạn." : "Khoản tiền được hoàn cho khách.");
            await Audit.LogAsync(conn, tx, http.User.GetUserId(), "appeal.resolve",
                "appeal", appealId.ToString(), new { outcome, note });
            await tx.CommitAsync(ct);
            return Results.Ok(new { status = "resolved", outcome });
        });

        var users = app.MapGroup("/api/users").RequireAuthorization().WithTags("Reputation");
        users.MapGet("/{userId:guid}/reputation", async (
            Guid userId, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var reputation = await GetReputationAsync(conn, userId);
            return reputation is null ? Results.NotFound() : Results.Ok(reputation);
        });

        app.MapGet("/api/me/reputation", async (HttpContext http, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            return Results.Ok(await GetReputationAsync(conn, http.User.GetUserId()));
        }).RequireAuthorization().WithTags("Reputation");

        return app;
    }

    private static async Task<dynamic?> GetParticipantAsync(
        NpgsqlConnection conn, Guid bookingId, Guid userId)
        => await conn.QuerySingleOrDefaultAsync<dynamic>("""
            select b.id, b.passenger_id, b.price_total, b.status, t.driver_id
            from bookings b join trips t on t.id = b.trip_id
            where b.id = @bookingId and (b.passenger_id = @userId or t.driver_id = @userId)
            """, new { bookingId, userId });

    private static async Task<bool> IsParticipantAsync(
        NpgsqlConnection conn, Guid bookingId, Guid userId)
        => await GetParticipantAsync(conn, bookingId, userId) is not null;

    private static EscrowDto MapEscrow(dynamic row) => new(
        (Guid)row.booking_id, (int)row.amount, (string)row.currency, (string)row.method,
        (string)row.status, Time.ToDto((DateTime)row.held_at),
        row.released_at is null ? null : Time.ToDto((DateTime)row.released_at));

    private static async Task<AppealDto?> GetAppealAsync(NpgsqlConnection conn, Guid appealId)
    {
        var row = await conn.QuerySingleOrDefaultAsync<dynamic>("""
            select a.*, uo.full_name as opened_by_name, ua.full_name as against_name
            from appeals a
            join users uo on uo.id = a.opened_by
            join users ua on ua.id = a.against_id
            where a.id = @appealId
            """, new { appealId });
        if (row is null) return null;
        var evidence = await conn.QueryAsync<dynamic>("""
            select e.id, e.original_name, e.mime_type, e.size_bytes, e.created_at, u.full_name
            from appeal_evidence e join users u on u.id = e.uploader_id
            where e.appeal_id = @appealId order by e.created_at
            """, new { appealId });
        return new AppealDto(
            (Guid)row.id, (Guid)row.booking_id, (Guid)row.opened_by, (string)row.opened_by_name,
            (Guid)row.against_id, (string)row.against_name, (string)row.reason,
            (string)row.description, (string)row.status, (string?)row.resolution,
            (string?)row.resolution_note, Time.ToDto((DateTime)row.created_at),
            row.resolved_at is null ? null : Time.ToDto((DateTime)row.resolved_at),
            evidence.Select(e => new AppealEvidenceDto(
                (Guid)e.id, (string)e.original_name, (string)e.mime_type, (int)e.size_bytes,
                (string)e.full_name, Time.ToDto((DateTime)e.created_at))).ToList());
    }

    private static async Task<ReputationDto?> GetReputationAsync(NpgsqlConnection conn, Guid userId)
    {
        var user = await conn.QuerySingleOrDefaultAsync<dynamic>(
            "select id, full_name, avatar_url, rating_avg, rating_count, verified_level from users where id = @userId",
            new { userId });
        if (user is null) return null;
        var d = await conn.QuerySingleAsync<dynamic>("""
            select
              (select count(*) from bookings b join trips t on t.id = b.trip_id
               where t.driver_id = @userId and b.status = 'completed') as completed_driver,
              (select count(*) from bookings b
               where b.passenger_id = @userId and b.status = 'completed') as completed_passenger,
              (select count(*) from bookings b join trips t on t.id = b.trip_id
               where t.driver_id = @userId and b.status like 'cancelled%') as cancelled_driver,
              (select count(*) from bookings b
               where b.passenger_id = @userId and b.status like 'cancelled%') as cancelled_passenger
            """, new { userId });
        var completed = (int)(long)d.completed_driver + (int)(long)d.completed_passenger;
        var cancelled = (int)(long)d.cancelled_driver + (int)(long)d.cancelled_passenger;
        var total = completed + cancelled;
        var rate = total == 0 ? 0 : (int)Math.Round(100.0 * completed / total);
        var rating = (double)(decimal)user.rating_avg;
        var score = total == 0 ? 0 : (int)Math.Round(50 * (rating / 5.0) + 35 * (rate / 100.0)
            + 15 * Math.Min(1, completed / 20.0));
        var tier = total < 3
            ? "new"
            : score >= 80 && completed >= 10
                ? "elite"
                : score >= 65 && completed >= 5
                    ? "gold"
                    : score >= 50
                        ? "silver"
                        : score >= 30
                            ? "bronze"
                            : "new";
        var badges = new List<string>();
        if ((int)user.verified_level >= 2) badges.Add("kyc");
        if ((int)user.verified_level >= 3) badges.Add("verified_driver");
        if ((int)user.rating_count >= 5 && rating >= 4.8) badges.Add("top_rated");
        return new ReputationDto(
            (Guid)user.id, (string)user.full_name, (string?)user.avatar_url,
            Math.Round(rating, 2), (int)user.rating_count,
            (int)(long)d.completed_driver, (int)(long)d.completed_passenger,
            (int)(long)d.cancelled_driver, (int)(long)d.cancelled_passenger,
            total, rate, score, tier, badges);
    }
}
