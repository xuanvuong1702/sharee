using Dapper;
using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Endpoints;

public static class NotificationEndpoints
{
    public static IEndpointRouteBuilder MapNotificationEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/notifications").RequireAuthorization().WithTags("Notifications");

        group.MapGet("", async (HttpContext http, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var rows = await conn.QueryAsync<dynamic>("""
                select id, type, title, body, created_at, read_at
                from notifications
                where user_id = @userId
                order by created_at desc
                limit 50
                """, new { userId = http.User.GetUserId() });
            return Results.Ok(rows.Select(r => new NotificationDto(
                (Guid)r.id, (string)r.type, (string)r.title, (string)r.body,
                Infrastructure.Time.ToDto((DateTime)r.created_at),
                r.read_at is null ? null : Infrastructure.Time.ToDto((DateTime)r.read_at))));
        });

        group.MapGet("/unread-count", async (HttpContext http, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var count = await conn.ExecuteScalarAsync<int>(
                "select count(*) from notifications where user_id = @userId and read_at is null",
                new { userId = http.User.GetUserId() });
            return Results.Ok(new { count });
        });

        group.MapPost("/read-all", async (HttpContext http, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            await conn.ExecuteAsync(
                "update notifications set read_at = now() where user_id = @userId and read_at is null",
                new { userId = http.User.GetUserId() });
            return Results.Ok(new { status = "ok" });
        });

        return app;
    }
}
