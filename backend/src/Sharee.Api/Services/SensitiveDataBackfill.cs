using Dapper;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Services;

/// <summary>One-time idempotent backfill for fields written before field
/// encryption. Safe to run on every boot; values already prefixed are skipped.</summary>
public sealed class SensitiveDataBackfill(Db db, ILogger<SensitiveDataBackfill> logger)
{
    public async Task RunAsync(CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync(ct);
        var users = await conn.QueryAsync<dynamic>("""
            select id, id_number, license_number, vehicle_registration
            from users
            where (id_number is not null and id_number not like 'enc:v1:%')
               or (license_number is not null and license_number not like 'enc:v1:%')
               or (vehicle_registration is not null and vehicle_registration not like 'enc:v1:%')
            """);
        foreach (var user in users)
        {
            await conn.ExecuteAsync("""
                update users set id_number = @idNumber, license_number = @license,
                    vehicle_registration = @registration where id = @id
                """, new
            {
                id = (Guid)user.id,
                idNumber = SensitiveDataProtector.Protect((string?)user.id_number),
                license = SensitiveDataProtector.Protect((string?)user.license_number),
                registration = SensitiveDataProtector.Protect((string?)user.vehicle_registration)
            });
        }
        var withdrawals = await conn.QueryAsync<dynamic>("""
            select id, account_number from driver_withdrawals
            where account_number not like 'enc:v1:%'
            """);
        foreach (var row in withdrawals)
        {
            await conn.ExecuteAsync(
                "update driver_withdrawals set account_number = @number where id = @id",
                new { id = (Guid)row.id, number = SensitiveDataProtector.Protect((string)row.account_number) });
        }
        if (users.Any() || withdrawals.Any())
            logger.LogInformation("Encrypted {Users} users and {Withdrawals} withdrawals at rest",
                users.Count(), withdrawals.Count());

        var tips = await conn.QueryAsync<dynamic>("""
            select driver_id, account_number from driver_tip_accounts
            where account_number not like 'enc:v1:%'
            """);
        foreach (var row in tips)
        {
            await conn.ExecuteAsync(
                "update driver_tip_accounts set account_number = @number where driver_id = @id",
                new { id = (Guid)row.driver_id, number = SensitiveDataProtector.Protect((string)row.account_number) });
        }
    }
}
