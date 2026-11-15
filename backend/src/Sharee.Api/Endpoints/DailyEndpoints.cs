using Dapper;
using Npgsql;
using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Api.Endpoints;

public static class DailyEndpoints
{
    public static IEndpointRouteBuilder MapDailyEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/daily").WithTags("Daily");

        group.MapGet("/lines", async (
            double? lat, double? lng, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var rows = await conn.QueryAsync<dynamic>("""
                select l.id, l.name, l.brand, l.description,
                       ST_Distance(l.route,
                           ST_SetSRID(ST_MakePoint(@lng, @lat), 4326)::geography)::float8 as distance_m,
                       (select count(*) from line_stops s where s.line_id = l.id)::int as stops_count
                from lines l
                where l.status = 'active'
                order by distance_m
                limit 20
                """, new { lng = lng ?? 106.6980, lat = lat ?? 10.7725 });

            var items = rows.Select(r => new LineDto(
                r.id, r.name, r.brand, r.description,
                r.distance_m is null ? (double?)null : (double)r.distance_m,
                (int)r.stops_count, null, null)).ToList();
            return Results.Ok(items);
        });

        group.MapGet("/lines/{id:guid}", async (Guid id, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var line = await conn.QuerySingleOrDefaultAsync<dynamic>("""
                select l.id, l.name, l.brand, l.description,
                       ST_Length(l.route)::float8 as distance_m
                from lines l where l.id = @id
                """, new { id });
            if (line is null) return Results.NotFound();

            var stops = (await conn.QueryAsync<LineStopDto>("""
                select id, seq::int as seq, name, ST_Y(location::geometry) as lat, ST_X(location::geometry) as lng, qr_token
                from line_stops where line_id = @id order by seq
                """, new { id })).ToList();

            var windows = (await conn.QueryAsync<ServiceWindowDto>("""
                select weekday::int as weekday, start_time::text as start_time, end_time::text as end_time, headway_min::int as headway_min
                from line_service_windows where line_id = @id order by weekday, start_time
                """, new { id })).ToList();

            return Results.Ok(new LineDto(line.id, line.name, line.brand, line.description,
                (double)line.distance_m, stops.Count, stops, windows));
        });

        group.MapPost("/e-tickets", async (
            CreateETicketRequest request, HttpContext http, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var stop = await conn.QuerySingleOrDefaultAsync<dynamic>("""
                select s.id, s.line_id, l.name as line_name, s.name as stop_name
                from line_stops s join lines l on l.id = s.line_id
                where s.id = @stopId and s.line_id = @lineId
                """, new { stopId = request.StopId, lineId = request.LineId });
            if (stop is null) return Results.BadRequest(new { error = "Trạm không hợp lệ" });

            var code = Random.Shared.Next(1000, 9999).ToString();
            var id = await conn.ExecuteScalarAsync<Guid>("""
                insert into e_tickets (passenger_id, line_id, stop_id, code, qr_token, expires_at)
                values (@userId, @lineId, @stopId, @code, @qr, now() + interval '30 minutes')
                returning id
                """, new
            {
                userId = http.User.GetUserId(),
                lineId = request.LineId,
                stopId = request.StopId,
                code,
                qr = Guid.NewGuid().ToString("N")
            });

            var ticket = await GetTicketAsync(conn, id);
            return Results.Created($"/api/daily/e-tickets/{id}", ticket);
        }).RequireAuthorization();

        group.MapGet("/e-tickets/{id:guid}", async (
            Guid id, HttpContext http, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var ticket = await GetTicketAsync(conn, id);
            if (ticket is null) return Results.NotFound();
            var userId = http.User.GetUserId();
            if (ticket.Id != Guid.Empty && ticketDriverId(ticket) != userId && !await IsOwner(conn, id, userId))
                return Results.Forbid();
            return Results.Ok(ticket);
        }).RequireAuthorization();

        group.MapPost("/e-tickets/{id:guid}/assign", async (
            Guid id, HttpContext http, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var driverId = http.User.GetUserId();
            if (!await DriverVerification.IsApprovedAsync(conn, driverId, ct))
                return Results.Json(new { error = "Tài xế chưa được xác thực." },
                    statusCode: StatusCodes.Status403Forbidden);
            var affected = await conn.ExecuteAsync("""
                update e_tickets set driver_id = @driverId, status = 'assigned', assigned_at = now()
                where id = @id and status = 'waiting' and driver_id is null
                """, new { id, driverId });
            if (affected == 0) return Results.Conflict(new { error = "Vé đã có tài xế hoặc không còn chờ" });
            return Results.Ok(await GetTicketAsync(conn, id));
        }).RequireAuthorization();

        group.MapPost("/e-tickets/{id:guid}/validate", async (
            Guid id, ValidateTicketRequest request, HttpContext http, Db db,
            CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var driverId = http.User.GetUserId();
            if (!await DriverVerification.IsApprovedAsync(conn, driverId, ct))
                return Results.Json(new { error = "Tài xế chưa được xác thực." },
                    statusCode: StatusCodes.Status403Forbidden);
            await using var tx = await conn.BeginTransactionAsync(ct);
            var ticket = await conn.QuerySingleOrDefaultAsync<dynamic>("""
                select id, passenger_id, driver_id, code, status, stop_id, line_id
                from e_tickets where id = @id
                """, new { id }, tx);
            if (ticket is null)
            {
                await tx.RollbackAsync(ct);
                return Results.NotFound();
            }

            if ((Guid?)ticket.driver_id != driverId)
            {
                await tx.RollbackAsync(ct);
                return Results.Forbid();
            }
            if ((string)ticket.status == "validated")
            {
                await tx.RollbackAsync(ct);
                return Results.Conflict(new { error = "Vé đã được xác nhận" });
            }
            if ((string)ticket.code != request.Code.Trim())
            {
                await tx.RollbackAsync(ct);
                return Results.BadRequest(new { error = "Mã vé không đúng" });
            }

            var amount = await conn.ExecuteScalarAsync<long?>("""
                select least(max_amount_minor, greatest(min_amount_minor, per_km_minor * 5))
                from subsidy_rules
                where line_id = @lineId and effective_from <= current_date
                  and (effective_to is null or effective_to >= current_date)
                order by effective_from desc limit 1
                """, new { lineId = (Guid)ticket.line_id }, tx) ?? 200;

            await conn.ExecuteAsync("""
                update e_tickets set status = 'validated', validated_at = now() where id = @id
                """, new { id }, tx);
            var validationId = await conn.ExecuteScalarAsync<Guid>("""
                insert into trip_validations (e_ticket_id, driver_id, method, distance_km, amount_minor)
                values (@id, @driverId, 'code', 5, @amount)
                returning id
                """, new { id, driverId, amount }, tx);
            await conn.ExecuteAsync("""
                insert into driver_earnings (driver_id, validation_id, amount_minor, period)
                values (@driverId, @validationId, @amount, date_trunc('month', now())::date)
                """, new { driverId, validationId, amount }, tx);
            await Notifier.NotifyAsync(conn, tx, (Guid)ticket.passenger_id, "ticket.validated",
                "Đã lên xe", "Tài xế đã xác nhận vé của bạn.");
            await tx.CommitAsync(ct);
            return Results.Ok(await GetTicketAsync(conn, id));
        }).RequireAuthorization();

        group.MapGet("/my-tickets", async (HttpContext http, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var ids = (await conn.QueryAsync<Guid>(
                "select id from e_tickets where passenger_id = @userId order by created_at desc limit 50",
                new { userId = http.User.GetUserId() })).ToList();
            var list = new List<ETicketDto?>();
            foreach (var id in ids) list.Add(await GetTicketAsync(conn, id));
            return Results.Ok(list.Where(x => x is not null));
        }).RequireAuthorization();

        group.MapGet("/driver/queue", async (HttpContext http, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var ids = (await conn.QueryAsync<Guid>("""
                select id from e_tickets
                where status = 'waiting'
                   or (driver_id = @driverId and status in ('assigned','validated'))
                order by created_at desc
                limit 50
                """, new { driverId = http.User.GetUserId() })).ToList();
            var list = new List<ETicketDto?>();
            foreach (var id in ids) list.Add(await GetTicketAsync(conn, id));
            return Results.Ok(list.Where(x => x is not null));
        }).RequireAuthorization();

        group.MapGet("/partner/summary", async (Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var summary = new
            {
                ticketsToday = await conn.ExecuteScalarAsync<int>(
                    "select count(*) from e_tickets where created_at >= current_date"),
                validationsToday = await conn.ExecuteScalarAsync<int>(
                    "select count(*) from trip_validations where validated_at >= current_date"),
                amountMinor = await conn.ExecuteScalarAsync<long>(
                    "select coalesce(sum(amount_minor),0) from trip_validations where validated_at >= current_date"),
                activeLines = await conn.ExecuteScalarAsync<int>(
                    "select count(*) from lines where status = 'active'"),
                costPerTripMinor = await conn.ExecuteScalarAsync<long>("""
                    select coalesce(avg(amount_minor), 0)::bigint from trip_validations
                    where validated_at >= current_date
                    """)
            };
            return Results.Ok(summary);
        }).RequireAuthorization("admin");

        return app;
    }

    private static Guid ticketDriverId(ETicketDto t) => t.DriverId ?? Guid.Empty;

    private static async Task<bool> IsOwner(NpgsqlConnection conn, Guid ticketId, Guid userId)
        => await conn.ExecuteScalarAsync<bool>(
            "select exists(select 1 from e_tickets where id = @ticketId and passenger_id = @userId)",
            new { ticketId, userId });

    private static async Task<ETicketDto?> GetTicketAsync(NpgsqlConnection conn, Guid id)
    {
        var row = await conn.QuerySingleOrDefaultAsync<dynamic>("""
            select t.id, t.line_id, l.name as line_name, t.stop_id, s.name as stop_name,
                   t.status, t.code, t.qr_token, t.created_at, t.expires_at,
                   t.driver_id, d.full_name as driver_name, t.validated_at,
                   p.full_name as passenger_name,
                   (select amount_minor from trip_validations v where v.e_ticket_id = t.id) as amount_minor
            from e_tickets t
            join lines l on l.id = t.line_id
            join line_stops s on s.id = t.stop_id
            left join users d on d.id = t.driver_id
            join users p on p.id = t.passenger_id
            where t.id = @id
            """, new { id });
        if (row is null) return null;

        return new ETicketDto(
            (Guid)row.id, (Guid)row.line_id, (string)row.line_name,
            (Guid)row.stop_id, (string)row.stop_name, (string)row.status,
            (string)row.code, (string)row.qr_token,
            Time.ToDto((DateTime)row.created_at), Time.ToDto((DateTime)row.expires_at),
            (Guid?)row.driver_id, (string?)row.driver_name,
            row.validated_at is null ? null : Time.ToDto((DateTime)row.validated_at),
            (long?)row.amount_minor, (string?)row.passenger_name);
    }
}
