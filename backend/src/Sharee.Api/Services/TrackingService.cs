using Dapper;
using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Services;

public sealed class TrackingService(Db db)
{
    public async Task<TripTrackingDto?> GetAsync(Guid tripId, Guid userId, CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync(ct);
        return await BuildAsync(conn, tripId, userId);
    }

    public async Task<TripTrackingDto?> UpdateLocationAsync(
        Guid tripId, Guid userId, LocationUpdateRequest request, CancellationToken ct = default)
    {
        if (request.Lat is < -90 or > 90 || request.Lng is < -180 or > 180)
            throw new ArgumentException("Toạ độ không hợp lệ");

        await using var conn = await db.OpenAsync(ct);
        var trip = await conn.QuerySingleOrDefaultAsync<dynamic>(
            "select driver_id, status from trips where id = @tripId", new { tripId });
        if (trip is null) return null;

        var isDriver = (Guid)trip.driver_id == userId;
        if (!isDriver)
        {
            var isPassenger = await conn.ExecuteScalarAsync<int>("""
                select count(*) from bookings
                where trip_id = @tripId and passenger_id = @userId
                  and status not like 'cancelled%'
                """, new { tripId, userId });
            if (isPassenger == 0) return null;
        }

        await conn.ExecuteAsync("""
            insert into trip_locations (trip_id, user_id, role, lat, lng, heading, speed, accuracy, updated_at)
            values (@tripId, @userId, @role, @lat, @lng, @heading, @speed, @accuracy, now())
            on conflict (trip_id, user_id) do update set
                lat = excluded.lat, lng = excluded.lng, heading = excluded.heading,
                speed = excluded.speed, accuracy = excluded.accuracy, updated_at = now()
            """, new
        {
            tripId, userId, role = isDriver ? "driver" : "passenger",
            request.Lat, request.Lng, request.Heading, request.Speed, request.Accuracy
        });

        if (isDriver)
        {
            await conn.ExecuteAsync("""
                update trips set tracking_status = 'en_route'
                where id = @tripId and tracking_status = 'scheduled'
                """, new { tripId });
        }

        return await BuildAsync(conn, tripId, userId);
    }

    public async Task<TripTrackingDto?> SetStatusAsync(
        Guid tripId, Guid userId, string status, CancellationToken ct = default)
    {
        var normalized = status switch
        {
            "en_route" => "en_route",
            "arrived" => "arrived",
            "in_progress" => "in_progress",
            "completed" => "completed",
            _ => throw new ArgumentException("Trạng thái theo dõi không hợp lệ")
        };

        await using var conn = await db.OpenAsync(ct);
        var trip = await conn.QuerySingleOrDefaultAsync<dynamic>(
            "select driver_id from trips where id = @tripId", new { tripId });
        if (trip is null || (Guid)trip.driver_id != userId) return null;

        await using var tx = await conn.BeginTransactionAsync(ct);
        await conn.ExecuteAsync("""
            update trips set
                tracking_status = @normalized,
                status = case
                    when @normalized = 'in_progress' then 'ongoing'
                    when @normalized = 'completed' then 'completed'
                    else status
                end,
                started_at = case when @normalized = 'in_progress' then coalesce(started_at, now()) else started_at end,
                completed_at = case when @normalized = 'completed' then now() else completed_at end
            where id = @tripId
            """, new { tripId, normalized }, tx);

        // Tracking is a location/status signal only. Money is moved by
        // BookingSettlementService from the driver's /complete endpoint or the
        // admin appeal resolution; never from a tracking update.

        await tx.CommitAsync(ct);
        return await BuildAsync(conn, tripId, userId);
    }

    private static async Task<TripTrackingDto?> BuildAsync(
        Npgsql.NpgsqlConnection conn, Guid tripId, Guid userId)
    {
        var trip = await conn.QuerySingleOrDefaultAsync<dynamic>("""
            select t.id, t.driver_id, t.status, t.tracking_status, t.started_at, t.vehicle_id,
                   u.full_name as driver_name, u.phone as driver_phone,
                   v.id as vehicle_id, v.make, v.model, v.year, v.color, v.plate, v.seats, v.status as vehicle_status
            from trips t
            join users u on u.id = t.driver_id
            join vehicles v on v.id = t.vehicle_id
            where t.id = @tripId
            """, new { tripId });
        if (trip is null) return null;

        var isDriver = (Guid)trip.driver_id == userId;
        var booking = await conn.QuerySingleOrDefaultAsync<dynamic>("""
            select from_stop_id, to_stop_id, status
            from bookings
            where trip_id = @tripId and passenger_id = @userId
              and status not like 'cancelled%'
            order by created_at desc limit 1
            """, new { tripId, userId });
        if (!isDriver && booking is null) return null;

        var stopRows = (await conn.QueryAsync<dynamic>("""
            select id, seq, name,
                   ST_Y(location::geometry) as lat, ST_X(location::geometry) as lng,
                   eta_offset_min, allow_pickup, allow_dropoff, price_from_origin
            from trip_stops where trip_id = @tripId order by seq
            """, new { tripId })).ToList();
        if (stopRows.Count == 0) return null;

        var stops = stopRows.Select(r => new StopDto(
            (Guid)r.id, (int)(short)r.seq, (string)r.name, (double)r.lat, (double)r.lng,
            (int)r.eta_offset_min, (bool)r.allow_pickup, (bool)r.allow_dropoff,
            (int)r.price_from_origin)).ToList();

        StopDto pickup = stops[0];
        StopDto dropoff = stops[^1];
        if (booking is not null)
        {
            var fromId = (Guid)booking.from_stop_id;
            var toId = (Guid)booking.to_stop_id;
            pickup = stops.FirstOrDefault(s => s.Id == fromId) ?? pickup;
            dropoff = stops.FirstOrDefault(s => s.Id == toId) ?? dropoff;
        }

        var driverRow = await conn.QuerySingleOrDefaultAsync<dynamic>("""
            select l.user_id, l.role, l.lat, l.lng, l.heading, l.speed, l.updated_at, u.full_name
            from trip_locations l join users u on u.id = l.user_id
            where l.trip_id = @tripId and l.role = 'driver'
            order by l.updated_at desc limit 1
            """, new { tripId });
        var passengerRows = (await conn.QueryAsync<dynamic>("""
            select l.user_id, l.role, l.lat, l.lng, l.heading, l.speed, l.updated_at, u.full_name
            from trip_locations l join users u on u.id = l.user_id
            where l.trip_id = @tripId and l.role = 'passenger'
            order by l.updated_at desc
            """, new { tripId })).ToList();

        LivePositionDto? driver = driverRow is null ? null : ToPosition(driverRow);
        var passengers = new List<LivePositionDto>();
        foreach (var row in passengerRows) passengers.Add(ToPosition(row));

        var trackingStatus = (string)trip.tracking_status;
        var target = trackingStatus is "scheduled" or "en_route" ? pickup : dropoff;
        var fromLat = driver is null ? pickup.Lat : driver.Lat;
        var fromLng = driver is null ? pickup.Lng : driver.Lng;
        var distance = Pricing.HaversineMeters(fromLat, fromLng, target.Lat, target.Lng);
        var eta = trackingStatus == "completed" || trackingStatus == "arrived"
            ? 0
            : (int)Math.Ceiling(distance / 1000.0 / 25.0 * 60.0);
        if (trackingStatus == "arrived") distance = 0;

        return new TripTrackingDto(
            (Guid)trip.id, (Guid)trip.driver_id, (string)trip.status, trackingStatus,
            (string)trip.driver_name, (string)trip.driver_phone,
            new VehicleDto((Guid)trip.vehicle_id, (string)trip.make, (string)trip.model,
                (int?)trip.year, (string?)trip.color, (string)trip.plate,
                (short)trip.seats, (string)trip.vehicle_status),
            pickup, dropoff,
            stops.Select(s => new LatLngDto(s.Lat, s.Lng)).ToList(),
            driver, passengers, Math.Max(0, eta), Math.Round(distance / 1000.0, 1),
            trip.started_at is null ? null : Time.ToDto((DateTime)trip.started_at));
    }

    private static LivePositionDto ToPosition(dynamic row) => new(
        (Guid)row.user_id, (string)row.full_name, (string)row.role,
        (double)row.lat, (double)row.lng, (double?)row.heading, (double?)row.speed,
        Time.ToDto((DateTime)row.updated_at));
}
