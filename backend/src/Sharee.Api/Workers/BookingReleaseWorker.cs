using Dapper;
using Microsoft.Extensions.DependencyInjection;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Api.Workers;

/// <summary>Releases escrow after the two-hour dispute window when the
/// passenger has not confirmed or opened an appeal.</summary>
public sealed class BookingReleaseWorker(
    Db db, IServiceScopeFactory scopes, ILogger<BookingReleaseWorker> log)
    : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(1));
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await using var conn = await db.OpenAsync(stoppingToken);
                var ids = (await conn.QueryAsync<Guid>("""
                    select e.booking_id
                    from escrow_holds e
                    join bookings b on b.id = e.booking_id
                    where e.status = 'held'
                      and b.status = 'completed'
                      and e.release_at is not null
                      and e.release_at <= now()
                      and not exists (
                        select 1 from appeals a
                        where a.booking_id = e.booking_id
                          and a.status in ('open','investigating'))
                    order by e.release_at
                    limit 50
                    """)).ToList();

                foreach (var id in ids)
                {
                    await using var scope = scopes.CreateAsyncScope();
                    var settlement = scope.ServiceProvider.GetRequiredService<BookingSettlementService>();
                    var result = await settlement.ReleaseAsync(id, null, "holdback_expired", stoppingToken);
                    if (!result.Ok)
                        log.LogWarning("Release {BookingId} skipped: {Status} {Error}", id, result.Status, result.Error);
                }
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                log.LogWarning(ex, "Booking release sweep failed");
            }

            try { await timer.WaitForNextTickAsync(stoppingToken); }
            catch (OperationCanceledException) { break; }
        }
    }
}
