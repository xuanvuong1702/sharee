using Dapper;
using Npgsql;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Services;

public sealed record SettlementResult(bool Ok, string Status, string? Error = null, int Amount = 0);

/// <summary>
/// Single place that moves booking money. Both driver completion, tracking
/// completion and admin appeal resolution must call this service; otherwise a
/// booking can be paid out and refunded twice.
/// </summary>
public sealed class BookingSettlementService(Db db, LedgerService ledger)
{
    public async Task<SettlementResult> CompleteAsync(
        Guid bookingId, Guid driverId, CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        var row = await LockAsync(conn, tx, bookingId);
        if (row is null) return new(false, "not_found", "Booking không tồn tại");
        if ((Guid)row.driver_id != driverId) return new(false, "forbidden", "Không phải tài xế của chuyến");
        if ((string)row.status != "confirmed") return new(false, "conflict", "Booking chưa ở trạng thái xác nhận");
        if (await HasOpenAppealAsync(conn, tx, bookingId))
            return new(false, "disputed", "Booking đang có khiếu nại mở, chưa thể hoàn tất.");

        var affected = await conn.ExecuteAsync("""
            update bookings set status = 'completed', updated_at = now()
            where id = @bookingId and status = 'confirmed'
            """, new { bookingId }, tx);
        if (affected == 0) return new(false, "conflict", "Booking đã thay đổi trạng thái");

        var amount = (int)row.price_total;
        var method = (string)row.payment_method;
        var escrow = await conn.QuerySingleOrDefaultAsync<dynamic>(
            "select status, amount from escrow_holds where booking_id = @bookingId for update",
            new { bookingId }, tx);

        if (method == "cash")
        {
            await conn.ExecuteAsync("""
                insert into escrow_holds (booking_id, amount, method, status, released_at, release_at)
                values (@bookingId, @amount, 'cash', 'released', now(), now())
                on conflict (booking_id) do update set status = 'released', released_at = now(),
                    release_at = now(), updated_at = now()
                """, new { bookingId, amount }, tx);
        }
        else if (escrow is null || (string)escrow.status == "held")
        {
            // Money stays in escrow for a two-hour dispute window. A passenger
            // confirmation or the release worker moves it to the driver.
            await conn.ExecuteAsync("""
                insert into escrow_holds (booking_id, amount, method, status, release_at)
                values (@bookingId, @amount, 'payos', 'held', now() + interval '2 hours')
                on conflict (booking_id) do update set
                    status = 'held',
                    release_at = coalesce(escrow_holds.release_at, now() + interval '2 hours'),
                    updated_at = now()
                where escrow_holds.status = 'held'
                """, new { bookingId, amount }, tx);
        }

        await Notifier.NotifyAsync(conn, tx, (Guid)row.passenger_id, "booking.completed",
            "Chuyến đã hoàn thành", "Bạn có 2 giờ để xác nhận hoặc mở khiếu nại trước khi tiền được giải ngân.");
        await tx.CommitAsync(ct);
        return new(true, "completed", null, amount);
    }

    public async Task<SettlementResult> ConfirmAsync(
        Guid bookingId, Guid passengerId, CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync(ct);
        var passenger = await conn.ExecuteScalarAsync<Guid?>(
            "select passenger_id from bookings where id = @bookingId", new { bookingId });
        if (passenger is null) return new(false, "not_found", "Booking không tồn tại");
        if (passenger.Value != passengerId) return new(false, "forbidden", "Không phải khách của chuyến");
        return await ReleaseAsync(bookingId, passengerId, "passenger_confirmed", ct);
    }

    public async Task<SettlementResult> ReleaseAsync(
        Guid bookingId, Guid? actorId, string reason, CancellationToken ct = default,
        bool allowDisputed = false)
    {
        await using var conn = await db.OpenAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        var row = await LockAsync(conn, tx, bookingId);
        if (row is null) return new(false, "not_found", "Booking không tồn tại");
        var escrow = await conn.QuerySingleOrDefaultAsync<dynamic>(
            "select id, status, amount, method from escrow_holds where booking_id = @bookingId for update",
            new { bookingId }, tx);
        if (escrow is null) return new(false, "no_escrow", "Không có escrow cho booking");
        if ((string)escrow.status == "released") return new(true, "released", null, (int)escrow.amount);
        if ((string)escrow.status is "refunded" or "partial_refunded")
            return new(false, "already_refunded", "Tiền đã được hoàn, không thể giải ngân.");
        if (!allowDisputed && await HasOpenAppealAsync(conn, tx, bookingId))
            return new(false, "disputed", "Booking đang có khiếu nại mở.");

        var alreadyPaidOut = await conn.ExecuteScalarAsync<bool>("""
            select exists(select 1 from ledger_transactions
                          where type = 'payout' and ref_type = 'booking' and ref_id = @bookingId)
            """, new { bookingId }, tx);
        var amount = (int)escrow.amount;
        var method = (string)escrow.method;
        if (method != "cash" && !alreadyPaidOut && amount > 0)
            await ledger.RecordAsync(conn, tx, "payout", "booking", bookingId,
                ("escrow", 'D', amount), ("driver_payable", 'C', amount));

        await conn.ExecuteAsync("""
            update escrow_holds set status = 'released', released_at = now(),
                release_at = now(), updated_at = now()
            where booking_id = @bookingId and status <> 'released'
            """, new { bookingId }, tx);
        await Notifier.NotifyAsync(conn, tx, (Guid)row.passenger_id, "booking.released",
            "Đã giải ngân cho tài xế", "Chuyến đi đã được thanh toán cho tài xế.");
        await Notifier.NotifyAsync(conn, tx, (Guid)row.driver_id, "booking.released",
            "Bạn đã được thanh toán", "Khoản tiền chuyến đi đã được giải ngân.");
        await tx.CommitAsync(ct);
        return new(true, "released", null, amount);
    }

    public async Task<SettlementResult> RefundAsync(
        Guid bookingId, int? requestedAmount, Guid actorId, string reason, CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        var row = await LockAsync(conn, tx, bookingId);
        if (row is null) return new(false, "not_found", "Booking không tồn tại");
        var escrow = await conn.QuerySingleOrDefaultAsync<dynamic>(
            "select status, amount, method from escrow_holds where booking_id = @bookingId for update",
            new { bookingId }, tx);
        if (escrow is null) return new(false, "no_escrow", "Không có escrow cho booking");
        var escrowAmount = (int)escrow.amount;
        var amount = Math.Clamp(requestedAmount ?? escrowAmount, 0, escrowAmount);
        var method = (string)escrow.method;
        var alreadyPaidOut = await conn.ExecuteScalarAsync<bool>("""
            select exists(select 1 from ledger_transactions
                          where type = 'payout' and ref_type = 'booking' and ref_id = @bookingId)
            """, new { bookingId }, tx);
        if (alreadyPaidOut)
            return new(false, "already_released", "Tiền đã được giải ngân, cần xử lý thủ công.");

        if (method != "cash" && amount > 0)
        {
            var alreadyRefunded = await conn.ExecuteScalarAsync<bool>("""
                select exists(select 1 from ledger_transactions
                              where type = 'refund' and ref_type = 'booking' and ref_id = @bookingId)
                """, new { bookingId }, tx);
            if (!alreadyRefunded)
                await ledger.RecordAsync(conn, tx, "refund", "booking", bookingId,
                    ("escrow", 'D', amount), ("customer_receivable", 'C', amount));
            var remainder = escrowAmount - amount;
            if (remainder > 0)
                await ledger.RecordAsync(conn, tx, "fee", "booking", bookingId,
                    ("escrow", 'D', remainder), ("platform_revenue", 'C', remainder));
        }

        var status = amount == escrowAmount ? "refunded" : "partial_refunded";
        await conn.ExecuteAsync("""
            update escrow_holds set status = @status, released_at = now(), updated_at = now()
            where booking_id = @bookingId
            """, new { bookingId, status }, tx);
        await conn.ExecuteAsync("""
            update payments set status = 'refunded' where booking_id = @bookingId
            """, new { bookingId }, tx);
        await conn.ExecuteAsync("""
            update bookings set status = 'refunded', updated_at = now()
            where id = @bookingId and status not in ('cancelled_by_passenger','cancelled_by_driver')
            """, new { bookingId }, tx);
        if ((string)row.status == "confirmed")
            await conn.ExecuteAsync("""
                update trips set seats_available = least(seats_total, seats_available + @seats),
                    status = case when status = 'full' then 'open' else status end,
                    updated_at = now()
                where id = @tripId
                """, new { tripId = (Guid)row.trip_id, seats = (short)row.seats }, tx);
        await Notifier.NotifyAsync(conn, tx, (Guid)row.passenger_id, "booking.refunded",
            "Đã hoàn tiền", $"Hoàn {amount:N0}đ cho chuyến đi.");
        await tx.CommitAsync(ct);
        return new(true, status, null, amount);
    }

    private static async Task<bool> HasOpenAppealAsync(
        NpgsqlConnection conn, NpgsqlTransaction tx, Guid bookingId)
        => await conn.ExecuteScalarAsync<bool>("""
            select exists(select 1 from appeals
                          where booking_id = @bookingId and status in ('open','investigating'))
            """, new { bookingId }, tx);

    private static Task<dynamic?> LockAsync(
        NpgsqlConnection conn, NpgsqlTransaction tx, Guid bookingId)
        => conn.QuerySingleOrDefaultAsync<dynamic>("""
            select b.id, t.driver_id, b.passenger_id, b.trip_id, b.seats, b.price_total,
                   b.status, b.payment_method
            from bookings b
            join trips t on t.id = b.trip_id
            where b.id = @bookingId
            for update of b
            """, new { bookingId }, tx);
}
