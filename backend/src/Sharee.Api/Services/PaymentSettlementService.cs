using System.Globalization;
using System.Text.Json;
using Dapper;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Services;

public sealed class PaymentSettlementService(Db db, LedgerService ledger)
{
    public async Task<bool> SettlePayOsAsync(PayOsWebhook webhook, CancellationToken ct = default)
    {
        if (webhook.Code != "00") return true;

        await using var conn = await db.OpenAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        var row = await conn.QuerySingleOrDefaultAsync<dynamic>("""
            select p.id as payment_id, p.amount, p.status as payment_status,
                   b.id as booking_id, b.status as booking_status, b.price_total, b.seats,
                   b.payment_method,
                   b.passenger_id, t.driver_id, t.origin_label, t.destination_label
            from payments p
            join bookings b on b.id = p.booking_id
            join trips t on t.id = b.trip_id
            where p.provider = 'payos' and p.provider_ref = @orderCode
            for update of p, b
            """, new { orderCode = webhook.OrderCode.ToString(CultureInfo.InvariantCulture) }, tx);
        if (row is null)
        {
            await tx.RollbackAsync(ct);
            return false;
        }
        if ((string)row.payment_status == "succeeded")
        {
            await tx.RollbackAsync(ct);
            return true;
        }
        if ((int)row.amount != webhook.Amount || (int)row.price_total != webhook.Amount)
        {
            // Never acknowledge a wrong-amount payment without a trace.
            await conn.ExecuteAsync("""
                insert into payment_reconciliation
                  (booking_id, order_code, amount, reason, status, note)
                values (@bookingId, @orderCode, @amount, 'amount_mismatch', 'open',
                        @note)
                on conflict (order_code) do nothing
                """, new
            {
                bookingId = (Guid)row.booking_id,
                orderCode = webhook.OrderCode.ToString(CultureInfo.InvariantCulture),
                amount = webhook.Amount,
                note = $"Expected {row.price_total}/{row.amount}, got {webhook.Amount}"
            }, tx);
            await tx.CommitAsync(ct);
            return true;
        }
        if ((string)row.booking_status != "pending_payment")
        {
            // The customer paid after the seat hold expired/was cancelled.
            // Acknowledge the webhook (so PayOS stops retrying) but never
            // confirm a dead booking. Put the money in a manual refund queue.
            await conn.ExecuteAsync("""
                insert into payment_reconciliation
                  (booking_id, order_code, amount, reason, status, note)
                values (@bookingId, @orderCode, @amount, 'late_payment', 'open',
                        'Webhook arrived after booking left pending_payment')
                on conflict (order_code) do nothing
                """, new
            {
                bookingId = (Guid)row.booking_id,
                orderCode = webhook.OrderCode.ToString(CultureInfo.InvariantCulture),
                amount = webhook.Amount
            }, tx);
            await tx.CommitAsync(ct);
            return true;
        }

        var meta = JsonSerializer.Serialize(new
        {
            reference = webhook.Reference,
            transactionDateTime = webhook.TransactionDateTime,
            payosDescription = webhook.Description
        });
        await conn.ExecuteAsync("""
            update payments
            set status = 'succeeded', captured_at = now(),
                metadata = metadata || @meta::jsonb
            where id = @paymentId
            """, new { paymentId = (Guid)row.payment_id, meta }, tx);
        await conn.ExecuteAsync("""
            update bookings set status = 'confirmed', updated_at = now()
            where id = @bookingId and status = 'pending_payment'
            """, new { bookingId = (Guid)row.booking_id }, tx);

        var amount = (int)row.price_total;
        await ledger.RecordAsync(conn, tx, "payment", "booking", (Guid)row.booking_id,
            ("customer_receivable", 'D', amount),
            ("escrow", 'C', amount));
        await conn.ExecuteAsync("""
            insert into escrow_holds (booking_id, amount, method, status)
            values (@bookingId, @amount, @method, 'held')
            on conflict (booking_id) do nothing
            """, new
        {
            bookingId = (Guid)row.booking_id, amount,
            method = (string?)row.payment_method ?? "payos"
        }, tx);

        await conn.ExecuteAsync("""
            insert into conversations (booking_id) values (@bookingId)
            on conflict (booking_id) do nothing
            """, new { bookingId = (Guid)row.booking_id }, tx);
        await Notifier.NotifyAsync(conn, tx, (Guid)row.driver_id, "booking.paid",
            "Khách đã thanh toán", $"{row.seats} ghế · {row.origin_label} → {row.destination_label}");
        await conn.ExecuteAsync("""
            insert into outbox (aggregate_type, aggregate_id, type, payload)
            values ('booking', @bookingId, 'booking.confirmed', '{}'::jsonb)
            """, new { bookingId = (Guid)row.booking_id }, tx);

        await tx.CommitAsync(ct);
        return true;
    }
}
