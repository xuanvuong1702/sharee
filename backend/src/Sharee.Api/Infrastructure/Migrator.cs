using System.Reflection;
using Dapper;
using Npgsql;

namespace Sharee.Api.Infrastructure;

public sealed class Migrator(
    NpgsqlDataSource dataSource,
    IConfiguration config,
    ILogger<Migrator> logger)
{
    public async Task RunAsync(CancellationToken ct = default)
    {
        const int maxAttempts = 40;
        for (var attempt = 1; attempt <= maxAttempts; attempt++)
        {
            try
            {
                await using var conn = await dataSource.OpenConnectionAsync(ct);
                await conn.ExecuteAsync("""
                    CREATE TABLE IF NOT EXISTS schema_migrations (
                        name text PRIMARY KEY,
                        applied_at timestamptz NOT NULL DEFAULT now()
                    )
                    """);

                await conn.ExecuteAsync(new CommandDefinition(
                    "select pg_advisory_lock(hashtext('sharee:migrations'))", commandTimeout: 0));
                try
                {
                    var applied = (await conn.QueryAsync<string>("select name from schema_migrations"))
                        .ToHashSet(StringComparer.OrdinalIgnoreCase);

                    var assembly = Assembly.GetExecutingAssembly();
                    var includeSeed = config.GetValue("Seed:DemoData", false);
                    var resources = assembly.GetManifestResourceNames()
                        .Where(n => n.Contains(".Migrations.") && n.EndsWith(".sql", StringComparison.OrdinalIgnoreCase))
                        .Where(n => includeSeed || !n.EndsWith("002_seed.sql", StringComparison.OrdinalIgnoreCase))
                        .OrderBy(n => n, StringComparer.Ordinal)
                        .ToList();

                    foreach (var resource in resources)
                    {
                        var name = resource[(resource.LastIndexOf(".Migrations.", StringComparison.Ordinal)
                                             + ".Migrations.".Length)..];
                        if (applied.Contains(name)) continue;

                        logger.LogInformation("Applying migration {Migration}", name);
                        await using var stream = assembly.GetManifestResourceStream(resource)
                            ?? throw new InvalidOperationException($"Missing resource {resource}");
                        using var reader = new StreamReader(stream);
                        var sql = await reader.ReadToEndAsync(ct);

                        await using var tx = await conn.BeginTransactionAsync(ct);
                        await conn.ExecuteAsync(sql, transaction: tx);
                        await conn.ExecuteAsync(
                            "insert into schema_migrations (name) values (@name) on conflict do nothing",
                            new { name }, tx);
                        await tx.CommitAsync(ct);
                    }

                    logger.LogInformation("Database migrations complete ({Count} files, seed={Seed})",
                        resources.Count, includeSeed);
                    return;
                }
                finally
                {
                    await conn.ExecuteAsync(new CommandDefinition(
                        "select pg_advisory_unlock(hashtext('sharee:migrations'))", commandTimeout: 0));
                }
            }
            catch (Exception ex) when (attempt < maxAttempts)
            {
                logger.LogWarning("Database not ready (attempt {Attempt}/{Max}): {Message}",
                    attempt, maxAttempts, ex.Message);
                await Task.Delay(TimeSpan.FromSeconds(2), ct);
            }
        }
    }
}
