using Sharee.Api.Services;
using Xunit;

namespace Sharee.Tests;

public class PricingTests
{
    [Fact]
    public void Haversine_Hanoi_To_HaiPhong_Is_About_105km()
    {
        // Mỹ Đình (21.0285, 105.7749) -> Lạch Tray (20.8449, 106.6881)
        var meters = Pricing.HaversineMeters(21.0285, 105.7749, 20.8449, 106.6881);
        Assert.InRange(meters, 95_000, 115_000);
    }

    [Fact]
    public void Refund_More_Than_24h_Is_100_Percent()
    {
        var departure = DateTimeOffset.UtcNow.AddHours(30);
        Assert.Equal(100, Pricing.RefundPercent(departure, DateTimeOffset.UtcNow, false));
    }

    [Fact]
    public void Refund_Between_6_And_24h_Is_70_Percent()
    {
        var departure = DateTimeOffset.UtcNow.AddHours(12);
        Assert.Equal(70, Pricing.RefundPercent(departure, DateTimeOffset.UtcNow, false));
    }

    [Fact]
    public void Refund_Under_6h_Is_Zero()
    {
        var departure = DateTimeOffset.UtcNow.AddHours(3);
        Assert.Equal(0, Pricing.RefundPercent(departure, DateTimeOffset.UtcNow, false));
    }

    [Fact]
    public void Driver_Cancel_Always_Refunds_100_Percent()
    {
        var departure = DateTimeOffset.UtcNow.AddHours(1);
        Assert.Equal(100, Pricing.RefundPercent(departure, DateTimeOffset.UtcNow, true));
    }
}
