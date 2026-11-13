using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Api.Endpoints;

public static class TrackingEndpoints
{
    public static IEndpointRouteBuilder MapTrackingEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/trips/{id:guid}/tracking", async (
            Guid id, HttpContext http, TrackingService service, CancellationToken ct) =>
        {
            var tracking = await service.GetAsync(id, http.User.GetUserId(), ct);
            return tracking is null ? Results.NotFound() : Results.Ok(tracking);
        }).RequireAuthorization().WithTags("Tracking");

        app.MapPost("/api/trips/{id:guid}/location", async (
            Guid id, LocationUpdateRequest request, HttpContext http,
            TrackingService service, CancellationToken ct) =>
        {
            try
            {
                var tracking = await service.UpdateLocationAsync(id, http.User.GetUserId(), request, ct);
                return tracking is null ? Results.NotFound() : Results.Ok(tracking);
            }
            catch (ArgumentException ex)
            {
                return Results.BadRequest(new { error = ex.Message });
            }
        }).RequireAuthorization().WithTags("Tracking");

        app.MapPost("/api/trips/{id:guid}/tracking/status", async (
            Guid id, TrackingStatusRequest request, HttpContext http,
            TrackingService service, CancellationToken ct) =>
        {
            try
            {
                var tracking = await service.SetStatusAsync(id, http.User.GetUserId(), request.Status, ct);
                return tracking is null
                    ? Results.Json(new { error = "Chỉ tài xế mới cập nhật được trạng thái" },
                        statusCode: StatusCodes.Status403Forbidden)
                    : Results.Ok(tracking);
            }
            catch (ArgumentException ex)
            {
                return Results.BadRequest(new { error = ex.Message });
            }
        }).RequireAuthorization().WithTags("Tracking");

        return app;
    }
}
