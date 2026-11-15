using System.Globalization;
using System.Text.RegularExpressions;
using Dapper;
using Microsoft.AspNetCore.Mvc;
using Npgsql;
using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Api.Endpoints;

public static partial class TipEndpoints
{
    private const int MaxAmount = 1_000_000;

    [GeneratedRegex(@"^\d{6}$")]
    private static partial Regex BankBinRegex();

    [GeneratedRegex(@"^\d{6,19}$")]
    private static partial Regex AccountRegex();

    public static IEndpointRouteBuilder MapTipEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api").RequireAuthorization().WithTags("Tips");

        group.MapGet("/me/tip-account", async (HttpContext http, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            return Results.Ok(await GetAccountAsync(conn, http.User.GetUserId()));
        });

        group.MapPut("/me/tip-account", async (
            SetTipAccountRequest request, HttpContext http, Db db, CancellationToken ct) =>
        {
            var bankBin = request.BankBin?.Trim() ?? "";
            var accountNumber = request.AccountNumber?.Trim() ?? "";
            var accountName = request.AccountName?.Trim() ?? "";
            var bankName = request.BankName?.Trim() ?? "";

            if (!BankBinRegex().IsMatch(bankBin))
                return Results.BadRequest(new { error = "Mã BIN ngân hàng phải gồm đúng 6 chữ số" });
            if (!AccountRegex().IsMatch(accountNumber))
                return Results.BadRequest(new { error = "Số tài khoản phải gồm 6–19 chữ số" });
            if (accountName.Length is < 2 or > 80)
                return Results.BadRequest(new { error = "Tên chủ tài khoản phải từ 2–80 ký tự" });
            if (bankName.Length > 80)
                return Results.BadRequest(new { error = "Tên ngân hàng quá dài" });

            await using var conn = await db.OpenAsync(ct);
            await conn.ExecuteAsync("""
                insert into driver_tip_accounts
                    (driver_id, bank_bin, bank_name, account_number, account_name)
                values (@driverId, @bankBin, @bankName, @accountNumber, @accountName)
                on conflict (driver_id) do update set
                    bank_bin = excluded.bank_bin,
                    bank_name = excluded.bank_name,
                    account_number = excluded.account_number,
                    account_name = excluded.account_name,
                    updated_at = now()
                """, new
            {
                driverId = http.User.GetUserId(),
                bankBin,
                bankName,
                accountNumber,
                accountName
            });

            return Results.Ok(await GetAccountAsync(conn, http.User.GetUserId()));
        });

        group.MapGet("/bookings/{id:guid}/tip-info", async (
            Guid id, HttpContext http, Db db, CancellationToken ct) =>
        {
            var userId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            var booking = await conn.QuerySingleOrDefaultAsync<dynamic>("""
                select b.id, b.trip_id, b.passenger_id, b.status, t.driver_id
                from bookings b join trips t on t.id = b.trip_id
                where b.id = @id
                """, new { id });
            if (booking is null) return Results.NotFound();
            if ((Guid)booking.passenger_id != userId && (Guid)booking.driver_id != userId)
                return Results.Forbid();

            var account = await GetAccountAsync(conn, (Guid)booking.driver_id);
            var tip = await conn.QuerySingleOrDefaultAsync<dynamic>("""
                select t.id from tips t
                where t.booking_id = @id and t.passenger_id = @userId
                  and t.status <> 'cancelled'
                order by t.created_at desc limit 1
                """, new { id, userId });
            var existing = tip is null ? null : await GetTipAsync(conn, (Guid)tip.id);
            var qrPayload = existing is { Status: "pending", Method: "bank_transfer" } && account is not null
                ? VietQr.Build(account.BankBin, account.AccountNumber, existing.Amount,
                    $"Sharee tip {existing.Id.ToString("N")[..8]}")
                : null;
            return Results.Ok(new BookingTipInfoDto(account, existing, qrPayload));
        });

        group.MapGet("/bookings/{id:guid}/tips", async (
            Guid id, HttpContext http, Db db, CancellationToken ct) =>
        {
            var userId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            var booking = await conn.QuerySingleOrDefaultAsync<dynamic>("""
                select b.passenger_id, t.driver_id
                from bookings b join trips t on t.id = b.trip_id where b.id = @id
                """, new { id });
            if (booking is null) return Results.NotFound();
            if ((Guid)booking.passenger_id != userId && (Guid)booking.driver_id != userId)
                return Results.Forbid();

            var rows = await conn.QueryAsync<Guid>("""
                select id from tips where booking_id = @id order by created_at desc
                """, new { id });
            var list = new List<TipDto>();
            foreach (var tipId in rows)
            {
                var tip = await GetTipAsync(conn, tipId);
                if (tip is not null) list.Add(tip);
            }
            return Results.Ok(list);
        });

        group.MapPost("/bookings/{id:guid}/tips", async (
            Guid id, [FromBody] CreateTipRequest request, HttpContext http, Db db, CancellationToken ct) =>
        {
            var userId = http.User.GetUserId();
            var method = (request.PaymentMethod ?? "").Trim().ToLowerInvariant();
            if (method is not ("bank_transfer" or "cash"))
                return Results.BadRequest(new { error = "Phương thức tip không hợp lệ" });
            if (request.Amount is < 1000 or > MaxAmount)
                return Results.BadRequest(new { error = "Tip phải từ 1.000đ đến 1.000.000đ" });

            var message = string.IsNullOrWhiteSpace(request.Message) ? null : request.Message.Trim();
            if (message is { Length: > 200 })
                return Results.BadRequest(new { error = "Lời nhắn tip tối đa 200 ký tự" });

            await using var conn = await db.OpenAsync(ct);
            var booking = await conn.QuerySingleOrDefaultAsync<dynamic>("""
                select b.id, b.trip_id, b.passenger_id, b.status, t.driver_id,
                       p.full_name as passenger_name, d.full_name as driver_name
                from bookings b
                join trips t on t.id = b.trip_id
                join users p on p.id = b.passenger_id
                join users d on d.id = t.driver_id
                where b.id = @id
                """, new { id });
            if (booking is null) return Results.NotFound();
            if ((Guid)booking.passenger_id != userId) return Results.Forbid();
            if ((string)booking.status != "completed")
                return Results.Conflict(new { error = "Chỉ có thể tip sau khi chuyến đã hoàn thành" });

            var existing = await conn.ExecuteScalarAsync<Guid?>("""
                select id from tips
                where booking_id = @id and passenger_id = @userId and status <> 'cancelled'
                """, new { id, userId });
            if (existing is not null)
                return Results.Conflict(new { error = "Bạn đã gửi tip cho chuyến này" });

            var account = await GetAccountAsync(conn, (Guid)booking.driver_id);
            if (method == "bank_transfer" && account is null)
                return Results.BadRequest(new { error = "Tài xế chưa cấu hình tài khoản nhận tip" });

            var status = method == "cash" ? "confirmed" : "pending";
            var tipId = Guid.NewGuid();
            var qrPayload = method == "bank_transfer"
                ? VietQr.Build(account!.BankBin, account.AccountNumber, request.Amount,
                    $"Sharee tip {tipId.ToString("N")[..8]}")
                : null;

            await using var tx = await conn.BeginTransactionAsync(ct);
            await conn.ExecuteAsync("""
                insert into tips (id, booking_id, trip_id, passenger_id, driver_id,
                                  amount, message, method, status, confirmed_at)
                values (@id, @bookingId, @tripId, @passengerId, @driverId,
                        @amount, @message, @method, @status, case when @status = 'confirmed' then now() else null end)
                """, new
            {
                id = tipId,
                bookingId = id,
                tripId = (Guid)booking.trip_id,
                passengerId = userId,
                driverId = (Guid)booking.driver_id,
                amount = request.Amount,
                message,
                method,
                status
            }, tx);

            var title = method == "cash" ? "Bạn nhận được tip" : "Khách muốn tip bạn";
            var body = method == "cash"
                ? $"{booking.passenger_name} đã tip {FormatMoney(request.Amount)} tiền mặt."
                : $"{booking.passenger_name} đã gửi tip {FormatMoney(request.Amount)}. Hãy mở QR và xác nhận khi nhận được tiền.";
            await Notifier.NotifyAsync(conn, tx, (Guid)booking.driver_id, "tip.received", title, body);
            await tx.CommitAsync(ct);

            var tip = await GetTipAsync(conn, tipId);
            return Results.Created($"/api/tips/{tipId}",
                new CreateTipResponse(tip!, account, qrPayload));
        });

        group.MapPost("/tips/{id:guid}/sent", async (
            Guid id, HttpContext http, Db db, CancellationToken ct) =>
        {
            var userId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            await using var tx = await conn.BeginTransactionAsync(ct);
            var row = await conn.QuerySingleOrDefaultAsync<dynamic>("""
                select t.id, t.passenger_id, t.driver_id, t.status, t.sent_at,
                       p.full_name as passenger_name
                from tips t join users p on p.id = t.passenger_id
                where t.id = @id for update of t
                """, new { id }, tx);
            if (row is null) return Results.NotFound();
            if ((Guid)row.passenger_id != userId) return Results.Forbid();
            if ((string)row.status != "pending")
                return Results.Conflict(new { error = "Tip này không còn chờ xác nhận" });

            if (row.sent_at is null)
            {
                await conn.ExecuteAsync(
                    "update tips set sent_at = now() where id = @id", new { id }, tx);
                await Notifier.NotifyAsync(conn, tx, (Guid)row.driver_id, "tip.sent",
                    "Khách báo đã chuyển tip",
                    $"{row.passenger_name} báo đã chuyển tip. Vui lòng kiểm tra và xác nhận.");
            }
            await tx.CommitAsync(ct);
            return Results.Ok(await GetTipAsync(conn, id));
        });

        group.MapPost("/tips/{id:guid}/confirm", async (
            Guid id, HttpContext http, Db db, CancellationToken ct) =>
        {
            var userId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            await using var tx = await conn.BeginTransactionAsync(ct);
            var row = await conn.QuerySingleOrDefaultAsync<dynamic>("""
                select t.id, t.passenger_id, t.driver_id, t.status
                from tips t where t.id = @id for update of t
                """, new { id }, tx);
            if (row is null) return Results.NotFound();
            if ((Guid)row.driver_id != userId) return Results.Forbid();
            if ((string)row.status == "confirmed")
            {
                await tx.RollbackAsync(ct);
                return Results.Ok(await GetTipAsync(conn, id));
            }
            if ((string)row.status != "pending")
                return Results.Conflict(new { error = "Tip này không thể xác nhận" });

            await conn.ExecuteAsync("""
                update tips set status = 'confirmed', confirmed_at = now()
                where id = @id and status = 'pending'
                """, new { id }, tx);
            await Notifier.NotifyAsync(conn, tx, (Guid)row.passenger_id, "tip.confirmed",
                "Tài xế đã xác nhận tip",
                "Cảm ơn bạn đã gửi tip cho tài xế.");
            await tx.CommitAsync(ct);
            return Results.Ok(await GetTipAsync(conn, id));
        });

        group.MapPost("/tips/{id:guid}/cancel", async (
            Guid id, HttpContext http, Db db, CancellationToken ct) =>
        {
            var userId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            await using var tx = await conn.BeginTransactionAsync(ct);
            var row = await conn.QuerySingleOrDefaultAsync<dynamic>("""
                select id, passenger_id, status from tips where id = @id for update
                """, new { id }, tx);
            if (row is null) return Results.NotFound();
            if ((Guid)row.passenger_id != userId) return Results.Forbid();
            if ((string)row.status != "pending")
                return Results.Conflict(new { error = "Chỉ có thể huỷ tip đang chờ" });

            await conn.ExecuteAsync("""
                update tips set status = 'cancelled', cancelled_at = now()
                where id = @id and status = 'pending'
                """, new { id }, tx);
            await tx.CommitAsync(ct);
            return Results.Ok(new { status = "cancelled" });
        });

        group.MapGet("/me/tips", async (HttpContext http, Db db, CancellationToken ct) =>
        {
            var driverId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            var total = await conn.ExecuteScalarAsync<int>(
                "select coalesce(sum(amount),0) from tips where driver_id = @driverId and status = 'confirmed'",
                new { driverId });
            var confirmed = await conn.ExecuteScalarAsync<int>(
                "select count(*) from tips where driver_id = @driverId and status = 'confirmed'",
                new { driverId });
            var pending = await conn.ExecuteScalarAsync<int>(
                "select count(*) from tips where driver_id = @driverId and status = 'pending'",
                new { driverId });
            var ids = await conn.QueryAsync<Guid>("""
                select id from tips where driver_id = @driverId order by created_at desc limit 20
                """, new { driverId });
            var recent = new List<TipDto>();
            foreach (var tipId in ids)
            {
                var tip = await GetTipAsync(conn, tipId);
                if (tip is not null) recent.Add(tip);
            }
            return Results.Ok(new TipSummaryDto(total, confirmed, pending, recent));
        });

        return app;
    }

    private static async Task<TipAccountDto?> GetAccountAsync(
        Npgsql.NpgsqlConnection conn, Guid driverId)
    {
        var row = await conn.QuerySingleOrDefaultAsync<dynamic>("""
            select driver_id, bank_bin, bank_name, account_number, account_name
            from driver_tip_accounts where driver_id = @driverId
            """, new { driverId });
        if (row is null) return null;
        return new TipAccountDto(
            (Guid)row.driver_id, (string)row.bank_bin, (string)row.bank_name,
            (string)row.account_number, (string)row.account_name,
            VietQr.Build((string)row.bank_bin, (string)row.account_number, null, "Sharee tip"));
    }

    private static async Task<TipDto?> GetTipAsync(Npgsql.NpgsqlConnection conn, Guid id)
    {
        var row = await conn.QuerySingleOrDefaultAsync<dynamic>("""
            select t.id, t.booking_id, t.trip_id, t.amount, t.message, t.method, t.status,
                   t.created_at, t.sent_at, t.confirmed_at,
                   p.full_name as passenger_name, d.full_name as driver_name
            from tips t
            join users p on p.id = t.passenger_id
            join users d on d.id = t.driver_id
            where t.id = @id
            """, new { id });
        if (row is null) return null;
        return new TipDto(
            (Guid)row.id, (Guid)row.booking_id, (Guid)row.trip_id,
            (string)row.passenger_name, (string)row.driver_name,
            (int)row.amount, (string?)row.message, (string)row.method, (string)row.status,
            Time.ToDto((DateTime)row.created_at),
            row.sent_at is DateTime sent ? Time.ToDto(sent) : null,
            row.confirmed_at is DateTime confirmed ? Time.ToDto(confirmed) : null);
    }

    private static string FormatMoney(int amount)
        => amount.ToString("N0", CultureInfo.InvariantCulture) + "đ";
}
