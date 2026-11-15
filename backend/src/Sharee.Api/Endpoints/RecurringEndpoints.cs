using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Api.Endpoints;

public static class RecurringEndpoints
{
    public static IEndpointRouteBuilder MapRecurringEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/trips/recurring").RequireAuthorization().WithTags("Recurring");

        group.MapGet("", async (HttpContext http, RecurringTripService service, CancellationToken ct) =>
            Results.Ok(await service.ListAsync(http.User.GetUserId(), ct)));

        group.MapPost("", async (
            CreateRecurringTripRequest request, HttpContext http, RecurringTripService service,
            Db db, CancellationToken ct) =>
        {
            var userId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            if (!await DriverVerification.IsApprovedAsync(conn, userId, ct))
                return Results.Json(new
                {
                    error = "Tài xế chưa được xác thực. Vui lòng hoàn tất xác thực trước khi tạo chuyến định kỳ.",
                    verificationRequired = true
                }, statusCode: StatusCodes.Status403Forbidden);
            try
            {
                var dto = await service.CreateAsync(userId, request, ct);
                return Results.Created($"/api/trips/recurring/{dto.Id}", dto);
            }
            catch (ArgumentException ex)
            {
                return Results.BadRequest(new { error = ex.Message });
            }
        });

        group.MapDelete("/{id:guid}", async (
            Guid id, HttpContext http, RecurringTripService service, CancellationToken ct) =>
        {
            var ok = await service.DeactivateAsync(id, http.User.GetUserId(), ct);
            return ok ? Results.Ok(new { status = "paused" }) : Results.NotFound();
        });

        return app;
    }
}
