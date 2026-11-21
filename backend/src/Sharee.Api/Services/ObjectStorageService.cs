using Amazon.Runtime;
using Amazon.S3;
using Amazon.S3.Model;
using Microsoft.Extensions.Options;

namespace Sharee.Api.Services;

public sealed class ObjectStorageOptions
{
    public bool Enabled { get; set; }
    public string Endpoint { get; set; } = "";
    public string Bucket { get; set; } = "sharee";
    public string AccessKey { get; set; } = "";
    public string SecretKey { get; set; } = "";
    public bool UseSsl { get; set; }
    public string LocalRoot { get; set; } = "./data/objects";
}

/// <summary>Object storage for sensitive files (KYC, appeal evidence).
/// S3/MinIO is primary; a local directory is kept as an explicit fallback so
/// a storage outage never loses an upload. Keys are opaque relative paths.</summary>
public sealed class ObjectStorageService(
    IOptions<ObjectStorageOptions> options,
    ILogger<ObjectStorageService> logger)
{
    private readonly ObjectStorageOptions _options = options.Value;
    private readonly string _localRoot = Path.GetFullPath(options.Value.LocalRoot);
    private readonly IAmazonS3? _s3 = BuildClient(options.Value);

    public bool Enabled => _s3 is not null;

    public async Task SaveAsync(string key, byte[] bytes, string contentType, CancellationToken ct = default)
    {
        var local = ResolveLocal(key);
        Directory.CreateDirectory(Path.GetDirectoryName(local)!);
        await File.WriteAllBytesAsync(local, bytes, ct);
        if (_s3 is null) return;
        try
        {
            await _s3.PutObjectAsync(new PutObjectRequest
            {
                BucketName = _options.Bucket,
                Key = key,
                InputStream = new MemoryStream(bytes),
                ContentType = contentType,
                DisablePayloadSigning = true
            }, ct);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "S3 upload failed for {Key}; local fallback kept", key);
        }
    }

    public async Task<Stream?> OpenReadAsync(string key, CancellationToken ct = default)
    {
        var local = ResolveLocal(key);
        if (File.Exists(local)) return File.OpenRead(local);
        if (_s3 is null) return null;
        try
        {
            using var response = await _s3.GetObjectAsync(_options.Bucket, key, ct);
            var buffer = new MemoryStream();
            await response.ResponseStream.CopyToAsync(buffer, ct);
            buffer.Position = 0;
            return buffer;
        }
        catch (AmazonS3Exception ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "S3 download failed for {Key}", key);
            return null;
        }
    }

    public async Task DeleteAsync(string? key, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(key)) return;
        var local = ResolveLocal(key);
        if (File.Exists(local))
        {
            try { File.Delete(local); }
            catch (Exception ex) { logger.LogWarning(ex, "Could not delete local object {Key}", key); }
        }
        if (_s3 is null) return;
        try
        {
            await _s3.DeleteObjectAsync(_options.Bucket, key, ct);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "S3 delete failed for {Key}", key);
        }
    }

    public string ResolveLocal(string key)
    {
        var full = Path.GetFullPath(Path.Combine(_localRoot, key));
        var prefix = _localRoot.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        if (!full.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Object key không hợp lệ");
        return full;
    }

    private static IAmazonS3? BuildClient(ObjectStorageOptions options)
    {
        if (!options.Enabled || string.IsNullOrWhiteSpace(options.Endpoint)
            || string.IsNullOrWhiteSpace(options.AccessKey)) return null;
        var config = new AmazonS3Config
        {
            ServiceURL = options.Endpoint,
            ForcePathStyle = true,
            UseHttp = !options.UseSsl,
            Timeout = TimeSpan.FromSeconds(15)
        };
        return new AmazonS3Client(
            new BasicAWSCredentials(options.AccessKey, options.SecretKey), config);
    }
}
