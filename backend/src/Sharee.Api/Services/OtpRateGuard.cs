using System.Collections.Concurrent;

namespace Sharee.Api.Services;

/// <summary>Process-local abuse guard for OTP requests. For multi-instance
/// deployments back this with Redis; the database still enforces per-phone.</summary>
public sealed class OtpRateGuard
{
    private readonly ConcurrentDictionary<string, Window> _ips = new();
    private readonly Window _global = new();

    public bool Allow(string? ip)
    {
        var now = DateTimeOffset.UtcNow;
        if (!_global.TryTake(now, 100, TimeSpan.FromMinutes(1))) return false;
        if (string.IsNullOrWhiteSpace(ip)) return true;
        var window = _ips.GetOrAdd(ip, _ => new Window());
        if (window.TryTake(now, 10, TimeSpan.FromMinutes(10))) return true;
        return false;
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
