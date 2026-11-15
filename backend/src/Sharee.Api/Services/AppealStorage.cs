using System.Security.Cryptography;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Options;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Services;

public sealed class AppealStorageOptions
{
    public string RootPath { get; set; } = "./data/appeals";
}

public sealed record StoredAppealEvidence(
    string StoredPath, string OriginalName, string MimeType, int SizeBytes, string Sha256);

public sealed partial class AppealStorage(
    IOptions<AppealStorageOptions> options,
    ILogger<AppealStorage> logger)
{
    private const long MaxBytes = 10 * 1024 * 1024;
    private readonly string _root = Path.GetFullPath(options.Value.RootPath);

    public async Task<StoredAppealEvidence> SaveAsync(
        Guid appealId, IFormFile file, CancellationToken ct = default)
    {
        await using var input = file.OpenReadStream();
        using var buffer = new MemoryStream();
        await input.CopyToAsync(buffer, ct);
        var bytes = buffer.ToArray();
        if (bytes.Length == 0 || bytes.Length > MaxBytes)
            throw new InvalidOperationException("Bằng chứng phải từ 1 byte đến 10 MB");
        var mime = DetectMime(bytes.AsSpan(0, Math.Min(bytes.Length, 8)));
        if (mime is null)
            throw new InvalidOperationException("Chỉ chấp nhận ảnh JPEG/PNG hoặc PDF");

        var ext = mime switch { "image/jpeg" => ".jpg", "image/png" => ".png", _ => ".pdf" };
        var dir = Path.Combine(_root, appealId.ToString("N"));
        Directory.CreateDirectory(dir);
        var name = $"{Guid.NewGuid():N}{ext}";
        var full = Path.Combine(dir, name);
        await File.WriteAllBytesAsync(full, bytes, ct);
        var hash = SHA256.HashData(bytes);
        var original = Regex.Replace(Path.GetFileName(file.FileName), @"[^\w\.\- ]", "_");
        if (string.IsNullOrWhiteSpace(original)) original = "evidence" + ext;
        logger.LogInformation("Stored appeal evidence for {AppealId} ({Bytes} bytes)", appealId, bytes.Length);
        return new StoredAppealEvidence(
            Path.Combine(appealId.ToString("N"), name).Replace('\\', '/'),
            original, mime, bytes.Length, Convert.ToHexString(hash).ToLowerInvariant());
    }

    public string? Resolve(string storedPath)
    {
        var full = Path.GetFullPath(Path.Combine(_root, storedPath));
        var prefix = _root.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        return full.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) ? full : null;
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
