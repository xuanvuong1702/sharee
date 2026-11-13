using System.Text.Json;
using Dapper;
using Npgsql;

namespace Sharee.Api.Infrastructure;

public static class Audit
{
    public static Task LogAsync(
        NpgsqlConnection conn,
        NpgsqlTransaction? tx,
        Guid? actorId,
        string action,
        string? targetType = null,
        string? targetId = null,
        object? meta = null)
    {
        return conn.ExecuteAsync("""
            insert into audit_logs (actor_id, action, target_type, target_id, meta)
            values (@actorId, @action, @targetType, @targetId, @meta::jsonb)
            """, new
        {
            actorId,
            action,
            targetType,
            targetId,
            meta = meta is null ? "{}" : JsonSerializer.Serialize(meta)
        }, tx);
    }
}
