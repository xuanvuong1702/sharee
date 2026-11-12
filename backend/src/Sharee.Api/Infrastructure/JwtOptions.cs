namespace Sharee.Api.Infrastructure;

public sealed class JwtOptions
{
    public string Key { get; set; } = "";
    public string Issuer { get; set; } = "sharee";
    public string Audience { get; set; } = "sharee-app";
    public int ExpiryDays { get; set; } = 7;
}
