using System.Collections.Concurrent;
using System.Security.Cryptography;

namespace Sharee.Api.Services;

public sealed class OtpService
{
    private sealed record Entry(string Code, DateTimeOffset ExpiresAt, int Attempts);

    private readonly ConcurrentDictionary<string, Entry> _codes = new();
    private readonly ConcurrentDictionary<string, List<DateTimeOffset>> _requests = new();

    public (string Code, int ExpiresInSeconds) Issue(string phone)
    {
        phone = Normalize(phone);
        var now = DateTimeOffset.UtcNow;
        var history = _requests.GetOrAdd(phone, _ => new List<DateTimeOffset>());
        lock (history)
        {
            history.RemoveAll(x => x < now.AddHours(-1));
            if (history.Count >= 20)
                throw new InvalidOperationException("RATE_LIMIT");
            history.Add(now);
        }

        var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
        _codes[phone] = new Entry(code, now.AddMinutes(5), 0);
        return (code, 300);
    }

    public bool Verify(string phone, string code)
    {
        phone = Normalize(phone);
        if (!_codes.TryGetValue(phone, out var entry)) return false;
        if (entry.ExpiresAt < DateTimeOffset.UtcNow) return false;
        if (entry.Attempts >= 5) return false;

        if (entry.Code != code.Trim())
        {
            _codes[phone] = entry with { Attempts = entry.Attempts + 1 };
            return false;
        }

        _codes.TryRemove(phone, out _);
        return true;
    }

    public static string Normalize(string phone)
    {
        var digits = new string(phone.Where(char.IsDigit).ToArray());
        if (digits.StartsWith("84")) digits = "+" + digits;
        else if (digits.StartsWith("0")) digits = "+84" + digits[1..];
        else if (!digits.StartsWith("+")) digits = "+" + digits;
        return digits;
    }
}
