using Dapper;
using Npgsql;
using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Services;

public sealed class ReadService(Db db)
{
    private const string TripSql = """
        select t.id, t.driver_id, t.vehicle_id,
               ST_Y(t.origin::geometry) as origin_lat,
               ST_X(t.origin::geometry) as origin_lng,
               ST_Y(t.destination::geometry) as destination_lat,
               ST_X(t.destination::geometry) as destination_lng,
               t.origin_label, t.destination_label, t.departure_time, t.arrive_estimate,
               t.price_per_seat, t.seats_total, t.seats_available, t.booking_mode,
               t.luggage, t.pets_allowed, t.smoking_allowed, t.status,
               t.distance_m, t.duration_s,
               u.phone as driver_phone, u.full_name as driver_name,
               u.avatar_url as driver_avatar_url, u.role as driver_role,
               u.verified_level as driver_verified_level,
               u.rating_avg as driver_rating_avg, u.rating_count as driver_rating_count,
               v.make as vehicle_make, v.model as vehicle_model, v.year as vehicle_year,
               v.color as vehicle_color, v.plate as vehicle_plate,
               v.seats as vehicle_seats, v.status as vehicle_status
        from trips t
        join users u on u.id = t.driver_id
        join vehicles v on v.id = t.vehicle_id
        where t.id = @id
        """;

    private const string StopsSql = """
        select id, trip_id, seq, name,
               ST_Y(location::geometry) as lat,
               ST_X(location::geometry) as lng,
               eta_offset_min, allow_pickup, allow_dropoff, price_from_origin
        from trip_stops
        where trip_id = @tripId
        order by seq
        """;

    private const string BookingSql = """
        select b.id, b.trip_id, b.passenger_id, b.from_stop_id, b.to_stop_id, b.seats,
               b.price_total, b.fee_amount, b.status, b.idempotency_key, b.expires_at, b.created_at,
               t.driver_id as driver_id,
               p.full_name as passenger_name, p.phone as passenger_phone,
               p.avatar_url as passenger_avatar_url, p.role as passenger_role,
               p.verified_level as passenger_verified_level,
               p.rating_avg as passenger_rating_avg, p.rating_count as passenger_rating_count,
               d.full_name as driver_name, d.phone as driver_phone,
               d.avatar_url as driver_avatar_url, d.role as driver_role,
               d.verified_level as driver_verified_level,
               d.rating_avg as driver_rating_avg, d.rating_count as driver_rating_count,
               t.origin_label, t.destination_label, t.departure_time,
               v.make as vehicle_make, v.model as vehicle_model, v.plate as vehicle_plate
        from bookings b
        join users p on p.id = b.passenger_id
        join trips t on t.id = b.trip_id
        join users d on d.id = t.driver_id
        join vehicles v on v.id = t.vehicle_id
        where b.id = @id
        """;

    public async Task<TripRow?> GetTripRowAsync(Guid id, CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<TripRow>(TripSql, new { id });
    }

    public async Task<List<StopRow>> GetStopsAsync(Guid tripId, CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync(ct);
        return (await conn.QueryAsync<StopRow>(StopsSql, new { tripId })).ToList();
    }

    public async Task<TripDto?> GetTripAsync(Guid id, CancellationToken ct = default)
    {
        var row = await GetTripRowAsync(id, ct);
        if (row is null) return null;
        var stops = await GetStopsAsync(id, ct);
        return row.ToTrip(stops);
    }

    public async Task<BookingRow?> GetBookingRowAsync(Guid id, CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<BookingRow>(BookingSql, new { id });
    }

    public async Task<BookingDto?> GetBookingAsync(Guid id, CancellationToken ct = default)
        => (await GetBookingsAsync([id], ct)).FirstOrDefault();

    /// <summary>Loads a page of bookings with one connection; avoids re-opening
    /// a connection per booking in list endpoints.</summary>
    public async Task<IReadOnlyList<BookingDto>> GetBookingsAsync(
        IReadOnlyCollection<Guid> ids, CancellationToken ct = default)
    {
        if (ids.Count == 0) return [];
        await using var conn = await db.OpenAsync(ct);
        var rows = (await conn.QueryAsync<BookingRow>(
            BookingSql.Replace("where b.id = @id", "where b.id = any(@ids)"),
            new { ids = ids.ToArray() }))
            .ToDictionary(r => r.Id);
        var result = new List<BookingDto>(ids.Count);
        foreach (var id in ids)
        {
            if (!rows.TryGetValue(id, out var row)) continue;
            var stops = (await conn.QueryAsync<StopRow>(StopsSql, new { tripId = row.TripId }))
                .ToDictionary(s => s.Id);
            var payment = await conn.QuerySingleOrDefaultAsync<PaymentRow>(
                "select id, booking_id, amount, currency, status, provider, captured_at from payments where booking_id = @id",
                new { id });
            stops.TryGetValue(row.FromStopId, out var from);
            stops.TryGetValue(row.ToStopId, out var to);
            var revealContact = row.Status is "confirmed" or "completed";
            var passenger = new UserDto(row.PassengerId,
                revealContact ? row.PassengerPhone : Privacy.MaskPhone(row.PassengerPhone),
                row.PassengerName, null, row.PassengerAvatarUrl, null, row.PassengerRole,
                row.PassengerVerifiedLevel, row.PassengerRatingAvg, row.PassengerRatingCount);
            var driver = new UserDto(row.DriverId,
                revealContact ? row.DriverPhone : Privacy.MaskPhone(row.DriverPhone),
                row.DriverName, null, row.DriverAvatarUrl, null, row.DriverRole,
                row.DriverVerifiedLevel, row.DriverRatingAvg, row.DriverRatingCount);
            result.Add(new BookingDto(
                row.Id, row.TripId, passenger, driver,
                from?.ToStop() ?? new StopDto(row.FromStopId, 0, "", 0, 0, 0, false, false, 0),
                to?.ToStop() ?? new StopDto(row.ToStopId, 0, "", 0, 0, 0, false, false, 0),
                row.Seats, row.PriceTotal, row.Status, row.ExpiresAt, row.CreatedAt,
                new TripSummaryDto(row.TripId, row.OriginLabel, row.DestinationLabel, row.DepartureTime,
                    row.DriverName, $"{row.VehicleMake} {row.VehicleModel}", row.VehiclePlate),
                payment?.ToPayment()));
        }
        return result;
    }

    public async Task<UserDto?> GetUserAsync(Guid id, CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync(ct);
        var row = await conn.QuerySingleOrDefaultAsync<UserRow>(
            "select * from users where id = @id", new { id });
        return row?.ToUser();
    }

    public async Task<List<ReviewDto>> GetReviewsAsync(Guid userId, CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync(ct);
        var rows = await conn.QueryAsync<dynamic>("""
            select r.id, r.booking_id, r.reviewer_id, u.full_name as reviewer_name,
                   r.reviewee_id, r.rating, r.comment, r.role, r.created_at
            from reviews r
            join users u on u.id = r.reviewer_id
            where r.reviewee_id = @userId
            order by r.created_at desc
            limit 50
            """, new { userId });
        return rows.Select(r => new ReviewDto(
            (Guid)r.id, (Guid)r.booking_id, (Guid)r.reviewer_id, (string)r.reviewer_name,
            (Guid)r.reviewee_id, (short)r.rating, (string?)r.comment, (string)r.role,
            Time.ToDto((DateTime)r.created_at))).ToList();
    }
}
