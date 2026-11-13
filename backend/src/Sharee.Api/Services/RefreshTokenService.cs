using System.Security.Cryptography;
using System.Text;
using Dapper;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Services;

public sealed class RefreshTokenService(Db db, JwtOptions options)
{
    private static string Hash(string value)
        => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();

    private TimeSpan Lifetime => TimeSpan.FromDays(Math.Max(1, options.RefreshDays));

    public async Task<string> IssueAsync(Guid userId, CancellationToken ct = default)
    {
        var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32)).ToLowerInvariant();
        await using var conn = await db.OpenAsync(ct);
        await conn.ExecuteAsync("""
            insert into refresh_tokens (user_id, token_hash, expires_at)
            values (@userId, @hash, now() + @lifetime)
            """, new { userId, hash = Hash(token), lifetime = Lifetime });
        return token;
    }

    public async Task<(UserRow User, string RefreshToken)?> RotateAsync(
        string token, CancellationToken ct = default)
    {
        var hash = Hash(token);
        await using var conn = await db.OpenAsync(ct);
        var tokenRow = await conn.QuerySingleOrDefaultAsync<dynamic>("""
            select user_id, revoked_at, expires_at from refresh_tokens where token_hash = @hash
            """, new { hash });
        if (tokenRow is null) return null;

        if (tokenRow.revoked_at is not null)
        {
            // Reuse of a rotated token: revoke the whole session family.
            await conn.ExecuteAsync("""
                update refresh_tokens set revoked_at = now()
                where user_id = @userId and revoked_at is null
                """, new { userId = (Guid)tokenRow.user_id });
            return null;
        }
        if ((DateTime)tokenRow.expires_at <= DateTime.UtcNow) return null;

        var user = await conn.QuerySingleOrDefaultAsync<UserRow>(
            "select * from users where id = @id", new { id = (Guid)tokenRow.user_id });
        if (user is null) return null;

        var newToken = Convert.ToHexString(RandomNumberGenerator.GetBytes(32)).ToLowerInvariant();
        await using var tx = await conn.BeginTransactionAsync(ct);
        var revoked = await conn.ExecuteAsync("""
            update refresh_tokens set revoked_at = now()
            where token_hash = @hash and revoked_at is null
            """, new { hash }, tx);
        if (revoked == 0)
        {
            await tx.RollbackAsync(ct);
            return null;
        }
        await conn.ExecuteAsync("""
            insert into refresh_tokens (user_id, token_hash, expires_at)
            values (@userId, @newHash, now() + @lifetime)
            """, new { userId = user.Id, newHash = Hash(newToken), lifetime = Lifetime }, tx);
        await tx.CommitAsync(ct);

        return (user, newToken);
    }

    public async Task RevokeAsync(string token, CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync(ct);
        await conn.ExecuteAsync("""
            update refresh_tokens set revoked_at = now()
            where token_hash = @hash and revoked_at is null
            """, new { hash = Hash(token) });
    }
}
