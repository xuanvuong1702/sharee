using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using Dapper;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Services;

public sealed class OtpRateLimitException(int retryAfterSeconds)
    : Exception($"OTP rate limit, retry in {retryAfterSeconds}s")
{
    public int RetryAfterSeconds { get; } = Math.Max(1, retryAfterSeconds);
}

public sealed partial class OtpService(Db db, IConfiguration config)
{
    private const int MaxAttempts = 5;
    private static readonly TimeSpan Lifetime = TimeSpan.FromMinutes(5);

    public async Task<(string Code, int ExpiresInSeconds)> IssueAsync(
        string phone, string? ip, CancellationToken ct = default)
    {
        phone = Normalize(phone);
        if (!PhoneRegex().IsMatch(phone))
            throw new ArgumentException("Số điện thoại không hợp lệ");

        var cooldown = Math.Max(0, config.GetValue("Auth:OtpResendSeconds", 60));
        var maxPerHour = Math.Max(1, config.GetValue("Auth:OtpMaxPerHour", 10));
        await using var conn = await db.OpenAsync(ct);

        if (cooldown > 0)
        {
            var elapsedSeconds = await conn.ExecuteScalarAsync<double?>("""
                select extract(epoch from (now() - max(created_at)))
                from otp_codes where phone = @phone
                """, new { phone });
            if (elapsedSeconds is not null && elapsedSeconds.Value < cooldown)
                throw new OtpRateLimitException(
                    Math.Max(1, (int)Math.Ceiling(cooldown - elapsedSeconds.Value)));
        }

        var recent = await conn.ExecuteScalarAsync<int>("""
            select count(*) from otp_codes
            where phone = @phone and created_at > now() - interval '1 hour'
            """, new { phone });
        if (recent >= maxPerHour)
            throw new OtpRateLimitException(3600);

        var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
        var hash = Hash(phone, code);
        await using var tx = await conn.BeginTransactionAsync(ct);
        await conn.ExecuteAsync("""
            update otp_codes set consumed_at = now()
            where phone = @phone and consumed_at is null
            """, new { phone }, tx);
        await conn.ExecuteAsync("""
            insert into otp_codes (phone, code_hash, expires_at, request_ip)
            values (@phone, @hash, now() + @lifetime, @ip)
            """, new { phone, hash, lifetime = Lifetime, ip }, tx);
        await tx.CommitAsync(ct);
        return (code, (int)Lifetime.TotalSeconds);
    }

    public async Task<bool> VerifyAsync(string phone, string code, CancellationToken ct = default)
    {
        phone = Normalize(phone);
        if (!PhoneRegex().IsMatch(phone) || string.IsNullOrWhiteSpace(code)) return false;

        await using var conn = await db.OpenAsync(ct);
        var row = await conn.QuerySingleOrDefaultAsync<dynamic>("""
            select id, code_hash, attempts from otp_codes
            where phone = @phone and consumed_at is null
              and expires_at > now() and attempts < @maxAttempts
            order by created_at desc limit 1
            """, new { phone, maxAttempts = MaxAttempts });
        if (row is null) return false;

        var expected = Hash(phone, code.Trim());
        var matches = FixedTimeEquals((string)row.code_hash, expected);
        if (!matches)
        {
            await conn.ExecuteAsync("""
                update otp_codes set attempts = attempts + 1 where id = @id
                """, new { id = (Guid)row.id });
            return false;
        }

        var affected = await conn.ExecuteAsync("""
            update otp_codes set consumed_at = now()
            where id = @id and consumed_at is null
            """, new { id = (Guid)row.id });
        return affected > 0;
    }

    private static bool FixedTimeEquals(string a, string b)
    {
        try
        {
            return CryptographicOperations.FixedTimeEquals(
                Convert.FromHexString(a), Convert.FromHexString(b));
        }
        catch
        {
            return false;
        }
    }

    private string Hash(string phone, string code)
    {
        var pepper = config["Auth:OtpPepper"]
            ?? throw new InvalidOperationException("Auth:OtpPepper chưa được cấu hình");
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(pepper));
        var bytes = hmac.ComputeHash(Encoding.UTF8.GetBytes($"{phone}:{code}"));
        return Convert.ToHexString(bytes);
    }

    public static string Normalize(string phone)
    {
        var digits = new string(phone.Where(char.IsDigit).ToArray());
        if (digits.StartsWith("84")) digits = "+" + digits;
        else if (digits.StartsWith("0")) digits = "+84" + digits[1..];
        else if (!digits.StartsWith("+")) digits = "+" + digits;
        return digits;
    }

    [GeneratedRegex(@"^\+84\d{9}$")]
    private static partial Regex PhoneRegex();
}
