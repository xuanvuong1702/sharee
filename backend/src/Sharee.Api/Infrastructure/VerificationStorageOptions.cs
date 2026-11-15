namespace Sharee.Api.Infrastructure;

public sealed class VerificationStorageOptions
{
    public string RootPath { get; set; } = "./data/verifications";
}

public sealed record StoredVerificationFile(
    string StoredPath, string OriginalName, string MimeType, int SizeBytes, string Sha256);
