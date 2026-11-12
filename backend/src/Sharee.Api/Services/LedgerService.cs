using Dapper;
using Npgsql;

namespace Sharee.Api.Services;

public sealed class LedgerService
{
    public async Task RecordAsync(
        NpgsqlConnection conn,
        NpgsqlTransaction tx,
        string type,
        string refType,
        Guid refId,
        params (string Account, char Direction, long Amount)[] entries)
    {
        var debit = entries.Where(e => e.Direction == 'D').Sum(e => e.Amount);
        var credit = entries.Where(e => e.Direction == 'C').Sum(e => e.Amount);
        if (debit != credit)
            throw new InvalidOperationException($"Unbalanced ledger transaction: debit={debit} credit={credit}");

        var txnId = Guid.NewGuid();
        await conn.ExecuteAsync("""
            insert into ledger_transactions (id, type, ref_type, ref_id)
            values (@txnId, @type, @refType, @refId)
            """, new { txnId, type, refType, refId }, tx);

        foreach (var entry in entries)
        {
            await conn.ExecuteAsync("""
                insert into ledger_entries (txn_id, account, direction, amount)
                values (@txnId, @account, @direction, @amount)
                """, new { txnId, account = entry.Account, direction = entry.Direction, amount = entry.Amount }, tx);
        }
    }
}
