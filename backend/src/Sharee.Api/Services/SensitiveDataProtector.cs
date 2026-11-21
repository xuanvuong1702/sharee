using System.Security.Cryptography;
using System.Text;

namespace Sharee.Api.Services;

/// <summary>
/// AES-256-GCM field protection. Nonce is derived from an HMAC of the plaintext
/// so equality lookups (CCCD/GPLX duplicate checks) still work. Values written
/// before rollout remain readable because plaintext has no "enc:v1:" prefix.
/// Set SECURITY_DATA_KEY or Security:DataKey in production.
/// </summary>
public static class SensitiveDataProtector
{
    private const string Prefix = "enc:v1:";
    private static readonly byte[] Key = BuildKey();

    public static string? Protect(string? value)
    {
        if (string.IsNullOrWhiteSpace(value) || value.StartsWith(Prefix, StringComparison.Ordinal))
            return value;
        var plain = Encoding.UTF8.GetBytes(value);
        var nonce = Nonce(value);
        var cipher = new byte[plain.Length];
        var tag = new byte[16];
        using var aes = new AesGcm(Key, 16);
        aes.Encrypt(nonce, plain, cipher, tag);
        var packed = new byte[nonce.Length + tag.Length + cipher.Length];
        nonce.CopyTo(packed, 0);
        tag.CopyTo(packed, nonce.Length);
        cipher.CopyTo(packed, nonce.Length + tag.Length);
        return Prefix + Convert.ToBase64String(packed);
    }

    public static string? Unprotect(string? value)
    {
        if (string.IsNullOrWhiteSpace(value) || !value.StartsWith(Prefix, StringComparison.Ordinal))
            return value;
        try
        {
            var packed = Convert.FromBase64String(value[Prefix.Length..]);
            if (packed.Length < 29) return value;
            var nonce = packed[..12];
            var tag = packed[12..28];
            var cipher = packed[28..];
            var plain = new byte[cipher.Length];
            using var aes = new AesGcm(Key, 16);
            aes.Decrypt(nonce, cipher, tag, plain);
            return Encoding.UTF8.GetString(plain);
        }
        catch (CryptographicException)
        {
            return value;
        }
        catch (FormatException)
        {
            return value;
        }
    }

    private static byte[] BuildKey()
    {
        var raw = Environment.GetEnvironmentVariable("SECURITY_DATA_KEY")
                  ?? "sharee-dev-data-key-change-in-production";
        return SHA256.HashData(Encoding.UTF8.GetBytes(raw));
    }

    private static byte[] Nonce(string plaintext)
    {
        using var hmac = new HMACSHA256(Key);
        return hmac.ComputeHash(Encoding.UTF8.GetBytes("nonce:" + plaintext))[..12];
    }
}
