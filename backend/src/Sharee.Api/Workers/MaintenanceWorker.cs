using Dapper;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Workers;

public sealed class MaintenanceWorker(Db db, ILogger<MaintenanceWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await using var conn = await db.OpenAsync(stoppingToken);
                await using var tx = await conn.BeginTransactionAsync(stoppingToken);

                var expired = await conn.ExecuteAsync("""
                    with expired as (
                        update bookings set status = 'cancelled_by_passenger', updated_at = now()
                        where status in ('pending_payment','pending_driver')
                          and expires_at is not null and expires_at < now()
                        returning trip_id, seats
                    ), agg as (
                        select trip_id, sum(seats)::int as seats from expired group by trip_id
                    )
                    update trips t
                    set seats_available = least(t.seats_total, t.seats_available + agg.seats),
                        status = case when t.status = 'full' then 'open' else t.status end,
                        updated_at = now()
                    from agg where t.id = agg.trip_id
                    """, transaction: tx);

                var tokens = await conn.ExecuteAsync("""
                    delete from refresh_tokens
                    where (expires_at < now() - interval '7 days')
                       or (revoked_at is not null and revoked_at < now() - interval '7 days')
                    """, transaction: tx);

                var otps = await conn.ExecuteAsync(
                    "delete from otp_codes where created_at < now() - interval '1 day'",
                    transaction: tx);

                var locations = await conn.ExecuteAsync("""
                    delete from trip_locations l using trips t
                    where l.trip_id = t.id
                      and l.updated_at < now() - interval '24 hours'
                      and (t.status in ('completed','cancelled')
                           or t.departure_time < now() - interval '24 hours')
                    """, transaction: tx);

                var outbox = await conn.ExecuteAsync("""
                    delete from outbox
                    where processed_at is not null and processed_at < now() - interval '7 days'
                    """, transaction: tx);

                var notifications = await conn.ExecuteAsync("""
                    delete from notifications
                    where read_at is not null and created_at < now() - interval '90 days'
                    """, transaction: tx);

                var verifications = await conn.ExecuteAsync("""
                    update users
                    set verification_status = 'expired',
                        verified_level = 1,
                        verification_rejection_reason = 'Giấy tờ xác thực đã hết hạn, vui lòng gửi lại hồ sơ.'
                    where verification_status = 'approved'
                      and verification_expires_at is not null
                      and verification_expires_at < now()
                    """, transaction: tx);

                await tx.CommitAsync(stoppingToken);
                if (expired + tokens + otps + locations + outbox + notifications + verifications > 0)
                {
                    logger.LogInformation(
                        "Maintenance: expiredBookings={Expired}, tokens={Tokens}, otps={Otps}, locations={Locations}, outbox={Outbox}, notifications={Notifications}, verifications={Verifications}",
                        expired, tokens, otps, locations, outbox, notifications, verifications);
                }
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                logger.LogWarning("Maintenance worker error: {Message}", ex.Message);
            }

            await Task.Delay(TimeSpan.FromHours(6), stoppingToken);
        }
    }
}
