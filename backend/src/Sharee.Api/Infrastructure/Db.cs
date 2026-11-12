using Npgsql;

namespace Sharee.Api.Infrastructure;

public sealed class Db(NpgsqlDataSource dataSource)
{
    public async Task<NpgsqlConnection> OpenAsync(CancellationToken ct = default)
        => await dataSource.OpenConnectionAsync(ct);
}
