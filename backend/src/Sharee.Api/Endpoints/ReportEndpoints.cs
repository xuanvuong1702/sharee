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
            if (string.IsNullOrWhiteSpace(request.Reason) || request.Reason.Trim().Length > 200)
                return Results.BadRequest(new { error = "Lý do không hợp lệ" });
            if (request.Description is { Length: > 2000 })
                return Results.BadRequest(new { error = "Mô tả tối đa 2000 ký tự" });

            await using var conn = await db.OpenAsync(ct);
            var exists = await conn.ExecuteScalarAsync<bool>(request.TargetType switch
            {
                "user" => "select exists(select 1 from users where id = @id)",
                "trip" => "select exists(select 1 from trips where id = @id)",
                _ => "select exists(select 1 from bookings where id = @id)"
            }, new { id = request.TargetId });
            if (!exists) return Results.BadRequest(new { error = "Đối tượng báo cáo không tồn tại" });
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
