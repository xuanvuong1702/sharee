using Sharee.Api.Services;
using Xunit;

namespace Sharee.Tests;

public class VietQrTests
{
    [Fact]
    public void Payload_Uses_Napas_And_Valid_Crc()
    {
        var payload = VietQr.Build("970436", "0123456789", 50000, "Sharee tip");

        Assert.StartsWith("000201", payload);
        Assert.Contains("A000000727", payload);
        Assert.Contains("970436", payload);
        Assert.Contains("0123456789", payload);
        Assert.Contains("5303704", payload);
        Assert.Contains("540550000", payload);
        Assert.EndsWith("6304" + payload[^4..], payload);
        Assert.Matches("^[0-9A-F]{4}$", payload[^4..]);
    }

    [Fact]
    public void Payload_Without_Amount_Omits_Amount_Field()
    {
        var payload = VietQr.Build("970436", "0123456789", null, null);
        Assert.DoesNotContain("5405", payload);
        Assert.Contains("5802VN", payload);
    }
}
