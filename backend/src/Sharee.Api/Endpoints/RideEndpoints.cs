using Dapper;
using Npgsql;
using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Api.Endpoints;

public static class RideEndpoints
{
    private const string RideSelect = """
        select r.id, r.passenger_id, pu.full_name as passenger_name, pu.rating_avg as passenger_rating,
               r.pickup_label, ST_Y(r.pickup::geometry) as pickup_lat, ST_X(r.pickup::geometry) as pickup_lng,
               r.dropoff_label, ST_Y(r.dropoff::geometry) as dropoff_lat, ST_X(r.dropoff::geometry) as dropoff_lng,
               r.vehicle_class, r.payment_method, r.note, r.status,
               r.driver_id, du.full_name as driver_name, du.avatar_url as driver_avatar,
               du.rating_avg as driver_rating, du.rating_count as driver_rating_count, du.phone as driver_phone,
               v.make, v.model, v.plate, v.color,
               r.created_at, r.accepted_at, r.arrived_at, r.started_at, r.completed_at
        from ride_requests r
        join users pu on pu.id = r.passenger_id
        left join users du on du.id = r.driver_id
        left join vehicles v on v.id = r.vehicle_id
        """;

    public static IEndpointRouteBuilder MapRideEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/geo/search", async (string? q, int? limit, GeoService geo, CancellationToken ct) =>
        {
            var items = await geo.SearchAsync(q ?? "", limit ?? 6);
            return Results.Ok(items);
        }).RequireAuthorization().WithTags("Rides");

        app.MapGet("/api/geo/reverse", async (double lat, double lng, GeoService geo) =>
        {
            if (!ValidPoint(lat, lng)) return Results.BadRequest(new { message = "Toạ độ không hợp lệ." });
            return Results.Ok(await geo.ReverseAsync(lat, lng));
        }).RequireAuthorization().WithTags("Rides");

        app.MapGet("/api/drivers/nearby", async (
            double lat, double lng, double? radiusKm, HttpContext http, Db db, CancellationToken ct) =>
        {
            if (!ValidPoint(lat, lng)) return Results.BadRequest(new { message = "Toạ độ không hợp lệ." });
            var radius = Math.Clamp(radiusKm ?? 10, 1, 30);
            await using var conn = await db.OpenAsync(ct);
            var rows = await conn.QueryAsync("""
                select p.driver_id, u.full_name, u.rating_avg, u.rating_count,
                       coalesce(nullif(trim(concat_ws(' ', v.make, v.model)), ''), 'Xe') as vehicle_label,
                       v.plate,
                       ST_Y(p.location::geometry) as lat, ST_X(p.location::geometry) as lng,
                       ST_Distance(p.location, ST_SetSRID(ST_MakePoint(@lng, @lat), 4326)::geography) as distance_m
                from driver_presence p
                join users u on u.id = p.driver_id
                left join vehicles v on v.id = p.vehicle_id
                where p.online
                  and p.updated_at > now() - interval '24 hours'
                  and ST_DWithin(p.location, ST_SetSRID(ST_MakePoint(@lng, @lat), 4326)::geography, @radiusM)
                order by distance_m
                limit 20
                """, new { lat, lng, radiusM = radius * 1000 });
            var list = rows.Select(row => new NearbyDriverDto(
                (Guid)row.driver_id,
                (string)row.full_name,
                row.rating_avg is null ? 5.0 : Convert.ToDouble(row.rating_avg),
                row.rating_count is null ? 0 : (int)row.rating_count,
                (string?)row.vehicle_label,
                (string?)row.plate,
                (double)row.lat,
                (double)row.lng,
                Math.Max(2, (int)Math.Ceiling((double)row.distance_m / 1000.0 / 25.0 * 60.0))
            )).ToList();
            return Results.Ok(list);
        }).RequireAuthorization().WithTags("Rides");

        app.MapGet("/api/driver/presence", async (HttpContext http, Db db, CancellationToken ct) =>
        {
            var driverId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            var row = await conn.QuerySingleOrDefaultAsync("""
                select online, ST_Y(location::geometry) as lat, ST_X(location::geometry) as lng,
                       vehicle_id, updated_at
                from driver_presence where driver_id = @driverId
                """, new { driverId });
            if (row is null)
                return Results.Ok(new DriverPresenceDto(false, 21.0278, 105.8342, null, DateTimeOffset.UtcNow));
            return Results.Ok(new DriverPresenceDto(
                (bool)row.online, (double)row.lat, (double)row.lng,
                (Guid?)row.vehicle_id, Time.ToDto((DateTime)row.updated_at)));
        }).RequireAuthorization().WithTags("Rides");

        app.MapPut("/api/driver/presence", async (
            UpdateDriverPresenceRequest request, HttpContext http, Db db, CancellationToken ct) =>
        {
            var driverId = http.User.GetUserId();
            if (!ValidPoint(request.Lat, request.Lng))
                return Results.BadRequest(new { message = "Toạ độ không hợp lệ." });
            await using var conn = await db.OpenAsync(ct);
            if (!await IsDriverAsync(conn, driverId, ct))
                return Results.Json(new { message = "Tài khoản này chưa phải tài xế." }, statusCode: 403);
            if (request.Online && !await DriverVerification.IsApprovedAsync(conn, driverId, ct))
                return Results.Json(new { message = "Hồ sơ tài xế chưa được duyệt." }, statusCode: 403);

            var vehicleId = request.VehicleId;
            if (vehicleId is null)
                vehicleId = await conn.ExecuteScalarAsync<Guid?>("""
                    select id from vehicles where owner_id = @driverId and status = 'active'
                    order by created_at limit 1
                    """, new { driverId });

            await conn.ExecuteAsync("""
                insert into driver_presence (driver_id, vehicle_id, online, location, updated_at)
                values (@driverId, @vehicleId, @online,
                        ST_SetSRID(ST_MakePoint(@lng, @lat), 4326)::geography, now())
                on conflict (driver_id) do update set
                  vehicle_id = excluded.vehicle_id,
                  online = excluded.online,
                  location = excluded.location,
                  updated_at = now()
                """, new { driverId, vehicleId, online = request.Online, lat = request.Lat, lng = request.Lng });

            var row = await conn.QuerySingleAsync("""
                select online, ST_Y(location::geometry) as lat, ST_X(location::geometry) as lng,
                       vehicle_id, updated_at
                from driver_presence where driver_id = @driverId
                """, new { driverId });
            return Results.Ok(new DriverPresenceDto(
                (bool)row.online, (double)row.lat, (double)row.lng,
                (Guid?)row.vehicle_id, Time.ToDto((DateTime)row.updated_at)));
        }).RequireAuthorization().WithTags("Rides");

        app.MapGet("/api/driver/rides/incoming", async (
            HttpContext http, Db db, CancellationToken ct) =>
        {
            var driverId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            if (!await IsDriverAsync(conn, driverId, ct))
                return Results.Json(new { message = "Tài khoản này chưa phải tài xế." }, statusCode: 403);
            var rows = await conn.QueryAsync(RideSelect + """

                join driver_presence p on p.driver_id = @driverId
                where r.status = 'searching'
                  and r.created_at > now() - interval '30 minutes'
                  and (p.location is null or ST_DWithin(p.location, r.pickup, 12000))
                order by ST_Distance(p.location, r.pickup)
                limit 20
                """, new { driverId });
            return Results.Ok(rows.Select(MapRide).ToList());
        }).RequireAuthorization().WithTags("Rides");

        app.MapGet("/api/driver/rides/current", async (
            HttpContext http, Db db, CancellationToken ct) =>
        {
            var driverId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            var row = await conn.QuerySingleOrDefaultAsync(RideSelect + """

                where r.driver_id = @driverId
                  and r.status in ('accepted','driver_arriving','arrived','in_progress')
                order by r.accepted_at desc limit 1
                """, new { driverId });
            return row is null ? Results.Ok(null) : Results.Ok(MapRide(row));
        }).RequireAuthorization().WithTags("Rides");

        app.MapPost("/api/rides", async (
            CreateRideRequestDto request, HttpContext http, Db db, CancellationToken ct) =>
        {
            var passengerId = http.User.GetUserId();
            if (!ValidPoint(request.PickupLat, request.PickupLng) ||
                !ValidPoint(request.DropoffLat, request.DropoffLng))
                return Results.BadRequest(new { message = "Toạ độ không hợp lệ." });
            var pickup = CleanLabel(request.PickupLabel);
            var dropoff = CleanLabel(request.DropoffLabel);
            if (pickup.Length < 2 || dropoff.Length < 2)
                return Results.BadRequest(new { message = "Vui lòng chọn điểm đón và điểm đến." });
            var payment = request.PaymentMethod is "cash" or "bank" or "wallet"
                ? request.PaymentMethod : "cash";
            var vehicle = request.VehicleClass is "bike" or "car" or "premium"
                ? request.VehicleClass : "car";

            await using var conn = await db.OpenAsync(ct);
            var activeRequests = await conn.ExecuteScalarAsync<int>("""
                select count(*) from ride_requests
                where passenger_id = @passengerId
                  and status in ('searching','accepted','driver_arriving','arrived','in_progress')
                  and created_at > now() - interval '2 hours'
                """, new { passengerId });
            if (activeRequests >= 2)
                return Results.Conflict(new { message = "Bạn đang có chuyến đang xử lý. Hãy hoàn tất hoặc huỷ trước." });

            await using var tx = await conn.BeginTransactionAsync(ct);
            var id = await conn.ExecuteScalarAsync<Guid>("""
                insert into ride_requests
                  (passenger_id, pickup, dropoff, pickup_label, dropoff_label,
                   vehicle_class, payment_method, note)
                values (@passengerId,
                        ST_SetSRID(ST_MakePoint(@pickupLng, @pickupLat), 4326)::geography,
                        ST_SetSRID(ST_MakePoint(@dropoffLng, @dropoffLat), 4326)::geography,
                        @pickup, @dropoff, @vehicle, @payment, @note)
                returning id
                """, new
            {
                passengerId,
                pickupLng = request.PickupLng,
                pickupLat = request.PickupLat,
                dropoffLng = request.DropoffLng,
                dropoffLat = request.DropoffLat,
                pickup,
                dropoff,
                vehicle,
                payment,
                note = string.IsNullOrWhiteSpace(request.Note) ? null : request.Note.Trim()
            }, tx);

            var drivers = (await conn.QueryAsync<Guid>("""
                select p.driver_id from driver_presence p
                join users u on u.id = p.driver_id
                where p.online
                  and p.driver_id <> @passengerId
                  and p.updated_at > now() - interval '24 hours'
                  and ST_DWithin(
                        p.location,
                        ST_SetSRID(ST_MakePoint(@pickupLng, @pickupLat), 4326)::geography,
                        12000)
                order by ST_Distance(
                    p.location,
                    ST_SetSRID(ST_MakePoint(@pickupLng, @pickupLat), 4326)::geography)
                limit 20
                """, new { passengerId, pickupLng = request.PickupLng, pickupLat = request.PickupLat }, tx)).ToList();

            foreach (var driverId in drivers)
            {
                await Notifier.NotifyAsync(conn, tx, driverId, "ride.request",
                    "Có chuyến mới gần bạn", $"{pickup} → {dropoff}");
            }

            await tx.CommitAsync(ct);
            var row = await conn.QuerySingleAsync(RideSelect + " where r.id = @id", new { id });
            return Results.Created($"/api/rides/{id}", MapRide(row));
        }).RequireAuthorization().WithTags("Rides");

        app.MapGet("/api/rides/mine", async (HttpContext http, Db db, CancellationToken ct) =>
        {
            var userId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            var rows = await conn.QueryAsync(RideSelect + """
                where r.passenger_id = @userId
                order by r.created_at desc limit 50
                """, new { userId });
            return Results.Ok(rows.Select(MapRide).ToList());
        }).RequireAuthorization().WithTags("Rides");

        app.MapGet("/api/rides/{id:guid}", async (
            Guid id, HttpContext http, Db db, CancellationToken ct) =>
        {
            var userId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            var row = await conn.QuerySingleOrDefaultAsync(RideSelect + " where r.id = @id", new { id });
            if (row is null) return Results.NotFound();
            var passengerId = (Guid)row.passenger_id;
            Guid? driverId = (Guid?)row.driver_id;
            if (passengerId != userId && driverId != userId)
                return Results.Forbid();
            return Results.Ok(MapRide(row));
        }).RequireAuthorization().WithTags("Rides");

        app.MapPost("/api/rides/{id:guid}/accept", async (
            Guid id, HttpContext http, Db db, CancellationToken ct) =>
        {
            var driverId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            if (!await IsDriverAsync(conn, driverId, ct))
                return Results.Json(new { message = "Tài khoản này chưa phải tài xế." }, statusCode: 403);
            if (!await DriverVerification.IsApprovedAsync(conn, driverId, ct))
                return Results.Json(new { message = "Hồ sơ tài xế chưa được duyệt." }, statusCode: 403);

            var vehicleId = await conn.ExecuteScalarAsync<Guid?>("""
                select id from vehicles where owner_id = @driverId and status = 'active'
                order by created_at limit 1
                """, new { driverId });

            await using var tx = await conn.BeginTransactionAsync(ct);
            var row = await conn.QuerySingleOrDefaultAsync("""
                update ride_requests
                set status = 'accepted', driver_id = @driverId, vehicle_id = @vehicleId,
                    accepted_at = now(), updated_at = now()
                where id = @id and status = 'searching' and passenger_id <> @driverId
                  and not exists (
                    select 1 from ride_requests active
                    where active.driver_id = @driverId
                      and active.status in ('accepted','driver_arriving','arrived','in_progress'))
                returning passenger_id, pickup_label, dropoff_label
                """, new { id, driverId, vehicleId }, tx);
            if (row is null)
            {
                await tx.RollbackAsync(ct);
                return Results.Conflict(new { message = "Chuyến đã có tài xế khác nhận." });
            }

            await Notifier.NotifyAsync(conn, tx, (Guid)row.passenger_id, "ride.accepted",
                "Tài xế đã nhận chuyến", "Tài xế đang đến điểm đón của bạn.");
            await tx.CommitAsync(ct);

            var ride = await conn.QuerySingleAsync(RideSelect + " where r.id = @id", new { id });
            return Results.Ok(MapRide(ride));
        }).RequireAuthorization().WithTags("Rides");

        app.MapPost("/api/rides/{id:guid}/arrive", async (
            Guid id, HttpContext http, Db db, CancellationToken ct) =>
        {
            var driverId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            await using var tx = await conn.BeginTransactionAsync(ct);
            var row = await conn.QuerySingleOrDefaultAsync("""
                update ride_requests set status = 'arrived', arrived_at = now(), updated_at = now()
                where id = @id and driver_id = @driverId and status = 'accepted'
                returning passenger_id
                """, new { id, driverId }, tx);
            if (row is null) { await tx.RollbackAsync(ct); return Results.Conflict(new { message = "Không thể cập nhật chuyến." }); }
            await Notifier.NotifyAsync(conn, tx, (Guid)row.passenger_id, "ride.arrived",
                "Tài xế đã đến", "Tài xế đang chờ bạn tại điểm đón.");
            await tx.CommitAsync(ct);
            var ride = await conn.QuerySingleAsync(RideSelect + " where r.id = @id", new { id });
            return Results.Ok(MapRide(ride));
        }).RequireAuthorization().WithTags("Rides");

        app.MapPost("/api/rides/{id:guid}/start", async (
            Guid id, HttpContext http, Db db, CancellationToken ct) =>
        {
            var driverId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            await using var tx = await conn.BeginTransactionAsync(ct);
            var row = await conn.QuerySingleOrDefaultAsync("""
                update ride_requests set status = 'in_progress', started_at = now(), updated_at = now()
                where id = @id and driver_id = @driverId and status in ('accepted','arrived')
                returning passenger_id
                """, new { id, driverId }, tx);
            if (row is null) { await tx.RollbackAsync(ct); return Results.Conflict(new { message = "Không thể bắt đầu chuyến." }); }
            await Notifier.NotifyAsync(conn, tx, (Guid)row.passenger_id, "ride.started",
                "Chuyến đã bắt đầu", "Bạn đang trên đường tới điểm đến.");
            await tx.CommitAsync(ct);
            var ride = await conn.QuerySingleAsync(RideSelect + " where r.id = @id", new { id });
            return Results.Ok(MapRide(ride));
        }).RequireAuthorization().WithTags("Rides");

        app.MapPost("/api/rides/{id:guid}/complete", async (
            Guid id, HttpContext http, Db db, CancellationToken ct) =>
        {
            var driverId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            await using var tx = await conn.BeginTransactionAsync(ct);
            var row = await conn.QuerySingleOrDefaultAsync("""
                update ride_requests set status = 'completed', completed_at = now(), updated_at = now()
                where id = @id and driver_id = @driverId and status = 'in_progress'
                returning passenger_id
                """, new { id, driverId }, tx);
            if (row is null) { await tx.RollbackAsync(ct); return Results.Conflict(new { message = "Không thể hoàn tất chuyến." }); }
            await Notifier.NotifyAsync(conn, tx, (Guid)row.passenger_id, "ride.completed",
                "Chuyến đã hoàn tất", "Cảm ơn bạn đã đi cùng Sharee. Thanh toán trực tiếp cho tài xế.");
            await tx.CommitAsync(ct);
            var ride = await conn.QuerySingleAsync(RideSelect + " where r.id = @id", new { id });
            return Results.Ok(MapRide(ride));
        }).RequireAuthorization().WithTags("Rides");

        app.MapPost("/api/rides/{id:guid}/cancel", async (
            Guid id, CancelRideRequest? request, HttpContext http, Db db, CancellationToken ct) =>
        {
            var userId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            var ride = await conn.QuerySingleOrDefaultAsync("""
                select passenger_id, driver_id, status from ride_requests where id = @id
                """, new { id });
            if (ride is null) return Results.NotFound();
            var passengerId = (Guid)ride.passenger_id;
            Guid? driverId = (Guid?)ride.driver_id;
            var status = (string)ride.status;
            if (userId != passengerId && userId != driverId) return Results.Forbid();
            if (status is "completed" or "cancelled")
                return Results.Conflict(new { message = "Chuyến đã kết thúc." });

            var affected = await conn.ExecuteAsync("""
                update ride_requests set status = 'cancelled', cancelled_at = now(),
                  cancel_reason = @reason, updated_at = now()
                where id = @id
                  and status in ('searching','accepted','arrived')
                  and (passenger_id = @userId or driver_id = @userId)
                """, new { id, userId, reason = string.IsNullOrWhiteSpace(request?.Reason) ? "Người dùng huỷ" : request!.Reason!.Trim() });
            if (affected == 0)
                return Results.Conflict(new { message = "Chuyến đã thay đổi trạng thái, không thể huỷ." });

            var otherId = userId == passengerId ? driverId : passengerId;
            if (otherId is not null)
                await Notifier.NotifyAsync(conn, null, otherId.Value, "ride.cancelled",
                    "Chuyến đã huỷ", "Chuyến đi vừa được huỷ.");
            return Results.Ok(new { status = "cancelled" });
        }).RequireAuthorization().WithTags("Rides");

        return app;
    }

    private static async Task<bool> IsDriverAsync(NpgsqlConnection conn, Guid userId, CancellationToken ct)
        => await conn.ExecuteScalarAsync<bool>("""
            select exists(
              select 1 from users u
              where u.id = @userId
                and (u.role = 'driver' or exists(
                  select 1 from vehicles v where v.owner_id = u.id and v.status = 'active'))
            )
            """, new { userId });

    private static bool ValidPoint(double lat, double lng)
        => lat is >= -90 and <= 90 && lng is >= -180 and <= 180 && !(lat == 0 && lng == 0);

    private static string CleanLabel(string value)
        => (value ?? "").Trim() is { Length: > 160 } s ? s[..160] : (value ?? "").Trim();

    private static RideDto MapRide(dynamic row)
    {
        Guid? driverId = (Guid?)row.driver_id;
        RideDriverDto? driver = null;
        if (driverId is not null)
        {
            var make = (string?)row.make ?? "";
            var model = (string?)row.model ?? "";
            var label = string.Join(' ', new[] { make, model }.Where(x => !string.IsNullOrWhiteSpace(x)));
            driver = new RideDriverDto(
                driverId.Value,
                (string?)row.driver_name ?? "Tài xế",
                (string?)row.driver_avatar,
                row.driver_rating is null ? 5.0 : Convert.ToDouble(row.driver_rating),
                row.driver_rating_count is null ? 0 : (int)row.driver_rating_count,
                label.Length == 0 ? "Xe" : label,
                (string?)row.plate,
                (string?)row.color,
                MaskPhone((string?)row.driver_phone));
        }

        return new RideDto(
            (Guid)row.id,
            (Guid)row.passenger_id,
            (string)row.passenger_name,
            row.passenger_rating is null ? null : Convert.ToDouble(row.passenger_rating),
            (string)row.pickup_label, (double)row.pickup_lat, (double)row.pickup_lng,
            (string)row.dropoff_label, (double)row.dropoff_lat, (double)row.dropoff_lng,
            (string)row.vehicle_class, (string)row.payment_method, (string?)row.note,
            (string)row.status, driver,
            Time.ToDto((DateTime)row.created_at),
            Time.ToDto((DateTime?)row.accepted_at),
            Time.ToDto((DateTime?)row.arrived_at),
            Time.ToDto((DateTime?)row.started_at),
            Time.ToDto((DateTime?)row.completed_at));
    }

    private static string? MaskPhone(string? phone)
    {
        if (string.IsNullOrWhiteSpace(phone) || phone.Length < 7) return null;
        return phone[..4] + "***" + phone[^3..];
    }
}
