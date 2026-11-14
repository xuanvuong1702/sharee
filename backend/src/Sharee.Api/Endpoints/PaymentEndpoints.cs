using Dapper;
using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Api.Endpoints;

public static class PaymentEndpoints
{
    public static IEndpointRouteBuilder MapPaymentEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/bookings/{id:guid}/pay", async (
            Guid id, HttpContext http, Db db, LedgerService ledger, ReadService read,
            IConfiguration config, CancellationToken ct) =>
        {
            if ((config["Payments:Provider"] ?? "mock").Equals("payos", StringComparison.OrdinalIgnoreCase))
            {
                return Results.Conflict(new
                {
                    error = "Vui lòng thanh toán qua PayOS",
                    checkout = $"/api/bookings/{id}/payos"
                });
            }
            if (!config.GetValue("Payments:AllowMock", false))
            {
                return Results.Json(new
                {
                    error = "Cổng thanh toán chưa được cấu hình. Vui lòng liên hệ hỗ trợ."
                }, statusCode: StatusCodes.Status501NotImplemented);
            }

            var userId = http.User.GetUserId();
            var booking = await read.GetBookingAsync(id, ct);
            if (booking is null) return Results.NotFound();
            if (booking.Passenger.Id != userId) return Results.Forbid();
            if (booking.Payment?.Status == "succeeded") return Results.Ok(booking);
            if (booking.Status != "pending_payment")
                return Results.Conflict(new { error = "Booking không ở trạng thái chờ thanh toán" });

            await using var conn = await db.OpenAsync(ct);
            await using var tx = await conn.BeginTransactionAsync(ct);

            var paymentId = await conn.ExecuteScalarAsync<Guid?>("""
                insert into payments (booking_id, provider, provider_ref, amount, status, captured_at)
                values (@bookingId, 'mock', @ref, @amount, 'succeeded', now())
                on conflict (booking_id) do nothing
                returning id
                """, new
            {
                bookingId = id,
                @ref = "MOCK-" + Guid.NewGuid().ToString("N")[..12],
                amount = booking.PriceTotal
            }, tx);

            if (paymentId is null)
            {
                await tx.RollbackAsync(ct);
                return Results.Ok(await read.GetBookingAsync(id, ct));
            }

            await ledger.RecordAsync(conn, tx, "payment", "booking", id,
                ("customer_receivable", 'D', booking.PriceTotal),
                ("escrow", 'C', booking.PriceTotal));

            await conn.ExecuteAsync("""
                update bookings set status = 'confirmed', updated_at = now()
                where id = @id and status = 'pending_payment'
                """, new { id }, tx);

            await conn.ExecuteAsync("""
                insert into conversations (booking_id) values (@id)
                on conflict (booking_id) do nothing
                """, new { id }, tx);

            await Notifier.NotifyAsync(conn, tx, booking.Driver.Id, "booking.paid",
                "Khách đã thanh toán", $"{booking.Seats} ghế · {booking.Trip.OriginLabel} → {booking.Trip.DestinationLabel}");

            await conn.ExecuteAsync("""
                insert into outbox (aggregate_type, aggregate_id, type, payload)
                values ('booking', @id, 'booking.confirmed', '{}'::jsonb)
                """, new { id }, tx);

            await tx.CommitAsync(ct);
            return Results.Ok(await read.GetBookingAsync(id, ct));
        }).RequireAuthorization().WithTags("Payments");

        return app;
    }
}
