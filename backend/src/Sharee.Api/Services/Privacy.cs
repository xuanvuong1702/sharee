namespace Sharee.Api.Services;

/// <summary>Small PII projection helpers used before returning DTOs.</summary>
public static class Privacy
{
    public static string MaskPhone(string? phone)
    {
        if (string.IsNullOrWhiteSpace(phone)) return "";
        var digits = phone.Trim();
        return digits.Length <= 5
            ? new string('*', digits.Length)
            : $"{digits[..4]}***{digits[^3..]}";
    }

    public static string? MaskEmail(string? email)
    {
        if (string.IsNullOrWhiteSpace(email)) return email;
        var at = email.IndexOf('@');
        if (at <= 0) return "***" + (at == 0 ? email : "");
        return $"{email[0]}***{email[at..]}";
    }
}
