namespace Sharee.Api.Contracts;

public record RequestOtpRequest(string Phone);
public record RequestOtpResponse(int ExpiresInSeconds, string? DevCode);
public record VerifyOtpRequest(string Phone, string Code);
public record RefreshRequest(string RefreshToken);
public record AuthResponse(string AccessToken, string RefreshToken, UserDto User);

public record UserDto(
    Guid Id, string Phone, string FullName, string? Email, string? AvatarUrl,
    string? Bio, string Role, short VerifiedLevel, decimal RatingAvg, int RatingCount);

public record UpdateProfileRequest(string? FullName, string? Email, string? Bio, string? AvatarUrl);

public record VehicleDto(
    Guid Id, string Make, string Model, int? Year, string? Color, string Plate, short Seats, string Status);

public record CreateVehicleRequest(string Make, string Model, int? Year, string? Color, string Plate, short Seats);

public record StopDto(
    Guid Id, int Seq, string Name, double Lat, double Lng,
    int EtaOffsetMin, bool AllowPickup, bool AllowDropoff, int PriceFromOrigin);

public record PlaceDto(double Lat, double Lng, string Label);

public record TripDto(
    Guid Id, UserDto Driver, VehicleDto Vehicle, PlaceDto Origin, PlaceDto Destination,
    DateTimeOffset DepartureTime, DateTimeOffset ArriveEstimate, int PricePerSeat,
    short SeatsTotal, short SeatsAvailable, string BookingMode,
    bool Luggage, bool PetsAllowed, bool SmokingAllowed, string Status,
    IReadOnlyList<StopDto> Stops);

public record CreateTripRequest(
    Guid VehicleId, PlaceDto Origin, PlaceDto Destination, DateTimeOffset DepartureTime,
    int PricePerSeat, short SeatsTotal, string BookingMode,
    bool Luggage, bool PetsAllowed, bool SmokingAllowed, List<CreateStopRequest> Stops);

public record CreateStopRequest(string Name, double Lat, double Lng, bool AllowPickup, bool AllowDropoff);

public record SearchResultDto(
    Guid TripId, UserDto Driver, VehicleDto Vehicle, string OriginLabel, string DestinationLabel,
    DateTimeOffset DepartureTime, DateTimeOffset ArriveEstimate, int PricePerSeat, short SeatsAvailable,
    StopDto PickupStop, StopDto DropoffStop, double AccessMeters, string BookingMode);

public record SearchResponse(IReadOnlyList<SearchResultDto> Items, int Count);

public record TripSummaryDto(
    Guid Id, string OriginLabel, string DestinationLabel, DateTimeOffset DepartureTime,
    string DriverName, string Vehicle, string Plate);

public record CreateBookingRequest(short Seats, Guid FromStopId, Guid ToStopId);

public record BookingDto(
    Guid Id, Guid TripId, UserDto Passenger, UserDto Driver, StopDto FromStop, StopDto ToStop,
    short Seats, int PriceTotal, string Status, DateTimeOffset? ExpiresAt, DateTimeOffset CreatedAt,
    TripSummaryDto Trip, PaymentDto? Payment);

public record PaymentDto(
    Guid Id, Guid BookingId, int Amount, string Currency, string Status, string Provider,
    DateTimeOffset? CapturedAt);

public record CreateReviewRequest(short Rating, string? Comment);

public record ReviewDto(
    Guid Id, Guid BookingId, Guid ReviewerId, string ReviewerName, Guid RevieweeId,
    short Rating, string? Comment, string Role, DateTimeOffset CreatedAt);

public record UserProfileDto(UserDto User, IReadOnlyList<ReviewDto> Reviews, int TripsCompleted);

public record ConversationDto(
    Guid Id, Guid BookingId, UserDto Other, string? LastMessage, DateTimeOffset? LastAt,
    int Unread, TripSummaryDto Trip);

public record MessageDto(
    Guid Id, Guid ConversationId, Guid SenderId, string SenderName, string Body,
    DateTimeOffset CreatedAt, DateTimeOffset? ReadAt);

public record SendMessageRequest(string Body);

public record ReportDto(
    Guid Id, Guid ReporterId, string ReporterName, string TargetType, Guid TargetId,
    string Reason, string? Description, string Status, DateTimeOffset CreatedAt);

public record CreateReportRequest(string TargetType, Guid TargetId, string Reason, string? Description);

public record LineStopDto(Guid Id, int Seq, string Name, double Lat, double Lng, string QrToken);

public record LineDto(
    Guid Id, string Name, string? Brand, string? Description, double? DistanceMeters,
    int StopsCount, IReadOnlyList<LineStopDto>? Stops,
    IReadOnlyList<ServiceWindowDto>? Windows);

public record ServiceWindowDto(int Weekday, string StartTime, string EndTime, int HeadwayMin);

public record ETicketDto(
    Guid Id, Guid LineId, string LineName, Guid StopId, string StopName, string Status,
    string Code, string QrToken, DateTimeOffset CreatedAt, DateTimeOffset ExpiresAt,
    Guid? DriverId, string? DriverName, DateTimeOffset? ValidatedAt, long? AmountMinor,
    string? PassengerName = null);

public record CreateETicketRequest(Guid LineId, Guid StopId);
public record ValidateTicketRequest(string Code);

public record AdminDashboardDto(
    int Users, int Trips, int Bookings, int OpenReports, int PendingVerifications,
    long Gmv, int ActiveTrips, int DailyTickets);

public record VerificationDto(
    Guid Id, Guid UserId, string UserName, string Phone, string Type, string Status,
    string? DocumentRef, DateTimeOffset CreatedAt);

public record AuditDto(
    long Id, string? ActorName, string Action, string? TargetType, string? TargetId,
    DateTimeOffset CreatedAt);

public record NotificationDto(
    Guid Id, string Type, string Title, string Body, DateTimeOffset CreatedAt, DateTimeOffset? ReadAt);

public record RecurringTripDto(
    Guid Id, string OriginLabel, string DestinationLabel, string DepartureTime,
    int[] Weekdays, int PricePerSeat, int SeatsTotal, bool Active, int UpcomingTrips);

public record CreateRecurringTripRequest(
    Guid VehicleId, PlaceDto Origin, PlaceDto Destination, string DepartureTime,
    int[] Weekdays, int PricePerSeat, short SeatsTotal, string BookingMode,
    bool Luggage, bool PetsAllowed, bool SmokingAllowed, List<CreateStopRequest> Stops);
