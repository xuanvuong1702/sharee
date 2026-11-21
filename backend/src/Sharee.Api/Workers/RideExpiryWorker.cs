using Dapper;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Workers;

/// <summary>Expires ride requests that no driver accepted, so they stop
/// appearing in the driver queue and cannot be accepted hours later.</summary>
public sealed class RideExpiryWorker(Db db, ILogger<RideExpiryWorker> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(1));
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await using var conn = await db.OpenAsync(stoppingToken);
                var expired = await conn.ExecuteAsync("""
                    update ride_requests
                    set status = 'expired', updated_at = now()
                    where status = 'searching'
                      and created_at < now() - interval '15 minutes'
                    """);
                if (expired > 0) log.LogInformation("Expired {Count} ride requests", expired);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                log.LogWarning(ex, "Ride expiry sweep failed");
            }

            try { await timer.WaitForNextTickAsync(stoppingToken); }
            catch (OperationCanceledException) { break; }
        }
    }
}
