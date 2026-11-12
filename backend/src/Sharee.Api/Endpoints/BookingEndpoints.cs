using Dapper;
using Npgsql;
using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Api.Endpoints;

public static class BookingEndpoints
{
    public static IEndpointRouteBuilder MapBookingEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/bookings").RequireAuthorization().WithTags("Bookings");

        app.MapPost("/api/trips/{tripId:guid}/bookings", async (
            Guid tripId, CreateBookingRequest request, HttpContext http, Db db,
            LedgerService ledger, ReadService read, CancellationToken ct) =>
        {
            var userId = http.User.GetUserId();
            var idempotency = http.Request.Headers["Idempotency-Key"].FirstOrDefault();

            await using var conn = await db.OpenAsync(ct);
            if (!string.IsNullOrWhiteSpace(idempotency))
            {
                var existingId = await conn.ExecuteScalarAsync<Guid?>(
                    "select id from bookings where idempotency_key = @idempotency", new { idempotency });
                if (existingId is not null)
                    return Results.Ok(await read.GetBookingAsync(existingId.Value, ct));
            }

            var trip = await conn.QuerySingleOrDefaultAsync<TripRow>(TripSql, new { id = tripId });
            if (trip is null) return Results.NotFound(new { error = "Không tìm thấy chuyến" });
            if (trip.DriverId == userId) return Results.BadRequest(new { error = "Bạn là tài xế của chuyến này" });
            if (trip.Status != "open") return Results.Conflict(new { error = "Chuyến không còn mở" });

            var stops = (await conn.QueryAsync<StopRow>(
                "select id, trip_id, seq, name, ST_Y(location::geometry) lat, ST_X(location::geometry) lng, eta_offset_min, allow_pickup, allow_dropoff, price_from_origin from trip_stops where trip_id = @tripId",
                new { tripId })).ToList();

            var from = stops.FirstOrDefault(s => s.Id == request.FromStopId);
            var to = stops.FirstOrDefault(s => s.Id == request.ToStopId);
            if (from is null || to is null) return Results.BadRequest(new { error = "Điểm đón/trả không hợp lệ" });
            if (from.Seq >= to.Seq) return Results.BadRequest(new { error = "Điểm đón phải trước điểm trả" });
            if (!from.AllowPickup || !to.AllowDropoff)
                return Results.BadRequest(new { error = "Điểm đón/trả không được phép" });
            if (request.Seats <= 0) return Results.BadRequest(new { error = "Số ghế không hợp lệ" });

            var price = (to.PriceFromOrigin - from.PriceFromOrigin) * request.Seats;
            if (price <= 0) return Results.BadRequest(new { error = "Chặng không hợp lệ" });

            var status = trip.BookingMode == "instant" ? "pending_payment" : "pending_driver";
            var expires = trip.BookingMode == "instant"
                ? DateTimeOffset.UtcNow.AddMinutes(10)
                : DateTimeOffset.UtcNow.AddMinutes(15);

            await using var tx = await conn.BeginTransactionAsync(ct);
            var affected = await conn.ExecuteAsync("""
                update trips set seats_available = seats_available - @seats,
                       status = case when seats_available - @seats = 0 then 'full' else status end,
                       updated_at = now()
                where id = @tripId and status = 'open' and seats_available >= @seats
                """, new { tripId, seats = request.Seats }, tx);

            if (affected == 0)
            {
                await tx.RollbackAsync(ct);
                return Results.Conflict(new { error = "Đã hết ghế" });
            }

            Guid bookingId;
            try
            {
                bookingId = await conn.ExecuteScalarAsync<Guid>("""
                    insert into bookings (trip_id, passenger_id, from_stop_id, to_stop_id, seats,
                        price_total, status, idempotency_key, expires_at)
                    values (@tripId, @userId, @fromStop, @toStop, @seats, @price, @status, @idempotency, @expires)
                    returning id
                    """, new
                {
                    tripId, userId, fromStop = from.Id, toStop = to.Id, seats = request.Seats,
                    price, status, idempotency, expires
                }, tx);
            }
            catch (PostgresException ex) when (ex.SqlState == "23505" && !string.IsNullOrWhiteSpace(idempotency))
            {
                await tx.RollbackAsync(ct);
                var existingId = await conn.ExecuteScalarAsync<Guid>(
                    "select id from bookings where idempotency_key = @idempotency", new { idempotency });
                return Results.Ok(await read.GetBookingAsync(existingId, ct));
            }

            await Notifier.NotifyAsync(conn, tx, trip.DriverId, "booking.created",
                "Có yêu cầu đặt chỗ mới",
                $"{request.Seats} ghế · {trip.OriginLabel} → {trip.DestinationLabel}");

            await conn.ExecuteAsync("""
                insert into outbox (aggregate_type, aggregate_id, type, payload)
                values ('booking', @bookingId, 'booking.created', @payload::jsonb)
                """, new { bookingId, payload = "{}" }, tx);

            await tx.CommitAsync(ct);
            return Results.Created($"/api/bookings/{bookingId}", await read.GetBookingAsync(bookingId, ct));
        }).WithTags("Bookings");

        group.MapGet("/{id:guid}", async (Guid id, HttpContext http, ReadService read, CancellationToken ct) =>
        {
            var booking = await read.GetBookingAsync(id, ct);
            if (booking is null) return Results.NotFound();
            var userId = http.User.GetUserId();
            if (booking.Passenger.Id != userId && booking.Driver.Id != userId)
                return Results.Forbid();
            return Results.Ok(booking);
        });

        group.MapGet("/mine", async (HttpContext http, Db db, ReadService read, CancellationToken ct) =>
        {
            var userId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            var ids = (await conn.QueryAsync<Guid>(
                "select id from bookings where passenger_id = @userId or trip_id in (select id from trips where driver_id = @userId) order by created_at desc limit 50",
                new { userId })).ToList();

            var list = new List<BookingDto>();
            foreach (var id in ids)
            {
                var booking = await read.GetBookingAsync(id, ct);
                if (booking is not null) list.Add(booking);
            }
            return Results.Ok(list);
        });

        group.MapPost("/{id:guid}/accept", async (
            Guid id, HttpContext http, Db db, ReadService read, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var affected = await conn.ExecuteAsync("""
                update bookings b set status = 'pending_payment',
                       expires_at = now() + interval '10 minutes', updated_at = now()
                from trips t
                where b.id = @id and b.trip_id = t.id and b.status = 'pending_driver'
                  and t.driver_id = @driverId
                """, new { id, driverId = http.User.GetUserId() });

            if (affected == 0) return Results.Conflict(new { error = "Không thể chấp nhận booking này" });

            var booking = await read.GetBookingAsync(id, ct);
            if (booking is not null)
                await Notifier.NotifyAsync(conn, null, booking.Passenger.Id, "booking.accepted",
                    "Yêu cầu được chấp nhận", "Bạn có 10 phút để thanh toán.");
            return Results.Ok(booking);
        });

        group.MapPost("/{id:guid}/reject", async (
            Guid id, HttpContext http, Db db, ReadService read, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            await using var tx = await conn.BeginTransactionAsync(ct);
            var row = await conn.QuerySingleOrDefaultAsync<dynamic>("""
                update bookings b set status = 'rejected', updated_at = now()
                from trips t
                where b.id = @id and b.trip_id = t.id and b.status = 'pending_driver'
                  and t.driver_id = @driverId
                returning b.trip_id, b.seats, b.passenger_id
                """, new { id, driverId = http.User.GetUserId() }, tx);

            if (row is null)
            {
                await tx.RollbackAsync(ct);
                return Results.Conflict(new { error = "Không thể từ chối booking này" });
            }

            Guid tripId = row.trip_id;
            short seats = row.seats;
            Guid passengerId = row.passenger_id;
            await conn.ExecuteAsync("""
                update trips set seats_available = least(seats_total, seats_available + @seats),
                       status = case when status = 'full' then 'open' else status end,
                       updated_at = now()
                where id = @tripId
                """, new { tripId, seats }, tx);
            await Notifier.NotifyAsync(conn, tx, passengerId, "booking.rejected",
                "Yêu cầu bị từ chối", "Tài xế không thể nhận chuyến này.");
            await tx.CommitAsync(ct);
            return Results.Ok(await read.GetBookingAsync(id, ct));
        });

        group.MapPost("/{id:guid}/cancel", async (
            Guid id, HttpContext http, Db db, LedgerService ledger, ReadService read,
            CancellationToken ct) =>
        {
            var userId = http.User.GetUserId();
            var booking = await read.GetBookingAsync(id, ct);
            if (booking is null) return Results.NotFound();
            if (booking.Passenger.Id != userId && booking.Driver.Id != userId) return Results.Forbid();
            if (booking.Status is "cancelled_by_passenger" or "cancelled_by_driver" or "completed")
                return Results.Conflict(new { error = "Booking không thể huỷ" });

            var driverCancelled = booking.Driver.Id == userId;
            var newStatus = driverCancelled ? "cancelled_by_driver" : "cancelled_by_passenger";
            var refundPercent = Pricing.RefundPercent(booking.Trip.DepartureTime, DateTimeOffset.UtcNow, driverCancelled);
            var refundAmount = booking.Payment?.Status == "succeeded"
                ? (int)Math.Round(booking.PriceTotal * refundPercent / 100.0)
                : 0;

            await using var conn = await db.OpenAsync(ct);
            await using var tx = await conn.BeginTransactionAsync(ct);

            await conn.ExecuteAsync("""
                update bookings set status = @newStatus, updated_at = now()
                where id = @id and status in ('pending_driver','pending_payment','confirmed')
                """, new { id, newStatus }, tx);

            await conn.ExecuteAsync("""
                update trips set seats_available = least(seats_total, seats_available + @seats),
                       status = case when status = 'full' then 'open' else status end,
                       updated_at = now()
                where id = @tripId
                """, new { tripId = booking.TripId, seats = booking.Seats }, tx);

            if (refundAmount > 0)
            {
                await conn.ExecuteAsync(
                    "update payments set status = 'refunded' where booking_id = @id", new { id }, tx);
                await ledger.RecordAsync(conn, tx, "refund", "booking", id,
                    ("escrow", 'D', refundAmount),
                    ("customer_receivable", 'C', refundAmount));
            }

            await Notifier.NotifyAsync(conn, tx,
                driverCancelled ? booking.Passenger.Id : booking.Driver.Id,
                "booking.cancelled", "Chuyến đã bị huỷ",
                driverCancelled ? "Tài xế đã huỷ chuyến. Bạn được hoàn tiền." : "Khách đã huỷ chuyến.");

            await tx.CommitAsync(ct);
            return Results.Ok(await read.GetBookingAsync(id, ct));
        });

        group.MapPost("/{id:guid}/complete", async (
            Guid id, HttpContext http, Db db, LedgerService ledger, ReadService read,
            CancellationToken ct) =>
        {
            var booking = await read.GetBookingAsync(id, ct);
            if (booking is null) return Results.NotFound();
            if (booking.Driver.Id != http.User.GetUserId()) return Results.Forbid();

            await using var conn = await db.OpenAsync(ct);
            await using var tx = await conn.BeginTransactionAsync(ct);
            var affected = await conn.ExecuteAsync("""
                update bookings set status = 'completed', updated_at = now()
                where id = @id and status = 'confirmed'
                """, new { id }, tx);
            if (affected == 0)
            {
                await tx.RollbackAsync(ct);
                return Results.Conflict(new { error = "Booking chưa ở trạng thái xác nhận" });
            }

            var payout = booking.PriceTotal - booking.PriceTotal * 0 / 100;
            await ledger.RecordAsync(conn, tx, "payout", "booking", id,
                ("escrow", 'D', payout),
                ("driver_payable", 'C', payout));

            await Notifier.NotifyAsync(conn, tx, booking.Passenger.Id, "booking.completed",
                "Chuyến đã hoàn thành", "Hãy đánh giá tài xế để giúp cộng đồng.");
            await tx.CommitAsync(ct);
            return Results.Ok(await read.GetBookingAsync(id, ct));
        });

        return app;
    }

    private const string TripSql = """
        select t.id, t.driver_id, t.vehicle_id,
               ST_Y(t.origin::geometry) as origin_lat, ST_X(t.origin::geometry) as origin_lng,
               ST_Y(t.destination::geometry) as destination_lat, ST_X(t.destination::geometry) as destination_lng,
               t.origin_label, t.destination_label, t.departure_time, t.arrive_estimate,
               t.price_per_seat, t.seats_total, t.seats_available, t.booking_mode,
               t.luggage, t.pets_allowed, t.smoking_allowed, t.status, t.distance_m, t.duration_s,
               u.phone as driver_phone, u.full_name as driver_name, u.avatar_url as driver_avatar_url,
               u.role as driver_role, u.verified_level as driver_verified_level,
               u.rating_avg as driver_rating_avg, u.rating_count as driver_rating_count,
               v.make as vehicle_make, v.model as vehicle_model, v.year as vehicle_year,
               v.color as vehicle_color, v.plate as vehicle_plate, v.seats as vehicle_seats,
               v.status as vehicle_status
        from trips t
        join users u on u.id = t.driver_id
        join vehicles v on v.id = t.vehicle_id
        where t.id = @id
        """;
}
