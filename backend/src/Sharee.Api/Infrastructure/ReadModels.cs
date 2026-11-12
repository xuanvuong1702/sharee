namespace Sharee.Api.Infrastructure;

public sealed class UserRow
{
    public Guid Id { get; set; }
    public string Phone { get; set; } = "";
    public string? Email { get; set; }
    public string FullName { get; set; } = "";
    public string? AvatarUrl { get; set; }
    public string? Bio { get; set; }
    public string Role { get; set; } = "user";
    public string Status { get; set; } = "active";
    public short VerifiedLevel { get; set; }
    public decimal RatingAvg { get; set; }
    public int RatingCount { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

public sealed class VehicleRow
{
    public Guid Id { get; set; }
    public Guid OwnerId { get; set; }
    public string Make { get; set; } = "";
    public string Model { get; set; } = "";
    public short? Year { get; set; }
    public string? Color { get; set; }
    public string Plate { get; set; } = "";
    public short Seats { get; set; }
    public string Status { get; set; } = "active";
}

public sealed class TripRow
{
    public Guid Id { get; set; }
    public Guid DriverId { get; set; }
    public Guid VehicleId { get; set; }
    public double OriginLat { get; set; }
    public double OriginLng { get; set; }
    public double DestinationLat { get; set; }
    public double DestinationLng { get; set; }
    public string OriginLabel { get; set; } = "";
    public string DestinationLabel { get; set; } = "";
    public DateTimeOffset DepartureTime { get; set; }
    public DateTimeOffset ArriveEstimate { get; set; }
    public int PricePerSeat { get; set; }
    public short SeatsTotal { get; set; }
    public short SeatsAvailable { get; set; }
    public string BookingMode { get; set; } = "instant";
    public bool Luggage { get; set; }
    public bool PetsAllowed { get; set; }
    public bool SmokingAllowed { get; set; }
    public string Status { get; set; } = "open";
    public int DistanceM { get; set; }
    public int DurationS { get; set; }
    public string DriverPhone { get; set; } = "";
    public string DriverName { get; set; } = "";
    public string? DriverAvatarUrl { get; set; }
    public string DriverRole { get; set; } = "user";
    public short DriverVerifiedLevel { get; set; }
    public decimal DriverRatingAvg { get; set; }
    public int DriverRatingCount { get; set; }
    public string VehicleMake { get; set; } = "";
    public string VehicleModel { get; set; } = "";
    public short? VehicleYear { get; set; }
    public string? VehicleColor { get; set; }
    public string VehiclePlate { get; set; } = "";
    public short VehicleSeats { get; set; }
    public string VehicleStatus { get; set; } = "active";
}

public sealed class StopRow
{
    public Guid Id { get; set; }
    public Guid TripId { get; set; }
    public short Seq { get; set; }
    public string Name { get; set; } = "";
    public double Lat { get; set; }
    public double Lng { get; set; }
    public int EtaOffsetMin { get; set; }
    public bool AllowPickup { get; set; }
    public bool AllowDropoff { get; set; }
    public int PriceFromOrigin { get; set; }
}

public sealed class BookingRow
{
    public Guid Id { get; set; }
    public Guid TripId { get; set; }
    public Guid PassengerId { get; set; }
    public Guid DriverId { get; set; }
    public Guid FromStopId { get; set; }
    public Guid ToStopId { get; set; }
    public short Seats { get; set; }
    public int PriceTotal { get; set; }
    public int FeeAmount { get; set; }
    public string Status { get; set; } = "";
    public string? IdempotencyKey { get; set; }
    public DateTimeOffset? ExpiresAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public string PassengerName { get; set; } = "";
    public string PassengerPhone { get; set; } = "";
    public string? PassengerAvatarUrl { get; set; }
    public string PassengerRole { get; set; } = "user";
    public short PassengerVerifiedLevel { get; set; }
    public decimal PassengerRatingAvg { get; set; }
    public int PassengerRatingCount { get; set; }
    public string DriverName { get; set; } = "";
    public string DriverPhone { get; set; } = "";
    public string? DriverAvatarUrl { get; set; }
    public string DriverRole { get; set; } = "user";
    public short DriverVerifiedLevel { get; set; }
    public decimal DriverRatingAvg { get; set; }
    public int DriverRatingCount { get; set; }
    public string OriginLabel { get; set; } = "";
    public string DestinationLabel { get; set; } = "";
    public DateTimeOffset DepartureTime { get; set; }
    public string VehicleMake { get; set; } = "";
    public string VehicleModel { get; set; } = "";
    public string VehiclePlate { get; set; } = "";
}

public sealed class PaymentRow
{
    public Guid Id { get; set; }
    public Guid BookingId { get; set; }
    public int Amount { get; set; }
    public string Currency { get; set; } = "VND";
    public string Status { get; set; } = "";
    public string Provider { get; set; } = "mock";
    public DateTimeOffset? CapturedAt { get; set; }
}

public sealed class SearchRow
{
    public Guid TripId { get; set; }
    public DateTimeOffset DepartureTime { get; set; }
    public DateTimeOffset ArriveEstimate { get; set; }
    public short SeatsAvailable { get; set; }
    public string BookingMode { get; set; } = "instant";
    public int SegmentPrice { get; set; }
    public string OriginLabel { get; set; } = "";
    public string DestinationLabel { get; set; } = "";
    public double AccessM { get; set; }

    public Guid PickupId { get; set; }
    public short PickupSeq { get; set; }
    public string PickupName { get; set; } = "";
    public double PickupLat { get; set; }
    public double PickupLng { get; set; }
    public int PickupEta { get; set; }
    public int PickupPrice { get; set; }

    public Guid DropoffId { get; set; }
    public short DropoffSeq { get; set; }
    public string DropoffName { get; set; } = "";
    public double DropoffLat { get; set; }
    public double DropoffLng { get; set; }
    public int DropoffEta { get; set; }
    public int DropoffPrice { get; set; }

    public Guid DriverId { get; set; }
    public string DriverName { get; set; } = "";
    public string DriverPhone { get; set; } = "";
    public string? DriverAvatarUrl { get; set; }
    public string DriverRole { get; set; } = "user";
    public short DriverVerifiedLevel { get; set; }
    public decimal DriverRatingAvg { get; set; }
    public int DriverRatingCount { get; set; }

    public Guid VehicleId { get; set; }
    public string VehicleMake { get; set; } = "";
    public string VehicleModel { get; set; } = "";
    public short? VehicleYear { get; set; }
    public string? VehicleColor { get; set; }
    public string VehiclePlate { get; set; } = "";
    public short VehicleSeats { get; set; }
    public string VehicleStatus { get; set; } = "active";
}
