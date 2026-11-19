using System.Globalization;
using System.Text.Json;
using Microsoft.Extensions.Caching.Memory;
using Sharee.Api.Contracts;

namespace Sharee.Api.Services;

/// <summary>
/// Lightweight geocoding proxy for the ride map. Nominatim/OSM keeps the app
/// key-free for the demo; results are cached and degraded gracefully offline.
/// </summary>
public sealed class GeoService
{
    private static readonly IReadOnlyList<GeoPlaceDto> Fallback =
    [
        new("Bến xe Mỹ Đình", "Bến xe Mỹ Đình, Phạm Hùng, Nam Từ Liêm, Hà Nội", 21.0287, 105.7788, "bus"),
        new("Hồ Hoàn Kiếm", "Hồ Hoàn Kiếm, Hoàn Kiếm, Hà Nội", 21.0285, 105.8523, "attraction"),
        new("Sân bay Nội Bài", "Sân bay Quốc tế Nội Bài, Sóc Sơn, Hà Nội", 21.2187, 105.8042, "airport"),
        new("Phố cổ Hà Nội", "Phố cổ, Hoàn Kiếm, Hà Nội", 21.0341, 105.8500, "attraction"),
        new("Times City", "Times City, Minh Khai, Hai Bà Trưng, Hà Nội", 20.9949, 105.8687, "mall"),
        new("Vincom Bà Triệu", "Vincom Center Bà Triệu, Hai Bà Trưng, Hà Nội", 21.0114, 105.8491, "mall")
    ];

    private readonly IHttpClientFactory _http;
    private readonly IMemoryCache _cache;
    private readonly ILogger<GeoService> _log;
    private readonly SemaphoreSlim _gate = new(1, 1);

    public GeoService(IHttpClientFactory http, IMemoryCache cache, ILogger<GeoService> log)
    {
        _http = http;
        _cache = cache;
        _log = log;
    }

    public async Task<IReadOnlyList<GeoPlaceDto>> SearchAsync(string query, int limit = 6)
    {
        query = (query ?? "").Trim();
        if (query.Length < 2) return [];
        limit = Math.Clamp(limit, 1, 8);
        var key = $"geo:search:{query.ToLowerInvariant()}:{limit}";
        if (_cache.TryGetValue(key, out IReadOnlyList<GeoPlaceDto>? hit) && hit is not null)
            return hit;

        try
        {
            await _gate.WaitAsync();
            try
            {
                var client = _http.CreateClient("geo");
                var url = "https://nominatim.openstreetmap.org/search" +
                          $"?format=jsonv2&q={Uri.EscapeDataString(query)}&countrycodes=vn&limit={limit}&accept-language=vi";
                using var req = new HttpRequestMessage(HttpMethod.Get, url);
                req.Headers.UserAgent.ParseAdd("Sharee/1.3 (ride demo; contact: support@sharee.local)");
                req.Headers.AcceptLanguage.ParseAdd("vi");
                using var res = await client.SendAsync(req);
                if (!res.IsSuccessStatusCode)
                    return FallbackFor(query);

                await using var stream = await res.Content.ReadAsStreamAsync();
                using var doc = await JsonDocument.ParseAsync(stream);
                if (doc.RootElement.ValueKind != JsonValueKind.Array)
                    return FallbackFor(query);

                var list = new List<GeoPlaceDto>();
                foreach (var item in doc.RootElement.EnumerateArray())
                {
                    var full = item.TryGetProperty("display_name", out var dn) ? dn.GetString() ?? "" : "";
                    var name = item.TryGetProperty("name", out var n) ? n.GetString() : null;
                    var lat = ReadDouble(item, "lat");
                    var lon = ReadDouble(item, "lon");
                    if (lat is null || lon is null || full.Length == 0) continue;
                    var kind = item.TryGetProperty("type", out var t) ? t.GetString() : null;
                    var label = string.IsNullOrWhiteSpace(name)
                        ? full.Split(',')[0].Trim()
                        : name!;
                    list.Add(new GeoPlaceDto(label, full, lat.Value, lon.Value, kind));
                }

                var result = list.Count > 0 ? list : FallbackFor(query);
                _cache.Set(key, result, TimeSpan.FromMinutes(10));
                return result;
            }
            finally
            {
                _gate.Release();
            }
        }
        catch (Exception ex)
        {
            _log.LogWarning(ex, "Geocoding search failed for {Query}", query);
            return FallbackFor(query);
        }
    }

    public async Task<GeoPlaceDto> ReverseAsync(double lat, double lng)
    {
        var key = $"geo:reverse:{lat:F5}:{lng:F5}";
        if (_cache.TryGetValue(key, out GeoPlaceDto? hit) && hit is not null)
            return hit;

        try
        {
            await _gate.WaitAsync();
            try
            {
                var client = _http.CreateClient("geo");
                var url = "https://nominatim.openstreetmap.org/reverse" +
                          $"?format=jsonv2&lat={lat.ToString(CultureInfo.InvariantCulture)}&lon={lng.ToString(CultureInfo.InvariantCulture)}&accept-language=vi";
                using var req = new HttpRequestMessage(HttpMethod.Get, url);
                req.Headers.UserAgent.ParseAdd("Sharee/1.3 (ride demo; contact: support@sharee.local)");
                req.Headers.AcceptLanguage.ParseAdd("vi");
                using var res = await client.SendAsync(req);
                if (!res.IsSuccessStatusCode) return new GeoPlaceDto("Vị trí đã chọn", $"{lat:F5}, {lng:F5}", lat, lng, "pin");

                await using var stream = await res.Content.ReadAsStreamAsync();
                using var doc = await JsonDocument.ParseAsync(stream);
                var full = doc.RootElement.TryGetProperty("display_name", out var dn)
                    ? dn.GetString() ?? "Vị trí đã chọn"
                    : "Vị trí đã chọn";
                var name = doc.RootElement.TryGetProperty("name", out var n) ? n.GetString() : null;
                var result = new GeoPlaceDto(
                    string.IsNullOrWhiteSpace(name) ? full.Split(',')[0].Trim() : name!,
                    full, lat, lng, "pin");
                _cache.Set(key, result, TimeSpan.FromHours(6));
                return result;
            }
            finally
            {
                _gate.Release();
            }
        }
        catch (Exception ex)
        {
            _log.LogWarning(ex, "Geocoding reverse failed for {Lat},{Lng}", lat, lng);
            return new GeoPlaceDto("Vị trí đã chọn", $"{lat:F5}, {lng:F5}", lat, lng, "pin");
        }
    }

    private static double? ReadDouble(JsonElement item, string name)
    {
        if (!item.TryGetProperty(name, out var el)) return null;
        return el.ValueKind == JsonValueKind.String
            ? double.TryParse(el.GetString(), NumberStyles.Float, CultureInfo.InvariantCulture, out var d) ? d : null
            : el.TryGetDouble(out var v) ? v : null;
    }

    private static IReadOnlyList<GeoPlaceDto> FallbackFor(string query)
    {
        var q = query.ToLowerInvariant();
        return Fallback.Where(p =>
                p.Label.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                p.FullName.Contains(q, StringComparison.OrdinalIgnoreCase))
            .Take(6)
            .ToList();
    }
}
