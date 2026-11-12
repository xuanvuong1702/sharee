namespace Sharee.Api.Infrastructure;

public static class Time
{
    public static DateTimeOffset ToDto(DateTime value)
        => new(DateTime.SpecifyKind(value, DateTimeKind.Utc));

    public static DateTimeOffset? ToDto(DateTime? value)
        => value is null ? null : ToDto(value.Value);
}
