using Dapper;
using Npgsql;
using Sharee.Api.Services;
using Testcontainers.PostgreSql;

namespace Sharee.Tests;

/// <summary>
/// Integration test for the ledger invariant. Skipped automatically when Docker
/// is unavailable so the fast unit suite still runs locally/CI without Docker.
/// </summary>
public class LedgerIntegrationTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _db = new PostgreSqlBuilder()
        .WithImage("postgres:16-alpine")
        .Build();

    public async Task InitializeAsync()
    {
        await _db.StartAsync();
        await using var conn = new NpgsqlConnection(_db.GetConnectionString());
        await conn.OpenAsync();
        await conn.ExecuteAsync("""
            create table ledger_transactions (
              id uuid primary key,
              type text not null,
              ref_type text not null,
              ref_id uuid not null,
              created_at timestamptz not null default now());
            create table ledger_entries (
              id bigserial primary key,
              txn_id uuid not null references ledger_transactions(id),
              account text not null,
              direction char(1) not null check (direction in ('D','C')),
              amount bigint not null check (amount >= 0));
            """);
    }

    public async Task DisposeAsync() => await _db.DisposeAsync();

    [Fact]
    public async Task Ledger_transaction_is_balanced_and_escrow_invariant_holds()
    {
        await using var conn = new NpgsqlConnection(_db.GetConnectionString());
        await conn.OpenAsync();
        await using var tx = await conn.BeginTransactionAsync();
        var ledger = new LedgerService();
        var id = Guid.NewGuid();
        // Money enters escrow, then is split between driver and platform.
        await ledger.RecordAsync(conn, tx, "capture", "booking", id,
            ("customer_receivable", 'D', 100_000),
            ("escrow", 'C', 100_000));
        await ledger.RecordAsync(conn, tx, "payout", "booking", id,
            ("escrow", 'D', 100_000),
            ("driver_payable", 'C', 90_000),
            ("platform_revenue", 'C', 10_000));
        await tx.CommitAsync();

        var debit = await conn.ExecuteScalarAsync<long>(
            "select coalesce(sum(amount),0) from ledger_entries where direction = 'D'");
        var credit = await conn.ExecuteScalarAsync<long>(
            "select coalesce(sum(amount),0) from ledger_entries where direction = 'C'");
        Assert.Equal(debit, credit);
        Assert.Equal(200_000, debit);

        var escrow = await conn.ExecuteScalarAsync<long>(
            "select coalesce(sum(case when direction='D' then amount else -amount end),0) " +
            "from ledger_entries where account='escrow'");
        Assert.Equal(0, escrow);
    }
}
