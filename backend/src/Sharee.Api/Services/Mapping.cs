using Sharee.Api.Contracts;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Services;

public static class Mapping
{
    public static UserDto ToUser(this UserRow r) => new(
        r.Id, r.Phone, r.FullName, r.Email, r.AvatarUrl, r.Bio, r.Role,
        r.VerifiedLevel, r.RatingAvg, r.RatingCount);

    public static UserDto ToDriver(this TripRow r) => new(
        r.DriverId, Privacy.MaskPhone(r.DriverPhone), r.DriverName, null, r.DriverAvatarUrl, null, r.DriverRole,
        r.DriverVerifiedLevel, r.DriverRatingAvg, r.DriverRatingCount);

    public static VehicleDto ToVehicle(this TripRow r) => new(
        r.VehicleId, r.VehicleMake, r.VehicleModel, r.VehicleYear, r.VehicleColor,
        r.VehiclePlate, r.VehicleSeats, r.VehicleStatus);

    public static VehicleDto ToVehicle(this VehicleRow r) => new(
        r.Id, r.Make, r.Model, r.Year, r.Color, r.Plate, r.Seats, r.Status);

    public static StopDto ToStop(this StopRow r) => new(
        r.Id, r.Seq, r.Name, r.Lat, r.Lng, r.EtaOffsetMin,
        r.AllowPickup, r.AllowDropoff, r.PriceFromOrigin);

    public static TripDto ToTrip(this TripRow r, IReadOnlyList<StopRow> stops) => new(
        r.Id, r.ToDriver(), r.ToVehicle(),
        new PlaceDto(r.OriginLat, r.OriginLng, r.OriginLabel),
        new PlaceDto(r.DestinationLat, r.DestinationLng, r.DestinationLabel),
        r.DepartureTime, r.ArriveEstimate, r.PricePerSeat,
        r.SeatsTotal, r.SeatsAvailable, r.BookingMode,
        r.Luggage, r.PetsAllowed, r.SmokingAllowed, r.Status,
        stops.Select(s => s.ToStop()).ToList());

    public static TripSummaryDto ToSummary(this TripRow r) => new(
        r.Id, r.OriginLabel, r.DestinationLabel, r.DepartureTime,
        r.DriverName, $"{r.VehicleMake} {r.VehicleModel}", r.VehiclePlate);

    public static PaymentDto ToPayment(this PaymentRow r) => new(
        r.Id, r.BookingId, r.Amount, r.Currency, r.Status, r.Provider, r.CapturedAt);
}
