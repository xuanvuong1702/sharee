using Dapper;
using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Api.Endpoints;

public static class ReportEndpoints
{
    public static IEndpointRouteBuilder MapReportEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/reports", async (
            CreateReportRequest request, HttpContext http, Db db, CancellationToken ct) =>
        {
            if (request.TargetType is not ("user" or "trip" or "booking"))
                return Results.BadRequest(new { error = "Loại đối tượng không hợp lệ" });
            if (string.IsNullOrWhiteSpace(request.Reason))
                return Results.BadRequest(new { error = "Thiếu lý do" });

            await using var conn = await db.OpenAsync(ct);
            var id = await conn.ExecuteScalarAsync<Guid>("""
                insert into reports (reporter_id, target_type, target_id, reason, description)
                values (@reporterId, @targetType, @targetId, @reason, @description)
                returning id
                """, new
            {
                reporterId = http.User.GetUserId(),
                targetType = request.TargetType,
                targetId = request.TargetId,
                reason = request.Reason,
                description = request.Description
            });
            return Results.Created($"/api/reports/{id}", new { id, status = "open" });
        }).RequireAuthorization().WithTags("Reports");

        return app;
    }
}
