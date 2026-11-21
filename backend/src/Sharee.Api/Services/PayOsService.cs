using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Dapper;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Services;

public sealed record PayOsCheckout(
    long OrderCode, int Amount, string Description, string CheckoutUrl,
    string QrCode, string PaymentLinkId, DateTimeOffset ExpiresAt);

public sealed record PayOsWebhook(
    string Code, string Description, long OrderCode, int Amount,
    string? Reference, string? TransactionDateTime);

public sealed class PayOsService(
    Db db,
    IHttpClientFactory httpFactory,
    PayOsOptions options,
    ILogger<PayOsService> logger)
{
    public bool Enabled => options.Enabled
        && !string.IsNullOrWhiteSpace(options.ClientId)
        && !string.IsNullOrWhiteSpace(options.ApiKey)
        && !string.IsNullOrWhiteSpace(options.ChecksumKey);

    public async Task<PayOsCheckout> CreateAsync(Guid bookingId, Guid userId, CancellationToken ct = default)
    {
        if (!Enabled) throw new InvalidOperationException("PayOS chưa được cấu hình");

        await using var conn = await db.OpenAsync(ct);
        var booking = await conn.QuerySingleOrDefaultAsync<dynamic>("""
            select b.id, b.passenger_id, b.status, b.price_total, b.seats, b.expires_at,
                   u.full_name, u.phone,
                   t.origin_label, t.destination_label
            from bookings b
            join users u on u.id = b.passenger_id
            join trips t on t.id = b.trip_id
            where b.id = @bookingId
            """, new { bookingId });
        if (booking is null) throw new InvalidOperationException("Không tìm thấy booking");
        if ((Guid)booking.passenger_id != userId)
            throw new UnauthorizedAccessException("Booking không thuộc người dùng");
        if ((string)booking.status == "confirmed")
            throw new InvalidOperationException("Booking đã được thanh toán");
        if ((string)booking.status != "pending_payment")
            throw new InvalidOperationException("Booking không ở trạng thái chờ thanh toán");

        var existing = await conn.QuerySingleOrDefaultAsync<dynamic>("""
            select status, provider, provider_ref, amount, metadata
            from payments where booking_id = @bookingId
            """, new { bookingId });
        if (existing is not null && (string)existing.status == "succeeded")
            throw new InvalidOperationException("Booking đã được thanh toán");
        if (existing is not null && (string)existing.status == "requires_capture"
            && (string)existing.provider == "payos")
        {
            var cached = await GetCachedCheckoutAsync(
                (string?)existing.provider_ref, (int)existing.amount, (string?)existing.metadata);
            if (cached is not null) return cached;
        }

        var amount = (int)booking.price_total;
        var orderCode = long.Parse(
            $"{DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}{Random.Shared.Next(10, 99)}",
            CultureInfo.InvariantCulture);
        var description = "Sharee " + bookingId.ToString("N")[..8];
        // The payment link must never outlive the seat hold. Otherwise a
        // customer can pay after expiry and the seat may already be resold.
        var bookingExpiry = booking.expires_at is null
            ? DateTimeOffset.UtcNow.AddMinutes(10)
            : Time.ToDto((DateTime)booking.expires_at);
        var expiresAt = bookingExpiry < DateTimeOffset.UtcNow.AddMinutes(15)
            ? bookingExpiry
            : DateTimeOffset.UtcNow.AddMinutes(15);
        if (expiresAt <= DateTimeOffset.UtcNow)
            throw new InvalidOperationException("Booking đã hết hạn thanh toán");

        var signature = SignCreate(amount, options.CancelUrl, description, orderCode, options.ReturnUrl);
        var payload = new Dictionary<string, object?>
        {
            ["orderCode"] = orderCode,
            ["amount"] = amount,
            ["description"] = description,
            ["buyerName"] = (string)booking.full_name,
            ["buyerPhone"] = (string)booking.phone,
            ["items"] = new[] { new { name = description, quantity = 1, price = amount } },
            ["returnUrl"] = options.ReturnUrl,
            ["cancelUrl"] = options.CancelUrl,
            ["expiredAt"] = expiresAt.ToUnixTimeSeconds(),
            ["signature"] = signature
        };

        await using var tx = await conn.BeginTransactionAsync(ct);
        await conn.ExecuteAsync("""
            insert into payments (booking_id, provider, provider_ref, amount, status, metadata)
            values (@bookingId, 'payos', @orderCode, @amount, 'requires_capture', '{}'::jsonb)
            on conflict (booking_id) do update set
                provider = 'payos', provider_ref = @orderCode, amount = @amount,
                status = 'requires_capture', metadata = '{}'::jsonb
            """, new { bookingId, orderCode = orderCode.ToString(CultureInfo.InvariantCulture), amount }, tx);
        await tx.CommitAsync(ct);

        using var request = new HttpRequestMessage(HttpMethod.Post,
            $"{options.BaseUrl.TrimEnd('/')}/v2/payment-requests");
        request.Headers.Add("x-client-id", options.ClientId);
        request.Headers.Add("x-api-key", options.ApiKey);
        request.Content = new StringContent(
            JsonSerializer.Serialize(payload, new JsonSerializerOptions(JsonSerializerDefaults.Web)),
            Encoding.UTF8, "application/json");

        var client = httpFactory.CreateClient("payos");
        using var response = await client.SendAsync(request, ct);
        var body = await response.Content.ReadAsStringAsync(ct);
        if (!response.IsSuccessStatusCode)
        {
            logger.LogError("PayOS create failed ({Status}): {Body}", (int)response.StatusCode, body);
            await MarkFailedAsync(conn, bookingId, body);
            throw new InvalidOperationException("Không tạo được link thanh toán PayOS");
        }

        using var doc = JsonDocument.Parse(body);
        var root = doc.RootElement;
        var code = root.TryGetProperty("code", out var codeEl) ? codeEl.GetString() : null;
        if (code != "00" || !root.TryGetProperty("data", out var data))
        {
            logger.LogWarning("PayOS rejected request: {Body}", body);
            await MarkFailedAsync(conn, bookingId, body);
            throw new InvalidOperationException(
                root.TryGetProperty("desc", out var desc) ? desc.GetString() ?? "PayOS error" : "PayOS error");
        }

        var checkoutUrl = data.TryGetProperty("checkoutUrl", out var checkoutEl)
            ? checkoutEl.GetString() ?? "" : "";
        if (string.IsNullOrWhiteSpace(checkoutUrl))
        {
            await MarkFailedAsync(conn, bookingId, body);
            throw new InvalidOperationException("PayOS không trả về checkoutUrl");
        }
        var qrCode = data.TryGetProperty("qrCode", out var qr) ? qr.GetString() ?? "" : "";
        var linkId = data.TryGetProperty("paymentLinkId", out var pl) ? pl.GetString() ?? "" : "";
        await conn.ExecuteAsync("""
            update payments set payment_link_id = @linkId, metadata = @metadata::jsonb
            where booking_id = @bookingId
            """, new
        {
            bookingId,
            linkId,
            metadata = JsonSerializer.Serialize(new { checkoutUrl, qrCode, paymentLinkId = linkId })
        });

        return new PayOsCheckout(orderCode, amount, description, checkoutUrl, qrCode, linkId, expiresAt);
    }

    private static Task<PayOsCheckout?> GetCachedCheckoutAsync(
        string? providerRef, int amount, string? metadata)
    {
        if (string.IsNullOrWhiteSpace(metadata)) return Task.FromResult<PayOsCheckout?>(null);
        try
        {
            using var doc = JsonDocument.Parse(metadata);
            var root = doc.RootElement;
            if (!root.TryGetProperty("checkoutUrl", out var url))
                return Task.FromResult<PayOsCheckout?>(null);
            var checkout = url.GetString();
            var qr = root.TryGetProperty("qrCode", out var q) ? q.GetString() ?? "" : "";
            var link = root.TryGetProperty("paymentLinkId", out var l) ? l.GetString() ?? "" : "";
            if (string.IsNullOrWhiteSpace(checkout)) return Task.FromResult<PayOsCheckout?>(null);
            var orderCode = long.TryParse(providerRef, out var parsed) ? parsed : 0;
            return Task.FromResult<PayOsCheckout?>(new PayOsCheckout(
                orderCode, amount, "Sharee", checkout, qr, link,
                DateTimeOffset.UtcNow.AddMinutes(10)));
        }
        catch
        {
            return Task.FromResult<PayOsCheckout?>(null);
        }
    }

    private static Task MarkFailedAsync(Npgsql.NpgsqlConnection conn, Guid bookingId, string body)
        => conn.ExecuteAsync("""
            update payments set status = 'failed', metadata = @meta::jsonb
            where booking_id = @bookingId and status = 'requires_capture'
            """, new { bookingId, meta = JsonSerializer.Serialize(new { error = body }) });

    public PayOsWebhook? VerifyWebhook(string body)
    {
        try
        {
            using var doc = JsonDocument.Parse(body);
            var root = doc.RootElement;
            if (!root.TryGetProperty("signature", out var sigEl)
                || !root.TryGetProperty("data", out var data)) return null;

            var signature = sigEl.GetString() ?? "";
            var canonical = CanonicalData(data);
            var expected = Hmac(canonical);
            if (!CryptographicOperations.FixedTimeEquals(
                    Encoding.UTF8.GetBytes(signature.ToLowerInvariant()),
                    Encoding.UTF8.GetBytes(expected.ToLowerInvariant())))
                return null;

            var orderCode = data.GetProperty("orderCode").GetInt64();
            var amount = data.GetProperty("amount").GetInt32();
            var code = data.TryGetProperty("code", out var c) ? c.GetString() ?? "" : "00";
            var desc = data.TryGetProperty("desc", out var d) ? d.GetString() ?? "" : "";
            var reference = data.TryGetProperty("reference", out var r) ? r.GetString() : null;
            var txTime = data.TryGetProperty("transactionDateTime", out var t) ? t.GetString() : null;
            return new PayOsWebhook(code, desc, orderCode, amount, reference, txTime);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Invalid PayOS webhook payload");
            return null;
        }
    }

    private static string CanonicalData(JsonElement data)
    {
        var values = new List<string>();
        foreach (var prop in data.EnumerateObject().OrderBy(p => p.Name, StringComparer.Ordinal))
        {
            if (prop.Value.ValueKind == JsonValueKind.Null) continue;
            var value = prop.Value.ValueKind == JsonValueKind.String
                ? prop.Value.GetString()
                : prop.Value.GetRawText();
            values.Add($"{prop.Name}={value}");
        }
        return string.Join("&", values);
    }

    private string SignCreate(int amount, string cancelUrl, string description, long orderCode, string returnUrl)
        => Hmac($"amount={amount}&cancelUrl={cancelUrl}&description={description}&orderCode={orderCode}&returnUrl={returnUrl}");

    private string Hmac(string value)
    {
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(options.ChecksumKey));
        return Convert.ToHexString(hmac.ComputeHash(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();
    }
}
