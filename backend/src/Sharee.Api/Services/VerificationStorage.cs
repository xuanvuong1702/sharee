using System.Security.Cryptography;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Options;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Services;

public static class VerificationTypes
{
    public static readonly string[] All =
    [
        "id_front", "id_back", "license_front", "license_back",
        "vehicle_registration", "insurance", "selfie"
    ];

    public static readonly string[] RequiredForDriver =
    [
        "id_front", "id_back", "license_front", "license_back",
        "vehicle_registration", "insurance", "selfie"
    ];

    public static bool IsValid(string type) => All.Contains(type);
}

public sealed partial class VerificationStorage(
    IOptions<VerificationStorageOptions> options,
    ILogger<VerificationStorage> logger)
{
    private const long MaxBytes = 10 * 1024 * 1024;
    private readonly string _root = Path.GetFullPath(options.Value.RootPath);

    public string Root => _root;

    public async Task<StoredVerificationFile> SaveAsync(
        Guid userId, string type, IFormFile file, CancellationToken ct = default)
    {
        if (!VerificationTypes.IsValid(type))
            throw new InvalidOperationException("Loại giấy tờ không hợp lệ");
        if (file.Length is <= 0 or > MaxBytes)
            throw new InvalidOperationException("Tệp phải có dung lượng từ 1 byte đến 10 MB");

        await using var input = file.OpenReadStream();
        using var buffer = new MemoryStream();
        await input.CopyToAsync(buffer, ct);
        var bytes = buffer.ToArray();
        var mime = DetectMime(bytes.AsSpan(0, Math.Min(bytes.Length, 8)));
        if (mime is null)
            throw new InvalidOperationException("Chỉ chấp nhận ảnh JPEG/PNG hoặc PDF");

        var ext = mime switch
        {
            "image/jpeg" => ".jpg",
            "image/png" => ".png",
            _ => ".pdf"
        };
        var dir = Path.Combine(_root, userId.ToString("N"));
        Directory.CreateDirectory(dir);
        var storedName = $"{Guid.NewGuid():N}{ext}";
        var fullPath = Path.Combine(dir, storedName);
        var relative = Path.Combine(userId.ToString("N"), storedName).Replace('\\', '/');

        await File.WriteAllBytesAsync(fullPath, bytes, ct);
        var hash = SHA256.HashData(bytes);
        var original = Regex.Replace(Path.GetFileName(file.FileName), @"[^\w\.\- ]", "_");
        if (string.IsNullOrWhiteSpace(original)) original = "document" + ext;
        logger.LogInformation("Stored verification document {Type} for {UserId} ({Bytes} bytes)",
            type, userId, bytes.Length);
        return new StoredVerificationFile(
            relative, original, mime, bytes.Length, Convert.ToHexString(hash).ToLowerInvariant());
    }

    public string? Resolve(string storedPath)
    {
        var full = Path.GetFullPath(Path.Combine(_root, storedPath));
        var prefix = _root.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        return full.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) ? full : null;
    }

    public void Delete(string? storedPath)
    {
        if (string.IsNullOrWhiteSpace(storedPath)) return;
        var full = Resolve(storedPath);
        if (full is null || !File.Exists(full)) return;
        try
        {
            File.Delete(full);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Could not delete verification document {Path}", storedPath);
        }
    }

    private static string? DetectMime(ReadOnlySpan<byte> header)
    {
        if (header.Length >= 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF)
            return "image/jpeg";
        if (header.Length >= 8 && header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E
            && header[3] == 0x47 && header[4] == 0x0D && header[5] == 0x0A && header[6] == 0x1A
            && header[7] == 0x0A)
            return "image/png";
        if (header.Length >= 4 && header[0] == 0x25 && header[1] == 0x50 && header[2] == 0x44
            && header[3] == 0x46)
            return "application/pdf";
        return null;
    }
}
