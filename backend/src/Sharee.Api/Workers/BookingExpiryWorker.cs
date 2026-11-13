using Dapper;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Workers;

public sealed class BookingExpiryWorker(Db db, ILogger<BookingExpiryWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await using var conn = await db.OpenAsync(stoppingToken);
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
                    """);
                if (expired > 0)
                    logger.LogInformation("Expired {Count} unpaid booking rows and released seats", expired);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                logger.LogWarning("Booking expiry worker error: {Message}", ex.Message);
            }

            await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
        }
    }
}
