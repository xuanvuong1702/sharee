using Dapper;
using Microsoft.AspNetCore.SignalR;
using Sharee.Api.Contracts;
using Sharee.Api.Hubs;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Api.Endpoints;

public static class ReviewEndpoints
{
    public static IEndpointRouteBuilder MapReviewEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/bookings/{id:guid}/reviews", async (
            Guid id, CreateReviewRequest request, HttpContext http, Db db,
            ReadService read, CancellationToken ct) =>
        {
            if (request.Rating is < 1 or > 5)
                return Results.BadRequest(new { error = "Số sao phải từ 1 đến 5" });

            var userId = http.User.GetUserId();
            var booking = await read.GetBookingAsync(id, ct);
            if (booking is null) return Results.NotFound();
            if (booking.Status != "completed")
                return Results.Conflict(new { error = "Chỉ đánh giá chuyến đã hoàn thành" });

            var isPassenger = booking.Passenger.Id == userId;
            var isDriver = booking.Driver.Id == userId;
            if (!isPassenger && !isDriver) return Results.Forbid();

            var revieweeId = isPassenger ? booking.Driver.Id : booking.Passenger.Id;
            var role = isPassenger ? "passenger" : "driver";

            await using var conn = await db.OpenAsync(ct);
            await using var tx = await conn.BeginTransactionAsync(ct);
            var reviewId = await conn.ExecuteScalarAsync<Guid?>("""
                insert into reviews (booking_id, reviewer_id, reviewee_id, role, rating, comment)
                values (@bookingId, @reviewerId, @revieweeId, @role, @rating, @comment)
                on conflict (booking_id, reviewer_id) do nothing
                returning id
                """, new
            {
                bookingId = id, reviewerId = userId, revieweeId, role,
                rating = request.Rating, comment = request.Comment
            }, tx);

            if (reviewId is null)
            {
                await tx.RollbackAsync(ct);
                return Results.Conflict(new { error = "Bạn đã đánh giá chuyến này" });
            }

            await conn.ExecuteAsync("""
                update users set
                    rating_avg = ((rating_avg * rating_count) + @rating) / (rating_count + 1),
                    rating_count = rating_count + 1
                where id = @revieweeId
                """, new { rating = request.Rating, revieweeId }, tx);

            await tx.CommitAsync(ct);

            var row = await conn.QuerySingleAsync<dynamic>("""
                select r.id, r.booking_id, r.reviewer_id, u.full_name as reviewer_name,
                       r.reviewee_id, r.rating, r.comment, r.role, r.created_at
                from reviews r join users u on u.id = r.reviewer_id
                where r.id = @reviewId
                """, new { reviewId });
            var review = new ReviewDto(
                (Guid)row.id, (Guid)row.booking_id, (Guid)row.reviewer_id, (string)row.reviewer_name,
                (Guid)row.reviewee_id, (short)row.rating, (string?)row.comment, (string)row.role,
                Time.ToDto((DateTime)row.created_at));
            return Results.Ok(review);
        }).RequireAuthorization().WithTags("Reviews");

        return app;
    }
}
