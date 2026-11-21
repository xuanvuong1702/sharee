using Sharee.Api.Services;
using Xunit;

namespace Sharee.Tests;

public class PrivacyTests
{
    [Theory]
    [InlineData("+84912345678", "+849***678")]
    [InlineData("0912345678", "0912***678")]
    [InlineData("", "")]
    [InlineData(null, "")]
    public void Phone_is_masked(string? input, string expected)
        => Assert.Equal(expected, Privacy.MaskPhone(input));

    [Theory]
    [InlineData("minh@example.com", "m***@example.com")]
    [InlineData("a@b.vn", "a***@b.vn")]
    [InlineData(null, null)]
    public void Email_is_masked(string? input, string? expected)
        => Assert.Equal(expected, Privacy.MaskEmail(input));
}
