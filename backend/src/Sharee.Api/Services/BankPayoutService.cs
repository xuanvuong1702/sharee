using System.Net.Http.Json;
using System.Text.Json;

namespace Sharee.Api.Services;

public sealed class BankPayoutOptions
{
    public bool Enabled { get; set; }
    public string BaseUrl { get; set; } = "";
    public string Path { get; set; } = "/payouts";
    public string ApiKey { get; set; } = "";
}

public sealed record BankPayoutResult(bool Ok, string? ProviderRef, string? Error);

/// <summary>Adapter for a bank/payout provider. Disabled in demo; when enabled
/// an admin cannot mark a withdrawal paid until the provider accepts it.</summary>
public sealed class BankPayoutService(
    IHttpClientFactory http, BankPayoutOptions options, ILogger<BankPayoutService> log)
{
    public bool Enabled => options.Enabled;

    public async Task<BankPayoutResult> TransferAsync(
        Guid withdrawalId, int amount, string bankName, string accountNumber,
        string accountName, CancellationToken ct = default)
    {
        if (!options.Enabled)
            return new BankPayoutResult(false, null, "Bank payout provider chưa được cấu hình");
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Post,
                $"{options.BaseUrl.TrimEnd('/')}{options.Path}");
            if (!string.IsNullOrWhiteSpace(options.ApiKey))
                request.Headers.Add("Authorization", $"Bearer {options.ApiKey}");
            request.Content = JsonContent.Create(new
            {
                reference = withdrawalId,
                amount,
                bankName,
                accountNumber,
                accountName
            });
            using var response = await http.CreateClient("bankpayout").SendAsync(request, ct);
            var body = await response.Content.ReadAsStringAsync(ct);
            if (!response.IsSuccessStatusCode)
                return new BankPayoutResult(false, null,
                    $"Bank payout HTTP {(int)response.StatusCode}: {body[..Math.Min(300, body.Length)]}");
            try
            {
                using var doc = JsonDocument.Parse(body);
                var reference = doc.RootElement.TryGetProperty("reference", out var r)
                    ? r.GetString()
                    : doc.RootElement.TryGetProperty("transactionId", out var t) ? t.GetString() : null;
                return new BankPayoutResult(true, reference, null);
            }
            catch (JsonException)
            {
                return new BankPayoutResult(false, null, "Phản hồi bank payout không hợp lệ");
            }
        }
        catch (Exception ex)
        {
            log.LogWarning(ex, "Bank payout failed for {WithdrawalId}", withdrawalId);
            return new BankPayoutResult(false, null, ex.Message);
        }
    }
}
