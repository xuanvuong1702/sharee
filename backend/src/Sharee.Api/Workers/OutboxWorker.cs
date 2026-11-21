using System.Text.Json;
using Dapper;
using Microsoft.AspNetCore.SignalR;
using Sharee.Api.Hubs;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Api.Workers;

/// <summary>
/// Claims a small batch with a short UPDATE ... RETURNING, then delivers
/// SignalR/push outside any DB transaction. Network latency can no longer hold
/// row locks or block the outbox table.
/// </summary>
public sealed class OutboxWorker(
    Db db,
    IHubContext<NotificationHub> notifications,
    PushService push,
    ILogger<OutboxWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await using var conn = await db.OpenAsync(stoppingToken);
                var events = (await conn.QueryAsync<dynamic>("""
                    update outbox set claimed_at = now()
                    where id in (
                        select id from outbox
                        where processed_at is null
                          and dead_lettered_at is null
                          and next_attempt_at <= now()
                          and (claimed_at is null or claimed_at < now() - interval '5 minutes')
                        order by id
                        limit 50
                        for update skip locked)
                    returning id, type, payload
                    """)).ToList();

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
                            try
                            {
                                var title = payload.TryGetProperty("title", out JsonElement t)
                                    ? t.GetString() ?? "" : "";
                                var body = payload.TryGetProperty("body", out JsonElement b)
                                    ? b.GetString() ?? "" : "";
                                var type = payload.TryGetProperty("type", out JsonElement ty)
                                    ? ty.GetString() ?? "" : "";
                                await push.SendAsync(userId, title, body, new { type }, stoppingToken);
                            }
                            catch (Exception pushEx)
                            {
                                // Push is best-effort; SignalR already delivered.
                                logger.LogWarning("Push delivery failed: {Message}", pushEx.Message);
                            }
                        }

                        await conn.ExecuteAsync("""
                            update outbox set processed_at = now(), attempts = attempts + 1,
                                claimed_at = null
                            where id = @id
                            """, new { id = (long)evt.id });
                    }
                    catch (Exception ex)
                    {
                        logger.LogWarning("Outbox event {Id} failed: {Message}", (long)evt.id, ex.Message);
                        await conn.ExecuteAsync("""
                            update outbox
                            set attempts = attempts + 1,
                                claimed_at = null,
                                last_error = @error,
                                next_attempt_at = now() + make_interval(
                                    secs => least(300, 10 * power(2, least(attempts, 5)))::int),
                                dead_lettered_at = case
                                    when attempts + 1 >= 5 then now() else dead_lettered_at end
                            where id = @id
                            """, new { id = (long)evt.id, error = ex.Message });
                    }
                }

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
