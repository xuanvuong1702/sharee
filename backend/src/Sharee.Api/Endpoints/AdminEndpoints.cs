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
                await conn.ExecuteScalarAsync<int>("select count(*) from user_verifications where status = 'pending'"),
                await conn.ExecuteScalarAsync<long>("select coalesce(sum(price_total),0) from bookings where status in ('confirmed','completed')"),
                await conn.ExecuteScalarAsync<int>("select count(*) from trips where status = 'open' and departure_time > now()"),
                await conn.ExecuteScalarAsync<int>("select count(*) from e_tickets where created_at > now() - interval '1 day'"));
            return Results.Ok(dto);
        });

        group.MapGet("/verifications", async (Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var rows = await conn.QueryAsync<dynamic>("""
                select v.id, v.user_id, u.full_name as user_name, u.phone, v.type, v.status,
                       v.document_ref, v.created_at
                from user_verifications v join users u on u.id = v.user_id
                order by case when v.status = 'pending' then 0 else 1 end, v.created_at desc
                limit 100
                """);
            return Results.Ok(rows.Select(r => new VerificationDto(
                (Guid)r.id, (Guid)r.user_id, (string)r.user_name, (string)r.phone,
                (string)r.type, (string)r.status, (string?)r.document_ref,
                Time.ToDto((DateTime)r.created_at))));
        });

        group.MapPost("/verifications/{id:guid}/approve", async (
            Guid id, HttpContext http, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var row = await conn.QuerySingleOrDefaultAsync<dynamic>("""
                update user_verifications
                set status = 'approved', reviewed_by = @adminId, reviewed_at = now()
                where id = @id and status = 'pending'
                returning user_id, type
                """, new { id, adminId = http.User.GetUserId() });
            if (row is null) return Results.NotFound();

            Guid userId = row.user_id;
            string type = row.type;
            var level = type switch { "license" => 3, "id" => 2, "vehicle" => 2, _ => 1 };
            await conn.ExecuteAsync(
                "update users set verified_level = greatest(verified_level, @level) where id = @userId",
                new { level, userId });
            return Results.Ok(new { status = "approved" });
        });

        group.MapPost("/verifications/{id:guid}/reject", async (
            Guid id, HttpContext http, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var affected = await conn.ExecuteAsync("""
                update user_verifications
                set status = 'rejected', reviewed_by = @adminId, reviewed_at = now()
                where id = @id and status = 'pending'
                """, new { id, adminId = http.User.GetUserId() });
            return affected == 0 ? Results.NotFound() : Results.Ok(new { status = "rejected" });
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
            Guid bookingId, Db db, LedgerService ledger, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            await using var tx = await conn.BeginTransactionAsync(ct);
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
            await conn.ExecuteAsync("update bookings set status = 'refunded' where id = @bookingId",
                new { bookingId }, tx);
            await ledger.RecordAsync(conn, tx, "refund", "booking", bookingId,
                ("escrow", 'D', amount.Value),
                ("customer_receivable", 'C', amount.Value));
            await tx.CommitAsync(ct);
            return Results.Ok(new { status = "refunded", amount });
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
