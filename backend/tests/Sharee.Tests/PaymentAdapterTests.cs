using System.Net;
using System.Text;
using Microsoft.Extensions.Logging.Abstractions;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Tests;

public class PaymentAdapterTests
{
    [Fact]
    public async Task PayOs_refund_posts_order_code_amount_and_signature()
    {
        HttpRequestMessage? captured = null;
        string? capturedBody = null;
        var handler = new FakeHandler(request =>
        {
            captured = request;
            capturedBody = request.Content?.ReadAsStringAsync().GetAwaiter().GetResult();
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("{\"reference\":\"RF-123\"}", Encoding.UTF8,
                    "application/json")
            };
        });
        var options = new PayOsOptions
        {
            Enabled = true, ClientId = "client", ApiKey = "key",
            ChecksumKey = "secret", BaseUrl = "https://payos.test"
        };
        var service = new PayOsService(null!, new Factory(handler), options,
            NullLogger<PayOsService>.Instance);

        var result = await service.RefundAsync("12345", 90_000, "hoàn tiền");

        Assert.True(result.Ok);
        Assert.Equal("RF-123", result.ProviderRef);
        Assert.NotNull(captured);
        Assert.Equal(HttpMethod.Post, captured!.Method);
        Assert.Contains("/v2/payment-requests/12345/refund", captured.RequestUri!.ToString());
        Assert.True(captured.Headers.TryGetValues("x-signature", out var signature));
        Assert.NotEmpty(signature!);
        var body = capturedBody;
        Assert.Contains("\"amount\":90000", body);
        Assert.Contains("\"reason\"", body);
    }

    [Fact]
    public async Task Bank_payout_sends_bank_details_and_returns_reference()
    {
        HttpRequestMessage? captured = null;
        string? capturedBody = null;
        var handler = new FakeHandler(request =>
        {
            captured = request;
            capturedBody = request.Content?.ReadAsStringAsync().GetAwaiter().GetResult();
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("{\"transactionId\":\"BANK-9\"}")
            };
        });
        var service = new BankPayoutService(new Factory(handler), new BankPayoutOptions
        {
            Enabled = true, BaseUrl = "https://bank.test", Path = "/v1/payouts", ApiKey = "token"
        }, NullLogger<BankPayoutService>.Instance);

        var result = await service.TransferAsync(Guid.NewGuid(), 50_000,
            "Vietcombank", "0123456789", "NGUYEN VAN A");

        Assert.True(result.Ok);
        Assert.Equal("BANK-9", result.ProviderRef);
        Assert.NotNull(captured);
        Assert.Equal("Bearer token", captured!.Headers.Authorization!.ToString());
        Assert.Contains("0123456789", capturedBody);
    }

    private sealed class Factory(HttpMessageHandler handler) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => new(handler, false);
    }

    private sealed class FakeHandler(
        Func<HttpRequestMessage, HttpResponseMessage> responder) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
            => Task.FromResult(responder(request));
    }
}
