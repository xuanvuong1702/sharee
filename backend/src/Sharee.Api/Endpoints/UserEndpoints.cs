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
            Guid id, HttpContext http, ReadService read, Db db, CancellationToken ct) =>
        {
            var user = await read.GetUserAsync(id, ct);
            if (user is null) return Results.NotFound();

            // Public profiles never expose phone/email; the owner sees their own data.
            if (http.User.GetUserId() != id)
                user = user with
                {
                    Phone = Privacy.MaskPhone(user.Phone),
                    Email = Privacy.MaskEmail(user.Email),
                    Bio = null
                };

            await using var conn = await db.OpenAsync(ct);
            var completed = await conn.ExecuteScalarAsync<int>("""
                select count(*) from bookings b
                join trips t on t.id = b.trip_id
                where b.status = 'completed' and (b.passenger_id = @id or t.driver_id = @id)
                """, new { id });
            var reviews = await read.GetReviewsAsync(id, ct);
            return Results.Ok(new UserProfileDto(user, reviews, completed));
        }).RequireAuthorization().WithTags("Users");

        app.MapGet("/api/users/{id:guid}/reviews", async (
            Guid id, ReadService read, CancellationToken ct) =>
            Results.Ok(await read.GetReviewsAsync(id, ct))).RequireAuthorization().WithTags("Users");

        app.MapPost("/api/me/devices", async (
            RegisterDeviceRequest request, HttpContext http, Db db, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(request.Token) || request.Token.Length > 4096)
                return Results.BadRequest(new { error = "Device token không hợp lệ" });
            if (request.Platform is not ("android" or "ios" or "web"))
                return Results.BadRequest(new { error = "Platform không hợp lệ" });

            await using var conn = await db.OpenAsync(ct);
            await conn.ExecuteAsync("""
                insert into device_tokens (user_id, token, platform)
                values (@userId, @token, @platform)
                on conflict (token) do update set
                    user_id = excluded.user_id,
                    platform = excluded.platform,
                    updated_at = now()
                """, new
            {
                userId = http.User.GetUserId(),
                token = request.Token.Trim(),
                request.Platform
            });
            return Results.Ok(new { status = "registered" });
        }).RequireAuthorization().WithTags("Me");

        app.MapDelete("/api/me/devices", async (
            string token, HttpContext http, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            await conn.ExecuteAsync(
                "delete from device_tokens where token = @token and user_id = @userId",
                new { token, userId = http.User.GetUserId() });
            return Results.Ok(new { status = "removed" });
        }).RequireAuthorization().WithTags("Me");

        app.MapGet("/api/me/earnings", async (
            HttpContext http, Db db, CancellationToken ct) =>
        {
            var driverId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);

            var trips = await conn.ExecuteScalarAsync<int>(
                "select coalesce(sum(b.price_total),0) from bookings b join trips t on t.id = b.trip_id where t.driver_id = @driverId and b.status = 'completed'",
                new { driverId });
            var completedTrips = await conn.ExecuteScalarAsync<int>(
                "select count(*) from bookings b join trips t on t.id = b.trip_id where t.driver_id = @driverId and b.status = 'completed'",
                new { driverId });
            var daily = await conn.ExecuteScalarAsync<long>(
                "select coalesce(sum(amount_minor),0) from driver_earnings where driver_id = @driverId",
                new { driverId });
            var dailyCount = await conn.ExecuteScalarAsync<int>(
                "select count(*) from driver_earnings where driver_id = @driverId", new { driverId });
            var tipEarnings = await conn.ExecuteScalarAsync<int>(
                "select coalesce(sum(amount),0) from tips where driver_id = @driverId and status = 'confirmed'",
                new { driverId });
            var tipCount = await conn.ExecuteScalarAsync<int>(
                "select count(*) from tips where driver_id = @driverId and status = 'confirmed'",
                new { driverId });
            var pendingTips = await conn.ExecuteScalarAsync<int>(
                "select count(*) from tips where driver_id = @driverId and status = 'pending'",
                new { driverId });

            var recent = new List<EarningItemDto>();
            var bookings = await conn.QueryAsync<dynamic>("""
                select b.price_total, b.updated_at, t.origin_label, t.destination_label
                from bookings b join trips t on t.id = b.trip_id
                where t.driver_id = @driverId and b.status = 'completed'
                order by b.updated_at desc limit 10
                """, new { driverId });
            foreach (var b in bookings)
            {
                recent.Add(new EarningItemDto("trip",
                    $"{b.origin_label} → {b.destination_label}",
                    (int)b.price_total, "VND", Time.ToDto((DateTime)b.updated_at)));
            }

            var validations = await conn.QueryAsync<dynamic>("""
                select v.amount_minor, v.validated_at, s.name as stop_name
                from driver_earnings e
                join trip_validations v on v.id = e.validation_id
                join e_tickets t on t.id = v.e_ticket_id
                join line_stops s on s.id = t.stop_id
                where e.driver_id = @driverId
                order by v.validated_at desc limit 10
                """, new { driverId });
            foreach (var v in validations)
            {
                recent.Add(new EarningItemDto("daily", (string)v.stop_name,
                    (int)(long)v.amount_minor, "EUR", Time.ToDto((DateTime)v.validated_at)));
            }

            var tips = await conn.QueryAsync<dynamic>("""
                select t.amount, t.confirmed_at, t.created_at, p.full_name as passenger_name
                from tips t join users p on p.id = t.passenger_id
                where t.driver_id = @driverId and t.status = 'confirmed'
                order by coalesce(t.confirmed_at, t.created_at) desc limit 10
                """, new { driverId });
            foreach (var tip in tips)
            {
                var at = tip.confirmed_at is DateTime confirmed ? confirmed : (DateTime)tip.created_at;
                recent.Add(new EarningItemDto("tip", $"Tip từ {tip.passenger_name}",
                    (int)tip.amount, "VND", Time.ToDto(at)));
            }

            return Results.Ok(new EarningsDto(trips, completedTrips, daily, dailyCount,
                recent.OrderByDescending(r => r.At).Take(20).ToList(),
                tipEarnings, tipCount, pendingTips));
        }).RequireAuthorization().WithTags("Me");

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
