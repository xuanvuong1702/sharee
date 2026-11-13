using System.Globalization;
using Dapper;
using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Services;

public sealed class RecurringTripService(Db db)
{
    private static readonly TimeZoneInfo VietnamTz =
        TimeZoneInfo.FindSystemTimeZoneById("Asia/Ho_Chi_Minh");

    public async Task<RecurringTripDto> CreateAsync(
        Guid driverId, CreateRecurringTripRequest request, CancellationToken ct = default)
    {
        if (request.Stops.Count < 2)
            throw new ArgumentException("Chuyến cần ít nhất 2 điểm đón/trả");
        if (request.Weekdays.Length == 0 || request.Weekdays.Any(d => d is < 1 or > 7))
            throw new ArgumentException("Ngày trong tuần không hợp lệ");
        if (!TimeOnly.TryParse(request.DepartureTime, out var departureTime))
            throw new ArgumentException("Giờ khởi hành không hợp lệ");
        if (request.PricePerSeat < 10000 || request.SeatsTotal is < 1 or > 8)
            throw new ArgumentException("Giá hoặc số ghế không hợp lệ");

        await using var conn = await db.OpenAsync(ct);
        var vehicle = await conn.QuerySingleOrDefaultAsync<VehicleRow>(
            "select * from vehicles where id = @id and owner_id = @ownerId and status = 'active'",
            new { id = request.VehicleId, ownerId = driverId });
        if (vehicle is null) throw new ArgumentException("Xe không hợp lệ");
        if (request.SeatsTotal > vehicle.Seats) throw new ArgumentException("Số ghế vượt quá số chỗ");

        var distance = 0.0;
        for (var i = 1; i < request.Stops.Count; i++)
        {
            distance += Pricing.HaversineMeters(
                request.Stops[i - 1].Lat, request.Stops[i - 1].Lng,
                request.Stops[i].Lat, request.Stops[i].Lng);
        }
        var durationSeconds = (int)Math.Max(600, distance / 17.0);
        var routeWkt = "SRID=4326;LINESTRING(" + string.Join(",", request.Stops.Select(s =>
            $"{s.Lng.ToString("F6", CultureInfo.InvariantCulture)} {s.Lat.ToString("F6", CultureInfo.InvariantCulture)}")) + ")";

        var cumulative = 0.0;
        var prices = new List<int> { 0 };
        for (var i = 1; i < request.Stops.Count; i++)
        {
            cumulative += Pricing.HaversineMeters(
                request.Stops[i - 1].Lat, request.Stops[i - 1].Lng,
                request.Stops[i].Lat, request.Stops[i].Lng);
            if (i == request.Stops.Count - 1)
            {
                prices.Add(request.PricePerSeat);
            }
            else
            {
                var maxMiddle = Math.Max(0, request.PricePerSeat - 1000);
                var computed = (int)Math.Round(request.PricePerSeat * cumulative / distance / 1000) * 1000;
                prices.Add(maxMiddle == 0 ? 0 : Math.Clamp(computed, 0, maxMiddle));
            }
        }

        await using var tx = await conn.BeginTransactionAsync(ct);
        var id = await conn.ExecuteScalarAsync<Guid>("""
            insert into recurring_trips (driver_id, vehicle_id, origin, destination,
                origin_label, destination_label, route, distance_m, duration_s,
                departure_time, weekdays, price_per_seat, seats_total, booking_mode,
                luggage, pets_allowed, smoking_allowed)
            values (@driverId, @vehicleId,
                ST_SetSRID(ST_MakePoint(@originLng, @originLat), 4326)::geography,
                ST_SetSRID(ST_MakePoint(@destLng, @destLat), 4326)::geography,
                @originLabel, @destLabel, ST_GeogFromText(@route), @distance, @duration,
                @departureTime::time, @weekdays, @price, @seatsTotal, @bookingMode,
                @luggage, @pets, @smoking)
            returning id
            """, new
        {
            driverId,
            vehicleId = request.VehicleId,
            originLat = request.Origin.Lat,
            originLng = request.Origin.Lng,
            destLat = request.Destination.Lat,
            destLng = request.Destination.Lng,
            originLabel = request.Origin.Label,
            destLabel = request.Destination.Label,
            route = routeWkt,
            distance = (int)Math.Round(distance),
            duration = durationSeconds,
            departureTime = request.DepartureTime,
            weekdays = request.Weekdays.Distinct().OrderBy(x => x).Select(x => (short)x).ToArray(),
            price = request.PricePerSeat,
            seatsTotal = request.SeatsTotal,
            bookingMode = request.BookingMode == "manual" ? "manual" : "instant",
            luggage = request.Luggage,
            pets = request.PetsAllowed,
            smoking = request.SmokingAllowed
        }, tx);

        for (var i = 0; i < request.Stops.Count; i++)
        {
            var s = request.Stops[i];
            await conn.ExecuteAsync("""
                insert into recurring_trip_stops (recurring_trip_id, seq, name, location,
                    eta_offset_min, allow_pickup, allow_dropoff, price_from_origin)
                values (@id, @seq, @name,
                    ST_SetSRID(ST_MakePoint(@lng, @lat), 4326)::geography,
                    @eta, @pickup, @dropoff, @price)
                """, new
            {
                id, seq = (short)i, name = s.Name, lng = s.Lng, lat = s.Lat,
                eta = (int)Math.Round(durationSeconds * (cumulativeFraction(request.Stops, i, distance)) / 60.0),
                pickup = s.AllowPickup, dropoff = s.AllowDropoff, price = prices[i]
            }, tx);
        }

        await tx.CommitAsync(ct);
        await MaterializeAsync(id, 14, ct);
        return (await ListAsync(driverId, ct)).First(r => r.Id == id);
    }

    private static double cumulativeFraction(List<CreateStopRequest> stops, int index, double total)
    {
        if (index <= 0 || total <= 0) return 0;
        var sum = 0.0;
        for (var i = 1; i <= index; i++)
            sum += Pricing.HaversineMeters(stops[i - 1].Lat, stops[i - 1].Lng, stops[i].Lat, stops[i].Lng);
        return sum / total;
    }

    public async Task<List<RecurringTripDto>> ListAsync(Guid driverId, CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync(ct);
        var rows = await conn.QueryAsync<dynamic>("""
            select r.id, r.origin_label, r.destination_label, r.departure_time, r.weekdays,
                   r.price_per_seat, r.seats_total, r.active,
                   (select count(*) from trips t
                    where t.source_recurring_id = r.id and t.departure_time > now()) as upcoming
            from recurring_trips r
            where r.driver_id = @driverId
            order by r.created_at desc
            """, new { driverId });
        return rows.Select(r => new RecurringTripDto(
            (Guid)r.id, (string)r.origin_label, (string)r.destination_label,
            ((TimeOnly)r.departure_time).ToString(@"HH\:mm"),
            ((short[])r.weekdays).Select(x => (int)x).ToArray(),
            (int)r.price_per_seat, (int)r.seats_total, (bool)r.active, (int)r.upcoming)).ToList();
    }

    public async Task<bool> DeactivateAsync(Guid id, Guid driverId, CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync(ct);
        var affected = await conn.ExecuteAsync(
            "update recurring_trips set active = false where id = @id and driver_id = @driverId",
            new { id, driverId });
        return affected > 0;
    }

    public async Task<int> MaterializeAsync(Guid recurringId, int days = 14, CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync(ct);
        var template = await conn.QuerySingleOrDefaultAsync<dynamic>("""
            select id, departure_time, weekdays, duration_s, valid_from, valid_to, active
            from recurring_trips where id = @recurringId
            """, new { recurringId });
        if (template is null || !(bool)template.active) return 0;

        var departure = (TimeOnly)template.departure_time;
        var weekdays = ((short[])template.weekdays).Select(x => (int)x).ToHashSet();
        var duration = (int)template.duration_s;
        var validFrom = template.valid_from is DateOnly fromDate
            ? fromDate.ToDateTime(TimeOnly.MinValue)
            : (DateTime)template.valid_from;
        var validTo = template.valid_to is null
            ? (DateTime?)null
            : template.valid_to is DateOnly toDate
                ? toDate.ToDateTime(TimeOnly.MinValue)
                : (DateTime)template.valid_to;

        var today = TimeZoneInfo.ConvertTime(DateTimeOffset.UtcNow, VietnamTz).Date;
        var start = today > validFrom ? today : validFrom;
        var created = 0;

        for (var offset = 0; offset < days; offset++)
        {
            var date = start.AddDays(offset);
            if (validTo is not null && date > validTo) break;
            var isoWeekday = date.DayOfWeek == DayOfWeek.Sunday ? 7 : (int)date.DayOfWeek;
            if (!weekdays.Contains(isoWeekday)) continue;

            var local = new DateTime(date.Year, date.Month, date.Day,
                departure.Hour, departure.Minute, 0, DateTimeKind.Unspecified);
            var offsetSpan = VietnamTz.GetUtcOffset(local);
            var departureUtc = new DateTimeOffset(local, offsetSpan).ToUniversalTime();
            if (departureUtc <= DateTimeOffset.UtcNow) continue;

            var tripId = await conn.ExecuteScalarAsync<Guid?>("""
                insert into trips (driver_id, vehicle_id, origin, destination, origin_label,
                    destination_label, route, distance_m, duration_s, departure_time,
                    arrive_estimate, price_per_seat, seats_total, seats_available, booking_mode,
                    luggage, pets_allowed, smoking_allowed, status, source_recurring_id)
                select driver_id, vehicle_id, origin, destination, origin_label, destination_label,
                       route, distance_m, duration_s, @departureTime, @arriveTime, price_per_seat,
                       seats_total, seats_total, booking_mode, luggage, pets_allowed, smoking_allowed,
                       'open', id
                from recurring_trips where id = @recurringId
                on conflict do nothing
                returning id
                """, new
            {
                recurringId, departureTime = departureUtc, arriveTime = departureUtc.AddSeconds(duration)
            });
            if (tripId is null) continue;

            await conn.ExecuteAsync("""
                insert into trip_stops (trip_id, seq, name, location, eta_offset_min,
                    allow_pickup, allow_dropoff, price_from_origin)
                select @tripId, seq, name, location, eta_offset_min, allow_pickup, allow_dropoff, price_from_origin
                from recurring_trip_stops where recurring_trip_id = @recurringId order by seq
                """, new { tripId, recurringId });
            created++;
        }

        return created;
    }

    public async Task<int> MaterializeAllAsync(CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync(ct);
        var ids = (await conn.QueryAsync<Guid>(
            "select id from recurring_trips where active = true")).ToList();
        var total = 0;
        foreach (var id in ids) total += await MaterializeAsync(id, 14, ct);
        return total;
    }
}
