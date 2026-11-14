using System.Net;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Dapper;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Services;

public sealed class PushService(
    Db db,
    IHttpClientFactory httpFactory,
    PushOptions options,
    ILogger<PushService> logger)
{
    private string? _fcmToken;
    private DateTimeOffset _fcmTokenExpires = DateTimeOffset.MinValue;
    private string? _apnsToken;
    private DateTimeOffset _apnsTokenExpires = DateTimeOffset.MinValue;

    public async Task SendAsync(Guid userId, string title, string body, object? data = null, CancellationToken ct = default)
    {
        if (!options.Enabled) return;
        await using var conn = await db.OpenAsync(ct);
        var tokens = (await conn.QueryAsync<dynamic>("""
            select token, platform from device_tokens where user_id = @userId
            """, new { userId })).ToList();
        if (tokens.Count == 0) return;

        foreach (var row in tokens)
        {
            var token = (string)row.token;
            var platform = (string)row.platform;
            try
            {
                var delivered = platform == "ios" && options.Apns.Enabled
                    ? await SendApnsAsync(token, title, body, data, ct)
                    : options.Fcm.Enabled
                        ? await SendFcmAsync(token, title, body, data, ct)
                        : false;
                if (!delivered)
                    await conn.ExecuteAsync("delete from device_tokens where token = @token", new { token });
            }
            catch (Exception ex)
            {
                logger.LogWarning("Push to {Platform} failed: {Message}", platform, ex.Message);
            }
        }
    }

    private async Task<bool> SendFcmAsync(string token, string title, string body, object? data, CancellationToken ct)
    {
        if (!options.Fcm.Enabled) return false;
        var accessToken = await GetFcmAccessTokenAsync(ct);
        var payload = new
        {
            message = new
            {
                token,
                notification = new { title, body },
                data = ToData(data),
                android = new { priority = "high" },
                apns = new { headers = new { apns_priority = "10" }, payload = new { aps = new { sound = "default" } } }
            }
        };
        var request = new HttpRequestMessage(HttpMethod.Post,
            $"https://fcm.googleapis.com/v1/projects/{options.Fcm.ProjectId}/messages:send");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        request.Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");
        using var response = await httpFactory.CreateClient("push").SendAsync(request, ct);
        if (response.IsSuccessStatusCode) return true;

        var error = await response.Content.ReadAsStringAsync(ct);
        if (response.StatusCode == HttpStatusCode.NotFound ||
            error.Contains("UNREGISTERED", StringComparison.OrdinalIgnoreCase))
            return false;
        throw new InvalidOperationException($"FCM {(int)response.StatusCode}: {error}");
    }

    private async Task<string> GetFcmAccessTokenAsync(CancellationToken ct)
    {
        if (_fcmToken is not null && _fcmTokenExpires > DateTimeOffset.UtcNow.AddMinutes(5))
            return _fcmToken;

        var json = options.Fcm.ServiceAccountJson.Trim();
        if (!json.StartsWith('{'))
        {
            if (!File.Exists(json)) throw new InvalidOperationException("FCM service account file not found");
            json = await File.ReadAllTextAsync(json, ct);
        }
        using var doc = JsonDocument.Parse(json);
        var account = doc.RootElement;
        var email = account.GetProperty("client_email").GetString()
            ?? throw new InvalidOperationException("FCM client_email missing");
        var privateKey = account.GetProperty("private_key").GetString()
            ?? throw new InvalidOperationException("FCM private_key missing");
        var tokenUri = account.TryGetProperty("token_uri", out var uriEl)
            ? uriEl.GetString() ?? "https://oauth2.googleapis.com/token"
            : "https://oauth2.googleapis.com/token";

        var now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var header = Base64Url(JsonSerializer.SerializeToUtf8Bytes(new { alg = "RS256", typ = "JWT" }));
        var claims = Base64Url(JsonSerializer.SerializeToUtf8Bytes(new
        {
            iss = email,
            scope = "https://www.googleapis.com/auth/firebase.messaging",
            aud = tokenUri,
            iat = now,
            exp = now + 3600
        }));
        using var rsa = RSA.Create();
        rsa.ImportFromPem(privateKey);
        var signature = Base64Url(rsa.SignData(Encoding.ASCII.GetBytes($"{header}.{claims}"),
            HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1));
        var assertion = $"{header}.{claims}.{signature}";

        var request = new HttpRequestMessage(HttpMethod.Post, tokenUri)
        {
            Content = new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["grant_type"] = "urn:ietf:params:oauth:grant-type:jwt-bearer",
                ["assertion"] = assertion
            })
        };
        using var response = await httpFactory.CreateClient("push").SendAsync(request, ct);
        var body = await response.Content.ReadAsStringAsync(ct);
        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException($"FCM OAuth {(int)response.StatusCode}: {body}");
        using var tokenDoc = JsonDocument.Parse(body);
        _fcmToken = tokenDoc.RootElement.GetProperty("access_token").GetString();
        _fcmTokenExpires = DateTimeOffset.UtcNow.AddSeconds(
            tokenDoc.RootElement.TryGetProperty("expires_in", out var exp) ? exp.GetInt32() : 3600);
        return _fcmToken!;
    }

    private async Task<bool> SendApnsAsync(string token, string title, string body, object? data, CancellationToken ct)
    {
        var key = options.Apns.PrivateKey;
        if (string.IsNullOrWhiteSpace(key) && File.Exists(options.Apns.PrivateKeyPath))
            key = await File.ReadAllTextAsync(options.Apns.PrivateKeyPath, ct);
        if (string.IsNullOrWhiteSpace(key))
            throw new InvalidOperationException("APNs private key missing");

        var jwt = GetApnsToken(key);
        var host = options.Apns.UseSandbox ? "https://api.sandbox.push.apple.com" : "https://api.push.apple.com";
        var payload = new
        {
            aps = new
            {
                alert = new { title, body },
                sound = "default",
                content_available = 1
            },
            data = ToData(data)
        };
        var request = new HttpRequestMessage(HttpMethod.Post, $"{host}/3/device/{token}")
        {
            Version = HttpVersion.Version20,
            VersionPolicy = HttpVersionPolicy.RequestVersionExact,
            Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json")
        };
        request.Headers.Add("authorization", $"bearer {jwt}");
        request.Headers.Add("apns-topic", options.Apns.BundleId);
        request.Headers.Add("apns-push-type", "alert");
        request.Headers.Add("apns-priority", "10");

        using var response = await httpFactory.CreateClient("push").SendAsync(request, ct);
        if (response.IsSuccessStatusCode) return true;
        var error = await response.Content.ReadAsStringAsync(ct);
        if (response.StatusCode == HttpStatusCode.Gone || response.StatusCode == HttpStatusCode.BadRequest)
            return false;
        throw new InvalidOperationException($"APNs {(int)response.StatusCode}: {error}");
    }

    private string GetApnsToken(string privateKey)
    {
        if (_apnsToken is not null && _apnsTokenExpires > DateTimeOffset.UtcNow.AddMinutes(5))
            return _apnsToken;
        var now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var header = Base64Url(JsonSerializer.SerializeToUtf8Bytes(new
        {
            alg = "ES256",
            kid = options.Apns.KeyId
        }));
        var claims = Base64Url(JsonSerializer.SerializeToUtf8Bytes(new
        {
            iss = options.Apns.TeamId,
            iat = now
        }));
        using var ecdsa = ECDsa.Create();
        ecdsa.ImportFromPem(privateKey.Replace("\\n", "\n"));
        var signature = Base64Url(ecdsa.SignData(Encoding.ASCII.GetBytes($"{header}.{claims}"),
            HashAlgorithmName.SHA256, DSASignatureFormat.IeeeP1363FixedFieldConcatenation));
        _apnsToken = $"{header}.{claims}.{signature}";
        _apnsTokenExpires = DateTimeOffset.UtcNow.AddMinutes(50);
        return _apnsToken;
    }

    private static Dictionary<string, string> ToData(object? data)
    {
        var result = new Dictionary<string, string>();
        if (data is null) return result;
        using var doc = JsonDocument.Parse(JsonSerializer.Serialize(data));
        foreach (var prop in doc.RootElement.EnumerateObject())
        {
            result[prop.Name] = prop.Value.ValueKind == JsonValueKind.String
                ? prop.Value.GetString() ?? ""
                : prop.Value.GetRawText();
        }
        return result;
    }

    private static string Base64Url(byte[] value) =>
        Convert.ToBase64String(value).TrimEnd('=').Replace('+', '-').Replace('/', '_');
}
