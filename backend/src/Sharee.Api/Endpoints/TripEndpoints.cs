using System.Globalization;
using Dapper;
using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Api.Endpoints;

public static class TripEndpoints
{
    private static readonly TimeZoneInfo VietnamTz =
        TimeZoneInfo.FindSystemTimeZoneById("Asia/Ho_Chi_Minh");

    public static IEndpointRouteBuilder MapTripEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/trips/search", async (
            double fromLat, double fromLng, double toLat, double toLng,
            string? date, short seats, DateTimeOffset? arriveBy, double? radiusKm,
            Db db, CancellationToken ct) =>
        {
            seats = (short)Math.Clamp((int)seats, 1, 8);
            var radiusM = Math.Clamp(radiusKm ?? 15, 1, 100) * 1000;

            var localNow = TimeZoneInfo.ConvertTime(DateTimeOffset.UtcNow, VietnamTz);
            DateTime day;
            if (!string.IsNullOrWhiteSpace(date))
            {
                if (!DateTime.TryParseExact(date, "yyyy-MM-dd", CultureInfo.InvariantCulture,
                        DateTimeStyles.None, out day))
                    return Results.BadRequest(new { error = "Ngày không hợp lệ (yyyy-MM-dd)" });
            }
            else
            {
                day = localNow.Date;
            }
            var offset = VietnamTz.GetUtcOffset(day);
            var dayStart = new DateTimeOffset(day, offset).ToUniversalTime();
            var dayEnd = dayStart.AddDays(1);
            var arriveLimit = (arriveBy ?? new DateTimeOffset(2100, 1, 1, 0, 0, 0, TimeSpan.Zero))
                .ToUniversalTime();

            const string sql = """
                with pickup as (
                    select s.trip_id, s.id, s.seq, s.name, s.location, s.eta_offset_min, s.price_from_origin
                    from trip_stops s
                    where s.allow_pickup
                      and ST_DWithin(s.location,
                          ST_SetSRID(ST_MakePoint(@fromLng, @fromLat), 4326)::geography, @radiusM)
                ),
                dropoff as (
                    select s.trip_id, s.id, s.seq, s.name, s.location, s.eta_offset_min, s.price_from_origin
                    from trip_stops s
                    where s.allow_dropoff
                      and ST_DWithin(s.location,
                          ST_SetSRID(ST_MakePoint(@toLng, @toLat), 4326)::geography, @radiusM)
                ),
                cand as (
                    select distinct on (t.id)
                        t.id as trip_id, t.departure_time, t.arrive_estimate,
                        t.seats_available, t.booking_mode,
                        (d.price_from_origin - p.price_from_origin) as segment_price,
                        t.origin_label, t.destination_label,
                        ST_Distance(p.location,
                            ST_SetSRID(ST_MakePoint(@fromLng, @fromLat), 4326)::geography) +
                        ST_Distance(d.location,
                            ST_SetSRID(ST_MakePoint(@toLng, @toLat), 4326)::geography) as access_m,
                        p.id as pickup_id, p.seq as pickup_seq, p.name as pickup_name,
                        ST_Y(p.location::geometry) as pickup_lat, ST_X(p.location::geometry) as pickup_lng,
                        p.eta_offset_min as pickup_eta, p.price_from_origin as pickup_price,
                        d.id as dropoff_id, d.seq as dropoff_seq, d.name as dropoff_name,
                        ST_Y(d.location::geometry) as dropoff_lat, ST_X(d.location::geometry) as dropoff_lng,
                        d.eta_offset_min as dropoff_eta, d.price_from_origin as dropoff_price,
                        u.id as driver_id, u.full_name as driver_name, u.phone as driver_phone,
                        u.avatar_url as driver_avatar_url, u.role as driver_role,
                        u.verified_level as driver_verified_level,
                        u.rating_avg as driver_rating_avg, u.rating_count as driver_rating_count,
                        v.id as vehicle_id, v.make as vehicle_make, v.model as vehicle_model,
                        v.year as vehicle_year, v.color as vehicle_color, v.plate as vehicle_plate,
                        v.seats as vehicle_seats, v.status as vehicle_status
                    from trips t
                    join pickup p on p.trip_id = t.id
                    join dropoff d on d.trip_id = t.id and d.seq > p.seq
                    join users u on u.id = t.driver_id
                    join vehicles v on v.id = t.vehicle_id
                    where t.status = 'open'
                      and t.seats_available >= @seats
                      and t.departure_time >= @dayStart
                      and t.departure_time < @dayEnd
                      and t.arrive_estimate <= @arriveBy
                      and (d.price_from_origin - p.price_from_origin) > 0
                    order by t.id, access_m
                )
                select * from cand order by access_m limit 50
                """;

            await using var conn = await db.OpenAsync(ct);
            var rows = await conn.QueryAsync<SearchRow>(sql, new
            {
                fromLat, fromLng, toLat, toLng, radiusM, seats, dayStart, dayEnd, arriveBy = arriveLimit
            });

            var items = rows.Select(r => new SearchResultDto(
                r.TripId,
                new UserDto(r.DriverId, Privacy.MaskPhone(r.DriverPhone), r.DriverName, null, r.DriverAvatarUrl, null,
                    r.DriverRole, r.DriverVerifiedLevel, r.DriverRatingAvg, r.DriverRatingCount),
                new VehicleDto(r.VehicleId, r.VehicleMake, r.VehicleModel, r.VehicleYear,
                    r.VehicleColor, r.VehiclePlate, r.VehicleSeats, r.VehicleStatus),
                r.OriginLabel, r.DestinationLabel, r.DepartureTime, r.ArriveEstimate,
                r.SegmentPrice, r.SeatsAvailable,
                new StopDto(r.PickupId, r.PickupSeq, r.PickupName, r.PickupLat, r.PickupLng,
                    r.PickupEta, true, false, r.PickupPrice),
                new StopDto(r.DropoffId, r.DropoffSeq, r.DropoffName, r.DropoffLat, r.DropoffLng,
                    r.DropoffEta, false, true, r.DropoffPrice),
                Math.Round(r.AccessM), r.BookingMode)).ToList();

            return Results.Ok(new SearchResponse(items, items.Count));
        }).WithTags("Trips");

        app.MapGet("/api/trips/{id:guid}", async (Guid id, ReadService read, CancellationToken ct) =>
        {
            var trip = await read.GetTripAsync(id, ct);
            return trip is null ? Results.NotFound() : Results.Ok(trip);
        }).RequireAuthorization().WithTags("Trips");

        app.MapPost("/api/trips", async (
            CreateTripRequest request, HttpContext http, Db db, ReadService read,
            CancellationToken ct) =>
        {
            var driverId = http.User.GetUserId();
            if (request.Stops.Count is < 2 or > 20)
                return Results.BadRequest(new { error = "Chuyến cần từ 2 đến 20 điểm đón/trả" });
            if (request.DepartureTime <= DateTimeOffset.UtcNow.AddMinutes(15))
                return Results.BadRequest(new { error = "Giờ khởi hành phải sau hiện tại ít nhất 15 phút" });
            if (request.SeatsTotal is < 1 or > 8 || request.PricePerSeat is < 10000 or > 10_000_000)
                return Results.BadRequest(new { error = "Số ghế hoặc giá không hợp lệ" });
            if (request.Stops.Any(s =>
                    s.Lat is < -90 or > 90 || s.Lng is < -180 or > 180 ||
                    string.IsNullOrWhiteSpace(s.Name) || s.Name.Trim().Length > 120))
                return Results.BadRequest(new { error = "Điểm dừng không hợp lệ" });
            if (!request.Stops[0].AllowPickup || !request.Stops[^1].AllowDropoff)
                return Results.BadRequest(new { error = "Điểm đầu phải cho đón, điểm cuối phải cho trả" });

            await using var conn = await db.OpenAsync(ct);
            if (!await DriverVerification.IsApprovedAsync(conn, driverId, ct))
                return Results.Json(new
                {
                    error = "Tài xế chưa được xác thực. Vui lòng hoàn tất xác thực CCCD, GPLX và giấy tờ xe trước khi đăng chuyến.",
                    verificationRequired = true
                }, statusCode: StatusCodes.Status403Forbidden);
            var vehicle = await conn.QuerySingleOrDefaultAsync<VehicleRow>(
                "select * from vehicles where id = @id and owner_id = @ownerId and status = 'active'",
                new { id = request.VehicleId, ownerId = driverId });
            if (vehicle is null) return Results.BadRequest(new { error = "Xe không hợp lệ" });
            if (request.SeatsTotal > vehicle.Seats)
                return Results.BadRequest(new { error = "Số ghế vượt quá số chỗ của xe" });

            var distance = 0.0;
            for (var i = 1; i < request.Stops.Count; i++)
            {
                var segment = Pricing.HaversineMeters(
                    request.Stops[i - 1].Lat, request.Stops[i - 1].Lng,
                    request.Stops[i].Lat, request.Stops[i].Lng);
                if (segment < 1)
                    return Results.BadRequest(new { error = "Hai điểm dừng không được trùng nhau" });
                distance += segment;
            }
            var durationSeconds = (int)Math.Max(600, distance / 17.0);
            var departureUtc = request.DepartureTime.ToUniversalTime();
            var arrive = departureUtc.AddSeconds(durationSeconds);

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
                    var price = maxMiddle == 0 ? 0 : Math.Clamp(computed, 0, maxMiddle);
                    prices.Add(price);
                }
            }

            await using var tx = await conn.BeginTransactionAsync(ct);
            var tripId = await conn.ExecuteScalarAsync<Guid>("""
                insert into trips (driver_id, vehicle_id, origin, destination, origin_label, destination_label,
                    route, distance_m, duration_s, departure_time, arrive_estimate, price_per_seat,
                    seats_total, seats_available, booking_mode, luggage, pets_allowed, smoking_allowed, status)
                values (@driverId, @vehicleId,
                    ST_SetSRID(ST_MakePoint(@originLng, @originLat), 4326)::geography,
                    ST_SetSRID(ST_MakePoint(@destLng, @destLat), 4326)::geography,
                    @originLabel, @destLabel, ST_GeogFromText(@route), @distance, @duration,
                    @departure, @arrive, @price, @seatsTotal, @seatsTotal, @bookingMode,
                    @luggage, @pets, @smoking, 'open')
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
                departure = departureUtc,
                arrive,
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
                    insert into trip_stops (trip_id, seq, name, location, eta_offset_min,
                        allow_pickup, allow_dropoff, price_from_origin)
                    values (@tripId, @seq, @name,
                        ST_SetSRID(ST_MakePoint(@lng, @lat), 4326)::geography,
                        @eta, @pickup, @dropoff, @price)
                    """, new
                {
                    tripId, seq = (short)i, name = s.Name, lng = s.Lng, lat = s.Lat,
                    eta = (int)Math.Round((request.DepartureTime.AddSeconds(
                        durationSeconds * CumulativeFraction(request.Stops, i, distance)) - request.DepartureTime).TotalMinutes),
                    pickup = s.AllowPickup, dropoff = s.AllowDropoff, price = prices[i]
                }, tx);
            }

            await tx.CommitAsync(ct);
            var trip = await read.GetTripAsync(tripId, ct);
            return Results.Created($"/api/trips/{tripId}", trip);
        }).RequireAuthorization().WithTags("Trips");

        app.MapPost("/api/trips/{id:guid}/cancel", async (
            Guid id, HttpContext http, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var trip = await conn.QuerySingleOrDefaultAsync<TripRow>(TripSqlForOwner, new { id });
            if (trip is null) return Results.NotFound();
            if (trip.DriverId != http.User.GetUserId()) return Results.Forbid();

            var confirmed = await conn.ExecuteScalarAsync<int>(
                "select count(*) from bookings where trip_id = @id and status = 'confirmed'", new { id });
            if (confirmed > 0)
                return Results.Conflict(new { error = "Chuyến còn khách đã xác nhận. Hãy huỷ từng booking trước." });

            await conn.ExecuteAsync(
                "update trips set status = 'cancelled', updated_at = now() where id = @id and status = 'open'",
                new { id });
            return Results.Ok(new { status = "cancelled" });
        }).RequireAuthorization().WithTags("Trips");

        app.MapGet("/api/trips/mine", async (
            HttpContext http, Db db, ReadService read, CancellationToken ct) =>
        {
            var userId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            var drivingIds = (await conn.QueryAsync<Guid>(
                "select id from trips where driver_id = @userId order by departure_time desc limit 30",
                new { userId })).ToList();
            var ridingIds = (await conn.QueryAsync<Guid>("""
                select distinct b.trip_id from bookings b
                where b.passenger_id = @userId
                order by b.trip_id limit 30
                """, new { userId })).ToList();

            var driving = new List<TripDto>();
            foreach (var id in drivingIds)
            {
                var trip = await read.GetTripAsync(id, ct);
                if (trip is not null) driving.Add(trip);
            }

            var riding = new List<TripDto>();
            foreach (var id in ridingIds)
            {
                var trip = await read.GetTripAsync(id, ct);
                if (trip is not null) riding.Add(trip);
            }

            return Results.Ok(new { driving, riding });
        }).RequireAuthorization().WithTags("Trips");

        return app;
    }

    private const string TripSqlForOwner = """
        select t.*, ST_Y(t.origin::geometry) as origin_lat, ST_X(t.origin::geometry) as origin_lng,
               ST_Y(t.destination::geometry) as destination_lat, ST_X(t.destination::geometry) as destination_lng,
               '' as driver_phone, '' as driver_name, 'user' as driver_role,
               0 as driver_verified_level, 0 as driver_rating_avg, 0 as driver_rating_count,
               '' as vehicle_make, '' as vehicle_model, 0 as vehicle_seats, '' as vehicle_plate,
               'active' as vehicle_status
        from trips t where t.id = @id
        """;

    private static double CumulativeFraction(List<CreateStopRequest> stops, int index, double total)
    {
        if (index <= 0 || total <= 0) return 0;
        var sum = 0.0;
        for (var i = 1; i <= index; i++)
            sum += Pricing.HaversineMeters(stops[i - 1].Lat, stops[i - 1].Lng, stops[i].Lat, stops[i].Lng);
        return sum / total;
    }
}
