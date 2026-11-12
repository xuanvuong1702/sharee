using Dapper;
using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Api.Endpoints;

public static class UserEndpoints
{
    public static IEndpointRouteBuilder MapUserEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/me", async (HttpContext http, ReadService read, CancellationToken ct) =>
        {
            var user = await read.GetUserAsync(http.User.GetUserId(), ct);
            return user is null ? Results.NotFound() : Results.Ok(user);
        }).RequireAuthorization().WithTags("Me");

        app.MapPatch("/api/me", async (
            UpdateProfileRequest request, HttpContext http, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var row = await conn.QuerySingleOrDefaultAsync<UserRow>("""
                update users set
                    full_name = coalesce(@fullName, full_name),
                    email = coalesce(@email, email),
                    bio = coalesce(@bio, bio),
                    avatar_url = coalesce(@avatarUrl, avatar_url)
                where id = @id
                returning *
                """, new
            {
                id = http.User.GetUserId(),
                fullName = request.FullName,
                email = request.Email,
                bio = request.Bio,
                avatarUrl = request.AvatarUrl
            });
            return row is null ? Results.NotFound() : Results.Ok(row.ToUser());
        }).RequireAuthorization().WithTags("Me");

        app.MapGet("/api/users/{id:guid}", async (
            Guid id, ReadService read, Db db, CancellationToken ct) =>
        {
            var user = await read.GetUserAsync(id, ct);
            if (user is null) return Results.NotFound();

            await using var conn = await db.OpenAsync(ct);
            var completed = await conn.ExecuteScalarAsync<int>("""
                select count(*) from bookings b
                join trips t on t.id = b.trip_id
                where b.status = 'completed' and (b.passenger_id = @id or t.driver_id = @id)
                """, new { id });
            var reviews = await read.GetReviewsAsync(id, ct);
            return Results.Ok(new UserProfileDto(user, reviews, completed));
        }).WithTags("Users");

        app.MapGet("/api/users/{id:guid}/reviews", async (
            Guid id, ReadService read, CancellationToken ct) =>
            Results.Ok(await read.GetReviewsAsync(id, ct))).WithTags("Users");

        var vehicles = app.MapGroup("/api/vehicles").RequireAuthorization().WithTags("Vehicles");

        vehicles.MapGet("", async (HttpContext http, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var rows = await conn.QueryAsync<VehicleRow>(
                "select * from vehicles where owner_id = @ownerId and status = 'active' order by created_at",
                new { ownerId = http.User.GetUserId() });
            return Results.Ok(rows.Select(r => r.ToVehicle()));
        });

        vehicles.MapPost("", async (
            CreateVehicleRequest request, HttpContext http, Db db, CancellationToken ct) =>
        {
            if (request.Seats is < 2 or > 9 || string.IsNullOrWhiteSpace(request.Plate))
                return Results.BadRequest(new { error = "Thông tin xe không hợp lệ" });

            await using var conn = await db.OpenAsync(ct);
            var row = await conn.QuerySingleAsync<VehicleRow>("""
                insert into vehicles (owner_id, make, model, year, color, plate, seats)
                values (@ownerId, @make, @model, @year, @color, @plate, @seats)
                returning *
                """, new
            {
                ownerId = http.User.GetUserId(),
                make = request.Make,
                model = request.Model,
                year = request.Year,
                color = request.Color,
                plate = request.Plate,
                seats = request.Seats
            });
            return Results.Created($"/api/vehicles/{row.Id}", row.ToVehicle());
        });

        vehicles.MapPatch("/{id:guid}", async (
            Guid id, CreateVehicleRequest request, HttpContext http, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var row = await conn.QuerySingleOrDefaultAsync<VehicleRow>("""
                update vehicles set make = @make, model = @model, year = @year,
                       color = @color, plate = @plate, seats = @seats
                where id = @id and owner_id = @ownerId
                returning *
                """, new
            {
                id, ownerId = http.User.GetUserId(), make = request.Make, model = request.Model,
                year = request.Year, color = request.Color, plate = request.Plate, seats = request.Seats
            });
            return row is null ? Results.NotFound() : Results.Ok(row.ToVehicle());
        });

        return app;
    }
}
