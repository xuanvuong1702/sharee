using System.Net;
using System.Security.Cryptography;
using System.Text;

namespace Sharee.Api.Services;

/// <summary>Optional IP allow-list + TOTP MFA for /api/admin.</summary>
public static class AdminSecurity
{
    public static bool IsIpAllowed(IPAddress? remote, IEnumerable<string>? allowList)
    {
        if (allowList is null) return true;
        var entries = allowList.Where(x => !string.IsNullOrWhiteSpace(x)).ToArray();
        if (entries.Length == 0) return true;
        if (remote is null) return false;
        if (remote.IsIPv4MappedToIPv6) remote = remote.MapToIPv4();
        foreach (var entry in entries)
        {
            if (IPAddress.TryParse(entry, out var ip) && ip.Equals(remote)) return true;
            if (System.Net.IPNetwork.TryParse(entry, out var network) && network.Contains(remote))
                return true;
        }
        return false;
    }

    public static bool ValidateTotp(string? secret, string? code, DateTimeOffset? now = null)
    {
        if (string.IsNullOrWhiteSpace(secret)) return true;
        if (string.IsNullOrWhiteSpace(code) || code.Length != 6 ||
            !int.TryParse(code, out var expectedCode)) return false;
        var key = DecodeBase32(secret);
        if (key.Length == 0) return false;
        var timestamp = (now ?? DateTimeOffset.UtcNow).ToUnixTimeSeconds();
        var step = timestamp / 30;
        for (var offset = -1; offset <= 1; offset++)
        {
            var counter = step + offset;
            var bytes = BitConverter.GetBytes(counter);
            if (BitConverter.IsLittleEndian) Array.Reverse(bytes);
            using var hmac = new HMACSHA1(key);
            var hash = hmac.ComputeHash(bytes);
            var index = hash[^1] & 0x0F;
            var value = ((hash[index] & 0x7F) << 24) |
                        ((hash[index + 1] & 0xFF) << 16) |
                        ((hash[index + 2] & 0xFF) << 8) |
                        (hash[index + 3] & 0xFF);
            if (value % 1_000_000 == expectedCode) return true;
        }
        return false;
    }

    private static byte[] DecodeBase32(string value)
    {
        const string alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
        var clean = value.Trim().Replace(" ", "").Replace("-", "").ToUpperInvariant();
        var bytes = new List<byte>();
        var buffer = 0;
        var bits = 0;
        foreach (var ch in clean)
        {
            var index = alphabet.IndexOf(ch);
            if (index < 0) continue;
            buffer = (buffer << 5) | index;
            bits += 5;
            if (bits >= 8)
            {
                bytes.Add((byte)((buffer >> (bits - 8)) & 0xFF));
                bits -= 8;
            }
        }
        return bytes.ToArray();
    }
}
