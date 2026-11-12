using Dapper;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Workers;

public sealed class OutboxWorker(Db db, ILogger<OutboxWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await using var conn = await db.OpenAsync(stoppingToken);
                var ids = (await conn.QueryAsync<long>("""
                    select id from outbox
                    where processed_at is null and next_attempt_at <= now()
                    order by id
                    limit 50
                    """)).ToList();

                foreach (var id in ids)
                {
                    // Demo worker: mark as processed. In production this is where push/email
                    // would be dispatched to a provider.
                    await conn.ExecuteAsync(
                        "update outbox set processed_at = now(), attempts = attempts + 1 where id = @id",
                        new { id });
                }

                if (ids.Count > 0)
                    logger.LogInformation("Outbox: processed {Count} events", ids.Count);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                logger.LogWarning("Outbox worker error: {Message}", ex.Message);
            }

            await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
        }
    }
}
