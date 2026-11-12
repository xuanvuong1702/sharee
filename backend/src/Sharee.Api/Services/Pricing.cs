using Dapper;
using Npgsql;

namespace Sharee.Api.Services;

public static class Pricing
{
    private const double EarthRadiusMeters = 6_371_000;

    public static double HaversineMeters(double lat1, double lng1, double lat2, double lng2)
    {
        static double Rad(double d) => d * Math.PI / 180;
        var dLat = Rad(lat2 - lat1);
        var dLng = Rad(lng2 - lng1);
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(Rad(lat1)) * Math.Cos(Rad(lat2)) *
                Math.Sin(dLng / 2) * Math.Sin(dLng / 2);
        return 2 * EarthRadiusMeters * Math.Asin(Math.Min(1, Math.Sqrt(a)));
    }

    public static int RefundPercent(DateTimeOffset departure, DateTimeOffset now, bool driverCancelled)
    {
        if (driverCancelled) return 100;
        var hours = (departure - now).TotalHours;
        if (hours > 24) return 100;
        if (hours >= 6) return 70;
        return 0;
    }
}

public static class Notifier
{
    public static Task NotifyAsync(
        NpgsqlConnection conn,
        NpgsqlTransaction? tx,
        Guid userId,
        string type,
        string title,
        string body)
    {
        return conn.ExecuteAsync("""
            insert into notifications (user_id, type, title, body)
            values (@userId, @type, @title, @body)
            """, new { userId, type, title, body }, tx);
    }
}
