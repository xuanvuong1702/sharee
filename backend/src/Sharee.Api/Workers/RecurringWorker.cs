using Sharee.Api.Services;

namespace Sharee.Api.Workers;

public sealed class RecurringWorker(IServiceScopeFactory scopeFactory, ILogger<RecurringWorker> logger)
    : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await Task.Delay(TimeSpan.FromSeconds(15), stoppingToken);
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                var service = scope.ServiceProvider.GetRequiredService<RecurringTripService>();
                var created = await service.MaterializeAllAsync(stoppingToken);
                if (created > 0)
                    logger.LogInformation("Recurring trips: materialized {Count} trips", created);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                logger.LogWarning("Recurring worker error: {Message}", ex.Message);
            }

            await Task.Delay(TimeSpan.FromHours(6), stoppingToken);
        }
    }
}
