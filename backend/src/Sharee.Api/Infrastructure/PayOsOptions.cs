namespace Sharee.Api.Infrastructure;

public sealed class PayOsOptions
{
    public string BaseUrl { get; set; } = "https://api-merchant.payos.vn";
    public string ClientId { get; set; } = "";
    public string ApiKey { get; set; } = "";
    public string ChecksumKey { get; set; } = "";
    public string ReturnUrl { get; set; } = "https://app.sharee.vn/payment/return";
    public string CancelUrl { get; set; } = "https://app.sharee.vn/payment/cancel";
    public bool Enabled { get; set; }
}
