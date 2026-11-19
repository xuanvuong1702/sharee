namespace Sharee.Api.Contracts;

public record RequestOtpRequest(string Phone);
public record RequestOtpResponse(int ExpiresInSeconds, string? DevCode);
public record VerifyOtpRequest(string Phone, string Code);
public record BootstrapAdminRequest(string Phone, string? FullName = null);
public record RegisterDeviceRequest(string Token, string Platform);
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
    long Gmv, int ActiveTrips, int DailyTickets, long EscrowHeld, int OpenAppeals,
    int VerifiedDrivers);

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

public record EarningItemDto(
    string Type, string Title, int Amount, string Currency, DateTimeOffset At);

public record EarningsDto(
    int TripEarnings, int CompletedTrips, long DailyEarningsMinor, int DailyValidations,
    IReadOnlyList<EarningItemDto> Recent,
    int TipEarnings = 0, int TipCount = 0, int PendingTips = 0);

public record TipAccountDto(
    Guid DriverId, string BankBin, string BankName, string AccountNumber,
    string AccountName, string QrPayload);

public record SetTipAccountRequest(
    string BankBin, string? BankName, string AccountNumber, string AccountName);

public record CreateTipRequest(int Amount, string? Message, string PaymentMethod);

public record TipDto(
    Guid Id, Guid BookingId, Guid TripId, string PassengerName, string DriverName,
    int Amount, string? Message, string Method, string Status,
    DateTimeOffset CreatedAt, DateTimeOffset? SentAt, DateTimeOffset? ConfirmedAt);

public record BookingTipInfoDto(TipAccountDto? Account, TipDto? ExistingTip, string? QrPayload);

public record CreateTipResponse(TipDto Tip, TipAccountDto? Account, string? QrPayload);

public record TipSummaryDto(
    int TotalConfirmed, int CountConfirmed, int CountPending,
    IReadOnlyList<TipDto> Recent);

public record VerificationDocumentDto(
    Guid Id, string Type, string OriginalName, string MimeType, int SizeBytes,
    DateTimeOffset CreatedAt);

public record VerificationStatusDto(
    string Status, int Level, DateTimeOffset? ExpiresAt, DateTimeOffset? SubmittedAt,
    DateTimeOffset? ReviewedAt, string? RejectionReason, string? LegalName,
    DateOnly? DateOfBirth, string? IdNumber, DateOnly? IdIssuedAt, DateOnly? IdExpiry,
    string? LicenseNumber, string? LicenseClass, DateOnly? LicenseExpiry,
    string? VehicleRegistration, DateOnly? InsuranceExpiry,
    IReadOnlyList<VerificationDocumentDto> Documents,
    IReadOnlyList<string> RequiredDocuments);

public record UpdateVerificationProfileRequest(
    string LegalName, DateOnly? DateOfBirth, string IdNumber, DateOnly? IdIssuedAt,
    DateOnly? IdExpiry, string LicenseNumber, string LicenseClass, DateOnly? LicenseExpiry,
    string VehicleRegistration, DateOnly? InsuranceExpiry);

public record ApproveVerificationRequest(DateOnly? ExpiresAt);
public record RejectVerificationRequest(string Reason);

public record VerificationQueueItemDto(
    Guid UserId, string FullName, string Phone, string Status, int Level,
    string? LegalName, string? IdNumber, string? LicenseNumber,
    DateOnly? LicenseExpiry, DateOnly? InsuranceExpiry, int DocumentCount,
    DateTimeOffset? SubmittedAt, DateTimeOffset? ExpiresAt);

public record EscrowDto(
    Guid BookingId, int Amount, string Currency, string Method, string Status,
    DateTimeOffset HeldAt, DateTimeOffset? ReleasedAt);

public record SetPaymentMethodRequest(string Method);

public record CreateAppealRequest(string Reason, string Description);

public record AppealEvidenceDto(
    Guid Id, string OriginalName, string MimeType, int SizeBytes, string UploaderName,
    DateTimeOffset CreatedAt);

public record AppealDto(
    Guid Id, Guid BookingId, Guid OpenedBy, string OpenedByName, Guid AgainstId,
    string AgainstName, string Reason, string Description, string Status,
    string? Resolution, string? ResolutionNote, DateTimeOffset CreatedAt,
    DateTimeOffset? ResolvedAt, IReadOnlyList<AppealEvidenceDto> Evidence);

public record ResolveAppealRequest(string Outcome, string Note);

public record ReputationDto(
    Guid UserId, string FullName, string? AvatarUrl, double Rating, int ReviewCount,
    int CompletedAsDriver, int CompletedAsPassenger, int CancelledAsDriver,
    int CancelledAsPassenger, int TotalOrders, int CompletionRate, int Score,
    string Tier, IReadOnlyList<string> Badges);

public record LocationUpdateRequest(
    double Lat, double Lng, double? Heading = null, double? Speed = null, double? Accuracy = null);

public record TrackingStatusRequest(string Status);

public record LivePositionDto(
    Guid UserId, string FullName, string Role, double Lat, double Lng,
    double? Heading, double? Speed, DateTimeOffset UpdatedAt);

public record LatLngDto(double Lat, double Lng);

public record TripTrackingDto(
    Guid TripId, Guid DriverId, string Status, string TrackingStatus, string DriverName, string DriverPhone,
    VehicleDto Vehicle, StopDto Pickup, StopDto Dropoff, IReadOnlyList<LatLngDto> Route,
    LivePositionDto? Driver, IReadOnlyList<LivePositionDto> Passengers,
    int EtaMinutes, double DistanceKm, DateTimeOffset? StartedAt);

public record GeoPlaceDto(
    string Label, string FullName, double Lat, double Lng, string? Kind);

public record NearbyDriverDto(
    Guid DriverId, string FullName, double Rating, int RatingCount,
    string? VehicleLabel, string? Plate, double Lat, double Lng, int EtaMinutes);

public record DriverPresenceDto(
    bool Online, double Lat, double Lng, Guid? VehicleId, DateTimeOffset UpdatedAt);

public record UpdateDriverPresenceRequest(bool Online, double Lat, double Lng, Guid? VehicleId);

public record RideDriverDto(
    Guid Id, string FullName, string? AvatarUrl, double Rating, int RatingCount,
    string VehicleLabel, string? Plate, string? Color, string? PhoneMasked);

public record CreateRideRequestDto(
    string PickupLabel, double PickupLat, double PickupLng,
    string DropoffLabel, double DropoffLat, double DropoffLng,
    string VehicleClass, string PaymentMethod, string? Note);

public record CancelRideRequest(string? Reason);

public record RideDto(
    Guid Id, Guid PassengerId, string PassengerName, double? PassengerRating,
    string PickupLabel, double PickupLat, double PickupLng,
    string DropoffLabel, double DropoffLat, double DropoffLng,
    string VehicleClass, string PaymentMethod, string? Note, string Status,
    RideDriverDto? Driver, DateTimeOffset CreatedAt, DateTimeOffset? AcceptedAt,
    DateTimeOffset? ArrivedAt, DateTimeOffset? StartedAt, DateTimeOffset? CompletedAt);
