namespace Sharee.Api.Infrastructure;

public sealed class JwtOptions
{
    public string Key { get; set; } = "";
    public string Issuer { get; set; } = "sharee";
    public string Audience { get; set; } = "sharee-app";
    public int ExpiryMinutes { get; set; } = 60;
    public int RefreshDays { get; set; } = 30;
    public int ExpiryDays { get; set; } = 0;
}
