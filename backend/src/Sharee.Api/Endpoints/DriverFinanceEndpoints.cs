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
                where driver_id = @driverId and status in ('pending','approved','processing')
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
                    accountNumber = Sharee.Api.Services.Privacy.MaskPhone(
                        SensitiveDataProtector.Unprotect((string)r.account_number) ?? ""),
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
            // Serialize balance checks for this driver; otherwise two parallel
            // withdrawal requests both observe the same available balance.
            await conn.ExecuteAsync(
                "select pg_advisory_xact_lock(hashtext(@driverId::text))",
                new { driverId }, tx);
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
                where driver_id = @driverId and status in ('pending','approved','processing')
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
                accountNumber = SensitiveDataProtector.Protect(request.AccountNumber.Trim())!,
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
                accountNumber = SensitiveDataProtector.Unprotect((string)r.account_number),
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
                update driver_withdrawals set status = 'approved', approved_by = @adminId,
                    processed_by = @adminId, processed_at = now()
                where id = @id and status = 'pending'
                """, new { id, adminId = http.User.GetUserId() });
            return affected == 0 ? Results.Conflict(new { error = "Yêu cầu không còn chờ duyệt." })
                : Results.Ok(new { status = "approved" });
        });

        admin.MapPost("/{id:guid}/paid", async (
            Guid id, MarkWithdrawalPaidRequest request, HttpContext http, Db db,
            LedgerService ledger, BankPayoutService bank, IConfiguration config,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(request.ProviderRef) || request.ProviderRef.Length > 160)
                return Results.BadRequest(new { error = "Mã giao dịch ngân hàng không hợp lệ." });
            var adminId = http.User.GetUserId();
            decimal dualApprovalAbove = config.GetValue("Admin:DualApprovalAbove", 5_000_000m);

            await using var conn = await db.OpenAsync(ct);
            Guid? approvedBy;
            int amount;
            string idempotencyKey;
            await using (var tx = await conn.BeginTransactionAsync(ct))
            {
                var row = await conn.QuerySingleOrDefaultAsync<dynamic>("""
                    select driver_id, amount, status, approved_by, idempotency_key
                    from driver_withdrawals where id = @id for update
                    """, new { id }, tx);
                if (row is null) { await tx.RollbackAsync(ct); return Results.NotFound(); }
                var status = (string)row.status;
                if (status == "paid") { await tx.RollbackAsync(ct); return Results.Ok(new { status = "paid" }); }
                if (status == "pending")
                {
                    await tx.RollbackAsync(ct);
                    return Results.Conflict(new { error = "Yêu cầu phải được duyệt trước khi chi tiền." });
                }
                if (status is not ("approved" or "processing"))
                {
                    await tx.RollbackAsync(ct);
                    return Results.Conflict(new { error = "Yêu cầu không thể thanh toán." });
                }
                amount = (int)row.amount;
                approvedBy = row.approved_by is null ? null : (Guid)row.approved_by;
                // Re-check available balance while holding the withdrawal row.
                await conn.ExecuteAsync(
                    "select pg_advisory_xact_lock(hashtext(@driverId::text))",
                    new { driverId = (Guid)row.driver_id }, tx);
                var balance = await conn.ExecuteScalarAsync<long>("""
                    select coalesce(sum(case when e.direction = 'C' then e.amount else -e.amount end), 0)
                    from ledger_entries e join ledger_transactions t on t.id = e.txn_id
                    where e.account = 'driver_payable'
                      and ((t.ref_type = 'booking' and exists (
                            select 1 from bookings b join trips tr on tr.id = b.trip_id
                            where b.id = t.ref_id and tr.driver_id = @driverId))
                        or (t.ref_type = 'withdrawal' and t.ref_id in (
                            select id from driver_withdrawals where driver_id = @driverId)))
                    """, new { driverId = (Guid)row.driver_id }, tx);
                var pendingTotal = await conn.ExecuteScalarAsync<long>("""
                    select coalesce(sum(amount), 0) from driver_withdrawals
                    where driver_id = @driverId
                      and status in ('pending','approved','processing')
                    """, new { driverId = (Guid)row.driver_id }, tx);
                if (balance - pendingTotal < 0)
                {
                    await tx.RollbackAsync(ct);
                    return Results.Conflict(new { error = "Số dư ví không đủ để chi lệnh này." });
                }
                if (amount >= dualApprovalAbove && approvedBy == adminId)
                {
                    await tx.RollbackAsync(ct);
                    return Results.Conflict(new
                    {
                        error = "Khoản chi lớn phải do người duyệt khác thực hiện (maker-checker)."
                    });
                }
                idempotencyKey = (string?)row.idempotency_key
                    ?? $"withdrawal-{id:N}-{amount}";
                // Commit processing BEFORE calling the provider. A crash after
                // the bank call leaves a visible processing record for retry.
                await conn.ExecuteAsync("""
                    update driver_withdrawals
                    set status = 'processing', processing_started_at = coalesce(processing_started_at, now()),
                        idempotency_key = @idempotencyKey
                    where id = @id
                    """, new { id, idempotencyKey }, tx);
                await tx.CommitAsync(ct);
            }

            BankPayoutResult payout;
            if (bank.Enabled)
            {
                var row = await conn.QuerySingleAsync<dynamic>(
                    "select bank_name, account_number, account_name from driver_withdrawals where id = @id",
                    new { id });
                payout = await bank.TransferAsync(id, amount, (string)row.bank_name,
                    SensitiveDataProtector.Unprotect((string)row.account_number)!,
                    (string)row.account_name, idempotencyKey, ct);
            }
            else
            {
                payout = new BankPayoutResult(true, null, null);
            }

            if (bank.Enabled && !payout.Ok)
            {
                await conn.ExecuteAsync("""
                    update driver_withdrawals
                    set status = 'approved', failure_reason = @error, note = @note
                    where id = @id and status = 'processing'
                    """, new { id, error = payout.Error, note = request.Note });
                return Results.Json(new { error = payout.Error ?? "Bank payout thất bại" },
                    statusCode: StatusCodes.Status502BadGateway);
            }

            var providerRef = payout.ProviderRef is { Length: > 0 }
                ? payout.ProviderRef : request.ProviderRef.Trim();
            await using (var tx = await conn.BeginTransactionAsync(ct))
            {
                var current = await conn.ExecuteScalarAsync<string>(
                    "select status from driver_withdrawals where id = @id for update",
                    new { id }, tx);
                if (current == "paid") { await tx.RollbackAsync(ct); return Results.Ok(new { status = "paid" }); }
                await ledger.RecordAsync(conn, tx, "withdrawal", "withdrawal", id,
                    ("driver_payable", 'D', amount), ("driver_paid", 'C', amount));
                await conn.ExecuteAsync("""
                    update driver_withdrawals set status = 'paid', provider_ref = @ref,
                        processed_by = @adminId, processed_at = now(), note = @note,
                        failure_reason = null
                    where id = @id
                    """, new { id, @ref = providerRef, adminId, note = request.Note }, tx);
                await Audit.LogAsync(conn, tx, adminId, "withdrawal.paid",
                    "withdrawal", id.ToString(), new { amount, providerRef, idempotencyKey });
                await tx.CommitAsync(ct);
            }
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
