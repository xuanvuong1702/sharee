using System.Text.Json;
using Dapper;
using Microsoft.AspNetCore.SignalR;
using Sharee.Api.Hubs;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Workers;

public sealed class OutboxWorker(
    Db db,
    IHubContext<NotificationHub> notifications,
    ILogger<OutboxWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await using var conn = await db.OpenAsync(stoppingToken);
                await using var tx = await conn.BeginTransactionAsync(stoppingToken);
                var events = (await conn.QueryAsync<dynamic>("""
                    select id, type, payload from outbox
                    where processed_at is null and next_attempt_at <= now()
                    order by id
                    limit 50
                    for update skip locked
                    """, transaction: tx)).ToList();

                foreach (var evt in events)
                {
                    try
                    {
                        if ((string)evt.type == "notification.created")
                        {
                            var json = evt.payload is string text ? text : evt.payload.ToString();
                            using var doc = JsonDocument.Parse(json!);
                            var payload = doc.RootElement.Clone();
                            var userId = payload.GetProperty("userId").GetGuid();
                            await notifications.Clients.Group($"user:{userId}")
                                .SendAsync("notification", (object)payload, stoppingToken);
                        }

                        await conn.ExecuteAsync(
                            "update outbox set processed_at = now(), attempts = attempts + 1 where id = @id",
                            new { id = (long)evt.id }, tx);
                    }
                    catch (Exception ex)
                    {
                        logger.LogWarning("Outbox event {Id} failed: {Message}", (long)evt.id, ex.Message);
                        await conn.ExecuteAsync("""
                            update outbox
                            set attempts = attempts + 1,
                                last_error = @error,
                                next_attempt_at = now() + interval '10 seconds'
                            where id = @id
                            """, new { id = (long)evt.id, error = ex.Message }, tx);
                    }
                }

                await tx.CommitAsync(stoppingToken);
                if (events.Count > 0)
                    logger.LogInformation("Outbox: processed {Count} events", events.Count);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                logger.LogWarning("Outbox worker error: {Message}", ex.Message);
            }

            await Task.Delay(TimeSpan.FromSeconds(2), stoppingToken);
        }
    }
}
