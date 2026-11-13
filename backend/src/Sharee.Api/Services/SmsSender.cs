using System.Net.Http.Headers;
using System.Text;

namespace Sharee.Api.Services;

public interface ISmsSender
{
    Task SendAsync(string phone, string message, CancellationToken ct = default);
}

public sealed class DevSmsSender(ILogger<DevSmsSender> logger) : ISmsSender
{
    public Task SendAsync(string phone, string message, CancellationToken ct = default)
    {
        logger.LogInformation("DEV SMS to {Phone}: {Message}", phone, message);
        return Task.CompletedTask;
    }
}

public sealed class TwilioSmsSender(
    IHttpClientFactory httpFactory,
    IConfiguration config,
    ILogger<TwilioSmsSender> logger) : ISmsSender
{
    public async Task SendAsync(string phone, string message, CancellationToken ct = default)
    {
        var sid = config["Twilio:AccountSid"];
        var token = config["Twilio:AuthToken"];
        var from = config["Twilio:From"];
        if (string.IsNullOrWhiteSpace(sid) || string.IsNullOrWhiteSpace(token) || string.IsNullOrWhiteSpace(from))
            throw new InvalidOperationException("Twilio chưa được cấu hình đầy đủ");

        var client = httpFactory.CreateClient("twilio");
        var request = new HttpRequestMessage(HttpMethod.Post,
            $"https://api.twilio.com/2010-04-01/Accounts/{sid}/Messages.json");
        request.Headers.Authorization = new AuthenticationHeaderValue("Basic",
            Convert.ToBase64String(Encoding.UTF8.GetBytes($"{sid}:{token}")));
        request.Content = new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["To"] = phone,
            ["From"] = from,
            ["Body"] = message
        });

        using var response = await client.SendAsync(request, ct);
        if (!response.IsSuccessStatusCode)
        {
            var body = await response.Content.ReadAsStringAsync(ct);
            logger.LogError("Twilio SMS failed ({Status}): {Body}", (int)response.StatusCode, body);
            throw new InvalidOperationException("Không gửi được SMS xác thực");
        }
    }
}
