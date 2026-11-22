using System.Collections.Concurrent;
using StackExchange.Redis;

namespace Sharee.Api.Services;

/// <summary>OTP abuse guard. Uses Redis counters when available so limits are
/// shared across instances; falls back to process memory in local/dev.</summary>
public sealed class OtpRateGuard
{
    private readonly IConnectionMultiplexer? _redis;
    private readonly ConcurrentDictionary<string, Window> _ips = new();
    private readonly Window _global = new();
    private readonly int _globalPerMinute;
    private readonly int _perIpPer10Minutes;

    public OtpRateGuard(IConfiguration config, IConnectionMultiplexer? redis = null)
    {
        _redis = redis;
        _globalPerMinute = Math.Clamp(config.GetValue("Otp:GlobalPerMinute", 600), 1, 100_000);
        _perIpPer10Minutes = Math.Clamp(config.GetValue("Otp:PerIpPer10Minutes", 10), 1, 1_000);
    }

    public async Task<bool> AllowAsync(string? ip)
    {
        if (_redis is { IsConnected: true })
        {
            try
            {
                var db = _redis.GetDatabase();
                var minute = DateTimeOffset.UtcNow.ToUnixTimeSeconds() / 60;
                var globalKey = $"otp:global:{minute}";
                var count = await db.StringIncrementAsync(globalKey);
                if (count == 1) await db.KeyExpireAsync(globalKey, TimeSpan.FromMinutes(2));
                if (count > _globalPerMinute) return false;
                if (string.IsNullOrWhiteSpace(ip)) return true;
                var ipKey = $"otp:ip:{ip}";
                var ipCount = await db.StringIncrementAsync(ipKey);
                if (ipCount == 1) await db.KeyExpireAsync(ipKey, TimeSpan.FromMinutes(10));
                return ipCount <= _perIpPer10Minutes;
            }
            catch
            {
                // Fall through to the in-process guard if Redis is flaky.
            }
        }

        var now = DateTimeOffset.UtcNow;
        if (!_global.TryTake(now, _globalPerMinute, TimeSpan.FromMinutes(1))) return false;
        if (string.IsNullOrWhiteSpace(ip)) return true;
        return _ips.GetOrAdd(ip, _ => new Window()).TryTake(now, _perIpPer10Minutes,
            TimeSpan.FromMinutes(10));
    }

    private sealed class Window
    {
        private readonly object _gate = new();
        private DateTimeOffset _start;
        private int _count;

        public bool TryTake(DateTimeOffset now, int limit, TimeSpan period)
        {
            lock (_gate)
            {
                if (now - _start >= period)
                {
                    _start = now;
                    _count = 0;
                }
                if (_count >= limit) return false;
                _count++;
                return true;
            }
        }
    }
}
