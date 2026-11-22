using System.Security.Cryptography;
using System.Text;

namespace Sharee.Api.Services;

/// <summary>
/// Versioned AES-256-GCM field protection.
/// - v2 (current): HKDF-separated AES and nonce keys, 12-byte nonce.
/// - v1 (legacy): direct SHA-256 key, kept only to decrypt existing rows.
/// Nonce is derived from an HMAC of the plaintext so equality lookups
/// (CCCD/GPLX duplicate checks) keep working.
/// </summary>
public static class SensitiveDataProtector
{
    private const string V2 = "enc:v2:";
    private const string V1 = "enc:v1:";
    private static readonly byte[] Master = ReadKey("SECURITY_DATA_KEY");
    private static readonly byte[] LegacyKey = ReadLegacyKey();
    private static readonly byte[] AesKey = Derive(Master, "sharee/aes/v2");
    private static readonly byte[] NonceKey = Derive(Master, "sharee/nonce/v2");

    /// <summary>Production must provide a strong key; fail at startup, not on
    /// the first KYC upload.</summary>
    public static void EnsureConfigured(bool production)
    {
        if (!production) return;
        if (Master.Length < 32)
            throw new InvalidOperationException(
                "SECURITY_DATA_KEY must be at least 32 bytes in Production");
        if (Master.SequenceEqual(Encoding.UTF8.GetBytes(
                "sharee-dev-data-key-change-in-production")))
            throw new InvalidOperationException(
                "SECURITY_DATA_KEY must not use the public development default");
        var raw = Environment.GetEnvironmentVariable("SECURITY_DATA_KEY") ?? "";
        var lower = raw.ToLowerInvariant();
        if (lower.Contains("replace-with") || lower.Contains("change-me")
            || lower.Contains("example"))
            throw new InvalidOperationException(
                "SECURITY_DATA_KEY still contains a placeholder value");
    }

    public static string? Protect(string? value)
    {
        if (string.IsNullOrWhiteSpace(value) || IsEncrypted(value)) return value;
        var plain = Encoding.UTF8.GetBytes(value);
        var nonce = Nonce(value);
        var cipher = new byte[plain.Length];
        var tag = new byte[16];
        using var aes = new AesGcm(AesKey, 16);
        aes.Encrypt(nonce, plain, cipher, tag);
        var packed = new byte[nonce.Length + tag.Length + cipher.Length];
        nonce.CopyTo(packed, 0);
        tag.CopyTo(packed, nonce.Length);
        cipher.CopyTo(packed, nonce.Length + tag.Length);
        return V2 + Convert.ToBase64String(packed);
    }

    public static string? Unprotect(string? value)
    {
        if (string.IsNullOrWhiteSpace(value) || !IsEncrypted(value)) return value;
        if (value.StartsWith(V2, StringComparison.Ordinal))
            return Decrypt(value[V2.Length..], AesKey);
        if (value.StartsWith(V1, StringComparison.Ordinal))
            return DecryptLegacy(value[V1.Length..]);
        throw new CryptographicException("Unknown encrypted value version");
    }

    public static bool IsEncrypted(string value) =>
        value.StartsWith(V2, StringComparison.Ordinal) ||
        value.StartsWith(V1, StringComparison.Ordinal);

    private static string Decrypt(string payload, byte[] aesKey)
    {
        var packed = Convert.FromBase64String(payload);
        if (packed.Length < 29) throw new CryptographicException("Ciphertext too short");
        var nonce = packed[..12];
        var tag = packed[12..28];
        var cipher = packed[28..];
        var plain = new byte[cipher.Length];
        using var aes = new AesGcm(aesKey, 16);
        aes.Decrypt(nonce, cipher, tag, plain);
        return Encoding.UTF8.GetString(plain);
    }

    private static string DecryptLegacy(string payload)
    {
        var key = LegacyKey.Length > 0 ? LegacyKey : SHA256.HashData(Master);
        var packed = Convert.FromBase64String(payload);
        if (packed.Length < 29) throw new CryptographicException("Ciphertext too short");
        var nonce = packed[..12];
        var tag = packed[12..28];
        var cipher = packed[28..];
        var plain = new byte[cipher.Length];
        using var aes = new AesGcm(key, 16);
        aes.Decrypt(nonce, cipher, tag, plain);
        return Encoding.UTF8.GetString(plain);
    }

    private static byte[] ReadKey(string name)
    {
        var raw = Environment.GetEnvironmentVariable(name);
        if (string.IsNullOrWhiteSpace(raw))
            return Encoding.UTF8.GetBytes("sharee-dev-data-key-change-in-production");
        try
        {
            var bytes = Convert.FromBase64String(raw);
            if (bytes.Length >= 16) return bytes;
        }
        catch (FormatException) { }
        return Encoding.UTF8.GetBytes(raw);
    }

    private static byte[] ReadLegacyKey()
    {
        var raw = Environment.GetEnvironmentVariable("SECURITY_DATA_KEY_LEGACY");
        if (string.IsNullOrWhiteSpace(raw)) return [];
        // v1 used SHA-256(raw) directly as the AES key.
        return SHA256.HashData(Encoding.UTF8.GetBytes(raw));
    }

    private static byte[] Derive(byte[] master, string info) =>
        HKDF.DeriveKey(HashAlgorithmName.SHA256, master, 32, salt: [], info: Encoding.UTF8.GetBytes(info));

    private static byte[] Nonce(string plaintext)
    {
        using var hmac = new HMACSHA256(NonceKey);
        return hmac.ComputeHash(Encoding.UTF8.GetBytes("nonce:" + plaintext))[..12];
    }
}
