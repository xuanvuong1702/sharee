using System.Text;

namespace Sharee.Api.Services;

/// <summary>
/// Builds an EMVCo / VietQR (NAPAS 247) payload. The payload is intentionally
/// generated locally so the app does not depend on a third-party QR image service.
/// </summary>
public static class VietQr
{
    private const string NapasGuid = "A000000727";
    private const string ServiceToAccount = "QRIBFTTA";

    public static string Build(string bankBin, string accountNumber, int? amount, string? addInfo)
    {
        var merchant = Tlv("00", NapasGuid)
            + Tlv("01", Tlv("00", bankBin) + Tlv("01", accountNumber))
            + Tlv("02", ServiceToAccount);

        var payload = new StringBuilder();
        payload.Append(Tlv("00", "01"));       // payload format indicator
        payload.Append(Tlv("01", "12"));       // dynamic QR
        payload.Append(Tlv("38", merchant));
        payload.Append(Tlv("53", "704"));      // VND
        if (amount is > 0) payload.Append(Tlv("54", amount.Value.ToString()));
        payload.Append(Tlv("58", "VN"));
        if (!string.IsNullOrWhiteSpace(addInfo))
            payload.Append(Tlv("62", Tlv("08", Trim(addInfo, 25))));

        var withoutCrc = payload.ToString();
        var crc = Crc16(Encoding.UTF8.GetBytes(withoutCrc + "6304"));
        return $"{withoutCrc}6304{crc:X4}";
    }

    private static string Tlv(string id, string value)
        => $"{id}{value.Length:00}{value}";

    private static string Trim(string value, int max)
    {
        var normalized = value.Trim();
        return normalized.Length <= max ? normalized : normalized[..max];
    }

    private static ushort Crc16(byte[] bytes)
    {
        ushort crc = 0xFFFF;
        foreach (var b in bytes)
        {
            crc ^= (ushort)(b << 8);
            for (var i = 0; i < 8; i++)
                crc = (crc & 0x8000) != 0 ? (ushort)((crc << 1) ^ 0x1021) : (ushort)(crc << 1);
        }
        return crc;
    }
}
