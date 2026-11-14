namespace Sharee.Api.Infrastructure;

public sealed class PushOptions
{
    public bool Enabled { get; set; }
    public FcmOptions Fcm { get; set; } = new();
    public ApnsOptions Apns { get; set; } = new();
}

public sealed class FcmOptions
{
    public string ProjectId { get; set; } = "";
    public string ServiceAccountJson { get; set; } = "";
    public bool Enabled => !string.IsNullOrWhiteSpace(ProjectId)
        && !string.IsNullOrWhiteSpace(ServiceAccountJson);
}

public sealed class ApnsOptions
{
    public bool Enabled { get; set; }
    public bool UseSandbox { get; set; }
    public string KeyId { get; set; } = "";
    public string TeamId { get; set; } = "";
    public string BundleId { get; set; } = "";
    public string PrivateKey { get; set; } = "";
    public string PrivateKeyPath { get; set; } = "";
}
