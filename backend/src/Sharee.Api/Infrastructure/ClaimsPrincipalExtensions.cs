using System.Security.Claims;

namespace Sharee.Api.Infrastructure;

public static class ClaimsPrincipalExtensions
{
    public static Guid GetUserId(this ClaimsPrincipal principal)
    {
        var raw = principal.FindFirstValue("sub") ?? principal.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(raw, out var id)
            ? id
            : throw new UnauthorizedAccessException("Missing user id claim");
    }

    public static bool IsAdmin(this ClaimsPrincipal principal)
        => principal.IsInRole("admin") || principal.FindFirstValue("role") == "admin";
}
