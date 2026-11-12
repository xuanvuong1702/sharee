using Dapper;
using Npgsql;
using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Services;

public sealed class ChatService(Db db)
{
    public async Task<bool> IsParticipantAsync(Guid conversationId, Guid userId, CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync(ct);
        return await conn.ExecuteScalarAsync<bool>("""
            select exists(
                select 1 from conversations c
                join bookings b on b.id = c.booking_id
                join trips t on t.id = b.trip_id
                where c.id = @conversationId and (b.passenger_id = @userId or t.driver_id = @userId))
            """, new { conversationId, userId });
    }

    public async Task<List<ConversationDto>> ListAsync(Guid userId, CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync(ct);
        var rows = await conn.QueryAsync<dynamic>("""
            select c.id, c.booking_id,
                   case when b.passenger_id = @userId then t.driver_id else b.passenger_id end as other_id
            from conversations c
            join bookings b on b.id = c.booking_id
            join trips t on t.id = b.trip_id
            where b.passenger_id = @userId or t.driver_id = @userId
            order by c.created_at desc
            """, new { userId });

        var result = new List<ConversationDto>();
        foreach (var row in rows)
        {
            Guid id = row.id;
            Guid bookingId = row.booking_id;
            Guid otherId = row.other_id;

            var other = await conn.QuerySingleAsync<UserRow>("select * from users where id = @otherId", new { otherId });
            var last = await conn.QuerySingleOrDefaultAsync<dynamic>("""
                select body, created_at from messages where conversation_id = @id order by created_at desc limit 1
                """, new { id });
            var unread = await conn.ExecuteScalarAsync<int>("""
                select count(*) from messages
                where conversation_id = @id and sender_id <> @userId and read_at is null
                """, new { id, userId });
            var trip = await conn.QuerySingleAsync<dynamic>("""
                select t.id, t.origin_label, t.destination_label, t.departure_time,
                       d.full_name as driver_name, v.make || ' ' || v.model as vehicle, v.plate
                from bookings b join trips t on t.id = b.trip_id
                join users d on d.id = t.driver_id
                join vehicles v on v.id = t.vehicle_id
                where b.id = @bookingId
                """, new { bookingId });

            result.Add(new ConversationDto(
                id, bookingId, other.ToUser(),
                last is null ? null : (string)last.body,
                last is null ? null : Time.ToDto((DateTime)last.created_at),
                unread,
                new TripSummaryDto(trip.id, trip.origin_label, trip.destination_label,
                    Time.ToDto((DateTime)trip.departure_time), trip.driver_name, trip.vehicle, trip.plate)));
        }

        return result;
    }

    public async Task<List<MessageDto>> MessagesAsync(Guid conversationId, Guid userId, CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync(ct);
        var rows = await conn.QueryAsync<dynamic>("""
            select m.id, m.conversation_id, m.sender_id, u.full_name as sender_name,
                   m.body, m.created_at, m.read_at
            from messages m join users u on u.id = m.sender_id
            where m.conversation_id = @conversationId
            order by m.created_at
            limit 200
            """, new { conversationId });
        await conn.ExecuteAsync("""
            update messages set read_at = now()
            where conversation_id = @conversationId and sender_id <> @userId and read_at is null
            """, new { conversationId, userId });

        return rows.Select(r => new MessageDto(
            (Guid)r.id, (Guid)r.conversation_id, (Guid)r.sender_id, (string)r.sender_name,
            (string)r.body, Time.ToDto((DateTime)r.created_at),
            r.read_at is null ? null : Time.ToDto((DateTime)r.read_at))).ToList();
    }

    public async Task<MessageDto> SendAsync(Guid conversationId, Guid userId, string body, CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync(ct);
        var row = await conn.QuerySingleAsync<dynamic>("""
            insert into messages (conversation_id, sender_id, body)
            values (@conversationId, @userId, @body)
            returning id, conversation_id, sender_id,
                      (select full_name from users where id = @userId) as sender_name,
                      body, created_at, read_at
            """, new { conversationId, userId, body });

        return new MessageDto(
            (Guid)row.id, (Guid)row.conversation_id, (Guid)row.sender_id, (string)row.sender_name,
            (string)row.body, Time.ToDto((DateTime)row.created_at),
            row.read_at is null ? null : Time.ToDto((DateTime)row.read_at));
    }

    public async Task<Guid> GetOtherUserIdAsync(Guid conversationId, Guid userId, CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync(ct);
        return await conn.ExecuteScalarAsync<Guid>("""
            select case when b.passenger_id = @userId then t.driver_id else b.passenger_id end
            from conversations c
            join bookings b on b.id = c.booking_id
            join trips t on t.id = b.trip_id
            where c.id = @conversationId
            """, new { conversationId, userId });
    }
}
