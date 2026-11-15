using System.Text;
using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Api.Endpoints;

public static class PayOsEndpoints
{
    public static IEndpointRouteBuilder MapPayOsEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/payments/config", (PayOsOptions options, IConfiguration config) =>
        {
            var enabled = options.Enabled
                && !string.IsNullOrWhiteSpace(options.ClientId)
                && !string.IsNullOrWhiteSpace(options.ApiKey)
                && !string.IsNullOrWhiteSpace(options.ChecksumKey);
            return Results.Ok(new
            {
                provider = enabled ? "payos" : "mock",
                enabled,
                checkout = enabled ? "payos" : "mock",
                methods = new[]
                {
                    new { id = "bank", label = "Chuyển khoản ngân hàng", escrow = true },
                    new { id = "wallet", label = "Ví điện tử (qua PayOS)", escrow = true },
                    new { id = "cash", label = "Tiền mặt khi lên xe", escrow = false }
                }
            });
        }).WithTags("Payments");

        app.MapPost("/api/bookings/{id:guid}/payos", async (
            Guid id, HttpContext http, PayOsService payos, CancellationToken ct) =>
        {
            try
            {
                var checkout = await payos.CreateAsync(id, http.User.GetUserId(), ct);
                return Results.Ok(checkout);
            }
            catch (UnauthorizedAccessException ex)
            {
                return Results.Json(new { error = ex.Message }, statusCode: 403);
            }
            catch (InvalidOperationException ex)
            {
                return Results.BadRequest(new { error = ex.Message });
            }
        }).RequireAuthorization().WithTags("Payments");

        app.MapPost("/api/payments/payos/webhook", async (
            HttpContext http, PayOsService payos, PaymentSettlementService settlement,
            ILoggerFactory loggerFactory, CancellationToken ct) =>
        {
            using var reader = new StreamReader(http.Request.Body, Encoding.UTF8);
            var body = await reader.ReadToEndAsync(ct);
            var webhook = payos.VerifyWebhook(body);
            if (webhook is null)
                return Results.BadRequest(new { error = "invalid signature" });

            var settled = await settlement.SettlePayOsAsync(webhook, ct);
            if (!settled)
            {
                loggerFactory.CreateLogger("PayOS").LogWarning(
                    "PayOS webhook could not be settled for order {OrderCode}", webhook.OrderCode);
            }
            return Results.Ok(new { success = true });
        }).WithTags("Payments");

        return app;
    }
}
