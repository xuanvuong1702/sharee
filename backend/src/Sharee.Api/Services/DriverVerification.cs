using Dapper;
using Npgsql;

namespace Sharee.Api.Services;

public static class DriverVerification
{
    public static Task<bool> IsApprovedAsync(
        NpgsqlConnection conn, Guid userId, CancellationToken ct = default)
        => conn.ExecuteScalarAsync<bool>("""
            select exists(
                select 1 from users
                where id = @userId
                  and verified_level >= 3
                  and verification_status = 'approved'
                  and (verification_expires_at is null or verification_expires_at > now())
            )
            """, new { userId });
}
