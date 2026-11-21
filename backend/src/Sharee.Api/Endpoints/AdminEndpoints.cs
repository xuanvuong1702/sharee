using Dapper;
using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Api.Endpoints;

public static class AdminEndpoints
{
    public static IEndpointRouteBuilder MapAdminEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/admin").RequireAuthorization("admin").WithTags("Admin");

        group.MapGet("/dashboard", async (Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var dto = new AdminDashboardDto(
                await conn.ExecuteScalarAsync<int>("select count(*) from users"),
                await conn.ExecuteScalarAsync<int>("select count(*) from trips"),
                await conn.ExecuteScalarAsync<int>("select count(*) from bookings"),
                await conn.ExecuteScalarAsync<int>("select count(*) from reports where status = 'open'"),
                await conn.ExecuteScalarAsync<int>("select count(*) from users where verification_status = 'pending'"),
                await conn.ExecuteScalarAsync<long>("select coalesce(sum(price_total),0) from bookings where status in ('confirmed','completed')"),
                await conn.ExecuteScalarAsync<int>("select count(*) from trips where status = 'open' and departure_time > now()"),
                await conn.ExecuteScalarAsync<int>("select count(*) from e_tickets where created_at > now() - interval '1 day'"),
                await conn.ExecuteScalarAsync<long>("select coalesce(sum(amount),0) from escrow_holds where status in ('held','cash_pending','disputed')"),
                await conn.ExecuteScalarAsync<int>("select count(*) from appeals where status in ('open','investigating')"),
                await conn.ExecuteScalarAsync<int>("select count(*) from users where verified_level >= 3 and verification_status = 'approved'"));
            return Results.Ok(dto);
        });

        group.MapGet("/reports", async (Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var rows = await conn.QueryAsync<dynamic>("""
                select r.id, r.reporter_id, u.full_name as reporter_name, r.target_type, r.target_id,
                       r.reason, r.description, r.status, r.created_at
                from reports r join users u on u.id = r.reporter_id
                order by case when r.status = 'open' then 0 else 1 end, r.created_at desc
                limit 100
                """);
            return Results.Ok(rows.Select(r => new ReportDto(
                (Guid)r.id, (Guid)r.reporter_id, (string)r.reporter_name,
                (string)r.target_type, (Guid)r.target_id, (string)r.reason,
                (string?)r.description, (string)r.status, Time.ToDto((DateTime)r.created_at))));
        });

        group.MapPatch("/reports/{id:guid}", async (
            Guid id, string status, HttpContext http, Db db, CancellationToken ct) =>
        {
            if (status is not ("resolved" or "dismissed"))
                return Results.BadRequest(new { error = "Trạng thái không hợp lệ" });
            await using var conn = await db.OpenAsync(ct);
            var affected = await conn.ExecuteAsync("""
                update reports set status = @status, handled_by = @adminId where id = @id
                """, new { id, status, adminId = http.User.GetUserId() });
            if (affected > 0)
                await Audit.LogAsync(conn, null, http.User.GetUserId(), "report.resolve",
                    "report", id.ToString(), new { status });
            return affected == 0 ? Results.NotFound() : Results.Ok(new { status });
        });

        group.MapGet("/users", async (string? q, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var rows = await conn.QueryAsync<UserRow>("""
                select * from users
                where (@q = '' or full_name ilike '%' || @q || '%' or phone ilike '%' || @q || '%')
                order by created_at desc limit 100
                """, new { q = q ?? "" });
            return Results.Ok(rows.Select(r => r.ToUser()));
        });

        group.MapGet("/trips", async (Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var rows = await conn.QueryAsync<TripRow>("""
                select t.id, t.driver_id, t.vehicle_id,
                       ST_Y(t.origin::geometry) as origin_lat, ST_X(t.origin::geometry) as origin_lng,
                       ST_Y(t.destination::geometry) as destination_lat, ST_X(t.destination::geometry) as destination_lng,
                       t.origin_label, t.destination_label, t.departure_time, t.arrive_estimate,
                       t.price_per_seat, t.seats_total, t.seats_available, t.booking_mode,
                       t.luggage, t.pets_allowed, t.smoking_allowed, t.status, t.distance_m, t.duration_s,
                       u.phone as driver_phone, u.full_name as driver_name, u.rating_avg as driver_rating_avg,
                       u.rating_count as driver_rating_count, u.verified_level as driver_verified_level,
                       v.make as vehicle_make, v.model as vehicle_model, v.plate as vehicle_plate,
                       v.seats as vehicle_seats
                from trips t join users u on u.id = t.driver_id join vehicles v on v.id = t.vehicle_id
                order by t.departure_time desc limit 100
                """);
            return Results.Ok(rows.Select(r => new
            {
                r.Id, r.OriginLabel, r.DestinationLabel, r.DepartureTime, r.PricePerSeat,
                r.SeatsAvailable, r.SeatsTotal, r.Status, DriverName = r.DriverName,
                Vehicle = $"{r.VehicleMake} {r.VehicleModel}", r.VehiclePlate
            }));
        });

        group.MapGet("/refunds", async (Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var rows = await conn.QueryAsync<dynamic>("""
                select b.id as booking_id, b.price_total, b.status, p.amount, p.status as payment_status,
                       u.full_name as passenger_name, t.origin_label, t.destination_label
                from bookings b
                join payments p on p.booking_id = b.id
                join users u on u.id = b.passenger_id
                join trips t on t.id = b.trip_id
                where b.status in ('cancelled_by_passenger','cancelled_by_driver')
                  and p.status = 'succeeded'
                order by b.created_at desc limit 100
                """);
            return Results.Ok(rows);
        });

        group.MapPost("/refunds/{bookingId:guid}", async (
            Guid bookingId, HttpContext http, Db db, LedgerService ledger, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            await using var tx = await conn.BeginTransactionAsync(ct);
            var payout = await conn.ExecuteScalarAsync<bool>("""
                select exists(select 1 from ledger_transactions
                              where type = 'payout' and ref_type = 'booking' and ref_id = @bookingId)
                """, new { bookingId }, tx);
            if (payout)
            {
                await tx.RollbackAsync(ct);
                return Results.Conflict(new { error = "Tiền đã được giải ngân; cần xử lý thủ công." });
            }
            var amount = await conn.ExecuteScalarAsync<int?>(
                "select amount from payments where booking_id = @bookingId and status = 'succeeded'",
                new { bookingId }, tx);
            if (amount is null)
            {
                await tx.RollbackAsync(ct);
                return Results.Conflict(new { error = "Không có thanh toán để hoàn" });
            }

            await conn.ExecuteAsync("update payments set status = 'refunded' where booking_id = @bookingId",
                new { bookingId }, tx);
            await conn.ExecuteAsync("""
                update escrow_holds set status = 'refunded', released_at = now(), updated_at = now()
                where booking_id = @bookingId and status <> 'released'
                """, new { bookingId }, tx);
            await conn.ExecuteAsync("update bookings set status = 'refunded' where id = @bookingId",
                new { bookingId }, tx);
            await ledger.RecordAsync(conn, tx, "refund", "booking", bookingId,
                ("escrow", 'D', amount.Value),
                ("customer_receivable", 'C', amount.Value));
            await Audit.LogAsync(conn, tx, http.User.GetUserId(), "refund.manual", "booking", bookingId.ToString(),
                new { amount = amount.Value });
            await tx.CommitAsync(ct);
            return Results.Ok(new { status = "refunded", amount });
        });

        group.MapGet("/reconciliation", async (Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var rows = await conn.QueryAsync<dynamic>("""
                select r.id, r.booking_id, r.order_code, r.amount, r.reason, r.status,
                       r.note, r.created_at, u.full_name as passenger_name,
                       t.origin_label, t.destination_label
                from payment_reconciliation r
                join bookings b on b.id = r.booking_id
                join users u on u.id = b.passenger_id
                join trips t on t.id = b.trip_id
                where r.status = 'open'
                order by r.created_at desc limit 100
                """);
            return Results.Ok(rows.Select(r => new
            {
                id = (Guid)r.id,
                bookingId = (Guid)r.booking_id,
                orderCode = (string)r.order_code,
                amount = (int)r.amount,
                reason = (string)r.reason,
                note = (string?)r.note,
                createdAt = Time.ToDto((DateTime)r.created_at),
                passengerName = (string)r.passenger_name,
                route = $"{r.origin_label} → {r.destination_label}"
            }));
        });

        group.MapPost("/reconciliation/{id:guid}/resolve", async (
            Guid id, ResolveReconciliationRequest request, HttpContext http, Db db,
            CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            await using var tx = await conn.BeginTransactionAsync(ct);
            var affected = await conn.ExecuteAsync("""
                update payment_reconciliation
                set status = 'resolved', resolved_at = now(), note = @note
                where id = @id and status = 'open'
                """, new { id, note = (request.Note ?? "").Trim() }, tx);
            if (affected == 0)
            {
                await tx.RollbackAsync(ct);
                return Results.NotFound();
            }
            await Audit.LogAsync(conn, tx, http.User.GetUserId(), "reconciliation.resolve",
                "payment_reconciliation", id.ToString(), new { request.Note });
            await tx.CommitAsync(ct);
            return Results.Ok(new { status = "resolved" });
        });

        group.MapGet("/audit", async (Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var rows = await conn.QueryAsync<dynamic>("""
                select a.id, u.full_name as actor_name, a.action, a.target_type, a.target_id, a.created_at
                from audit_logs a left join users u on u.id = a.actor_id
                order by a.id desc limit 100
                """);
            return Results.Ok(rows.Select(r => new AuditDto(
                (long)r.id, (string?)r.actor_name, (string)r.action,
                (string?)r.target_type, (string?)r.target_id, Time.ToDto((DateTime)r.created_at))));
        });

        return app;
    }
}
