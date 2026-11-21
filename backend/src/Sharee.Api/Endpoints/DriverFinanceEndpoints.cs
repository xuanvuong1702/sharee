using Dapper;
using Npgsql;
using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Api.Endpoints;

public static class DriverFinanceEndpoints
{
    public static IEndpointRouteBuilder MapDriverFinanceEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/driver/wallet", async (HttpContext http, Db db, CancellationToken ct) =>
        {
            var driverId = http.User.GetUserId();
            await using var conn = await db.OpenAsync(ct);
            if (!await IsDriverAsync(conn, driverId, ct))
                return Results.Json(new { error = "Tài khoản chưa phải tài xế." }, statusCode: 403);

            var balance = await conn.ExecuteScalarAsync<long>("""
                select coalesce(sum(case when direction = 'C' then amount else -amount end), 0)
                from ledger_entries e
                join ledger_transactions t on t.id = e.txn_id
                where e.account = 'driver_payable'
                  and (
                    (t.ref_type = 'booking' and exists (
                      select 1 from bookings b join trips tr on tr.id = b.trip_id
                      where b.id = t.ref_id and tr.driver_id = @driverId))
                    or (t.ref_type = 'withdrawal' and t.ref_id in (
                      select id from driver_withdrawals where driver_id = @driverId))
                  )
                """, new { driverId });
            var pending = await conn.ExecuteScalarAsync<long>("""
                select coalesce(sum(amount), 0) from driver_withdrawals
                where driver_id = @driverId and status in ('pending','approved')
                """, new { driverId });
            var rows = await conn.QueryAsync<dynamic>("""
                select id, amount, bank_name, account_number, status, provider_ref, note,
                       requested_at, processed_at
                from driver_withdrawals where driver_id = @driverId
                order by requested_at desc limit 50
                """, new { driverId });
            return Results.Ok(new
            {
                balance,
                pending,
                available = Math.Max(0, balance - pending),
                withdrawals = rows.Select(r => new
                {
                    id = (Guid)r.id,
                    amount = (int)r.amount,
                    bankName = (string)r.bank_name,
                    accountNumber = Sharee.Api.Services.Privacy.MaskPhone((string)r.account_number),
                    status = (string)r.status,
                    providerRef = (string?)r.provider_ref,
                    note = (string?)r.note,
                    requestedAt = Time.ToDto((DateTime)r.requested_at),
                    processedAt = r.processed_at is null ? (DateTimeOffset?)null : Time.ToDto((DateTime)r.processed_at)
                })
            });
        }).RequireAuthorization().WithTags("DriverFinance");

        app.MapPost("/api/driver/withdrawals", async (
            CreateWithdrawalRequest request, HttpContext http, Db db, CancellationToken ct) =>
        {
            var driverId = http.User.GetUserId();
            if (request.Amount < 50_000 || request.Amount > 50_000_000)
                return Results.BadRequest(new { error = "Số tiền rút phải từ 50.000đ đến 50.000.000đ." });
            if (string.IsNullOrWhiteSpace(request.BankName) || request.BankName.Trim().Length > 120 ||
                string.IsNullOrWhiteSpace(request.AccountNumber) || request.AccountNumber.Trim().Length > 32 ||
                string.IsNullOrWhiteSpace(request.AccountName) || request.AccountName.Trim().Length > 120)
                return Results.BadRequest(new { error = "Thông tin ngân hàng không hợp lệ." });

            await using var conn = await db.OpenAsync(ct);
            if (!await DriverVerification.IsApprovedAsync(conn, driverId, ct))
                return Results.Json(new { error = "Hồ sơ tài xế chưa được duyệt." }, statusCode: 403);

            await using var tx = await conn.BeginTransactionAsync(ct);
            var balance = await conn.ExecuteScalarAsync<long>("""
                select coalesce(sum(case when e.direction = 'C' then e.amount else -e.amount end), 0)
                from ledger_entries e
                join ledger_transactions t on t.id = e.txn_id
                where e.account = 'driver_payable'
                  and (
                    (t.ref_type = 'booking' and exists (
                      select 1 from bookings b join trips tr on tr.id = b.trip_id
                      where b.id = t.ref_id and tr.driver_id = @driverId))
                    or (t.ref_type = 'withdrawal' and t.ref_id in (
                      select id from driver_withdrawals where driver_id = @driverId))
                  )
                """, new { driverId }, tx);
            var pending = await conn.ExecuteScalarAsync<long>("""
                select coalesce(sum(amount), 0) from driver_withdrawals
                where driver_id = @driverId and status in ('pending','approved')
                """, new { driverId }, tx);
            if (request.Amount > balance - pending)
            {
                await tx.RollbackAsync(ct);
                return Results.Conflict(new { error = "Số dư khả dụng không đủ." });
            }

            var id = await conn.ExecuteScalarAsync<Guid>("""
                insert into driver_withdrawals
                  (driver_id, amount, bank_name, account_number, account_name)
                values (@driverId, @amount, @bankName, @accountNumber, @accountName)
                returning id
                """, new
            {
                driverId,
                amount = request.Amount,
                bankName = request.BankName.Trim(),
                accountNumber = request.AccountNumber.Trim(),
                accountName = request.AccountName.Trim()
            }, tx);
            await tx.CommitAsync(ct);
            return Results.Created($"/api/driver/withdrawals/{id}", new { id, status = "pending" });
        }).RequireAuthorization().WithTags("DriverFinance");

        var admin = app.MapGroup("/api/admin/withdrawals").RequireAuthorization("admin");
        admin.MapGet("", async (Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var rows = await conn.QueryAsync<dynamic>("""
                select w.id, w.driver_id, u.full_name as driver_name, w.amount,
                       w.bank_name, w.account_number, w.account_name, w.status,
                       w.provider_ref, w.note, w.requested_at, w.processed_at
                from driver_withdrawals w join users u on u.id = w.driver_id
                order by case w.status when 'pending' then 0 when 'approved' then 1 else 2 end,
                         w.requested_at
                limit 200
                """);
            return Results.Ok(rows.Select(r => new
            {
                id = (Guid)r.id,
                driverId = (Guid)r.driver_id,
                driverName = (string)r.driver_name,
                amount = (int)r.amount,
                bankName = (string)r.bank_name,
                accountNumber = (string)r.account_number,
                accountName = (string)r.account_name,
                status = (string)r.status,
                providerRef = (string?)r.provider_ref,
                note = (string?)r.note,
                requestedAt = Time.ToDto((DateTime)r.requested_at)
            }));
        });

        admin.MapPost("/{id:guid}/approve", async (
            Guid id, HttpContext http, Db db, CancellationToken ct) =>
        {
            await using var conn = await db.OpenAsync(ct);
            var affected = await conn.ExecuteAsync("""
                update driver_withdrawals set status = 'approved', processed_by = @adminId,
                    processed_at = now() where id = @id and status = 'pending'
                """, new { id, adminId = http.User.GetUserId() });
            return affected == 0 ? Results.Conflict(new { error = "Yêu cầu không còn chờ duyệt." })
                : Results.Ok(new { status = "approved" });
        });

        admin.MapPost("/{id:guid}/paid", async (
            Guid id, MarkWithdrawalPaidRequest request, HttpContext http, Db db,
            LedgerService ledger, BankPayoutService bank, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(request.ProviderRef) || request.ProviderRef.Length > 160)
                return Results.BadRequest(new { error = "Mã giao dịch ngân hàng không hợp lệ." });
            await using var conn = await db.OpenAsync(ct);
            await using var tx = await conn.BeginTransactionAsync(ct);
            var row = await conn.QuerySingleOrDefaultAsync<dynamic>("""
                select driver_id, amount, status, bank_name, account_number, account_name
                from driver_withdrawals where id = @id for update
                """, new { id }, tx);
            if (row is null) { await tx.RollbackAsync(ct); return Results.NotFound(); }
            if ((string)row.status == "paid") { await tx.RollbackAsync(ct); return Results.Ok(new { status = "paid" }); }
            if ((string)row.status is not ("pending" or "approved"))
            {
                await tx.RollbackAsync(ct);
                return Results.Conflict(new { error = "Yêu cầu không thể thanh toán." });
            }
            var amount = (int)row.amount;
            var providerRef = request.ProviderRef.Trim();
            var payout = await bank.TransferAsync(id, amount, (string)row.bank_name,
                (string)row.account_number, (string)row.account_name, ct);
            if (bank.Enabled && !payout.Ok)
            {
                await tx.RollbackAsync(ct);
                return Results.Json(new { error = payout.Error ?? "Bank payout thất bại" },
                    statusCode: StatusCodes.Status502BadGateway);
            }
            if (payout.ProviderRef is { Length: > 0 }) providerRef = payout.ProviderRef;
            await ledger.RecordAsync(conn, tx, "withdrawal", "withdrawal", id,
                ("driver_payable", 'D', amount), ("driver_paid", 'C', amount));
            await conn.ExecuteAsync("""
                update driver_withdrawals set status = 'paid', provider_ref = @ref,
                    processed_by = @adminId, processed_at = now(), note = @note
                where id = @id
                """, new { id, @ref = providerRef, adminId = http.User.GetUserId(), note = request.Note }, tx);
            await Audit.LogAsync(conn, tx, http.User.GetUserId(), "withdrawal.paid",
                "withdrawal", id.ToString(), new { amount, request.ProviderRef });
            await tx.CommitAsync(ct);
            return Results.Ok(new { status = "paid" });
        });

        admin.MapPost("/{id:guid}/reject", async (
            Guid id, RejectWithdrawalRequest request, HttpContext http, Db db, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(request.Note))
                return Results.BadRequest(new { error = "Cần lý do từ chối." });
            await using var conn = await db.OpenAsync(ct);
            var affected = await conn.ExecuteAsync("""
                update driver_withdrawals set status = 'rejected', note = @note,
                    processed_by = @adminId, processed_at = now()
                where id = @id and status in ('pending','approved')
                """, new { id, note = request.Note.Trim(), adminId = http.User.GetUserId() });
            return affected == 0 ? Results.Conflict(new { error = "Yêu cầu không thể từ chối." })
                : Results.Ok(new { status = "rejected" });
        });

        return app;
    }

    private static Task<bool> IsDriverAsync(NpgsqlConnection conn, Guid userId, CancellationToken ct)
        => conn.ExecuteScalarAsync<bool>("""
            select exists(
              select 1 from users u
              where u.id = @userId and (u.role = 'driver' or exists(
                select 1 from vehicles v where v.owner_id = u.id and v.status = 'active')))
            """, new { userId });
}
