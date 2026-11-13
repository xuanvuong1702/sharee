using System.Security.Cryptography;
using System.Text;
using Dapper;
using Npgsql;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Services;

public sealed class RefreshTokenService(Db db, JwtOptions options)
{
    private static string Hash(string value)
        => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();

    public async Task<string> IssueAsync(Guid userId, CancellationToken ct = default)
    {
        var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32)).ToLowerInvariant();
        await using var conn = await db.OpenAsync(ct);
        await conn.ExecuteAsync("""
            insert into refresh_tokens (user_id, token_hash, expires_at)
            values (@userId, @hash, now() + interval '30 days')
            """, new { userId, hash = Hash(token) });
        return token;
    }

    public async Task<(UserRow User, string RefreshToken)?> RotateAsync(string token, CancellationToken ct = default)
    {
        var hash = Hash(token);
        await using var conn = await db.OpenAsync(ct);
        var user = await conn.QuerySingleOrDefaultAsync<UserRow>("""
            select u.* from refresh_tokens t
            join users u on u.id = t.user_id
            where t.token_hash = @hash and t.revoked_at is null and t.expires_at > now()
            """, new { hash });
        if (user is null) return null;

        var newToken = Convert.ToHexString(RandomNumberGenerator.GetBytes(32)).ToLowerInvariant();
        await using var tx = await conn.BeginTransactionAsync(ct);
        await conn.ExecuteAsync(
            "update refresh_tokens set revoked_at = now() where token_hash = @hash",
            new { hash }, tx);
        await conn.ExecuteAsync("""
            insert into refresh_tokens (user_id, token_hash, expires_at)
            values (@userId, @newHash, now() + interval '30 days')
            """, new { userId = user.Id, newHash = Hash(newToken) }, tx);
        await tx.CommitAsync(ct);

        _ = options; // options kept for future per-environment TTL
        return (user, newToken);
    }

    public async Task RevokeAsync(string token, CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync(ct);
        await conn.ExecuteAsync(
            "update refresh_tokens set revoked_at = now() where token_hash = @hash and revoked_at is null",
            new { hash = Hash(token) });
    }
}
