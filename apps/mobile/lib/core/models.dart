class AppUser {
  final String id;
  final String phone;
  final String fullName;
  final String? avatarUrl;
  final String role;
  final int verifiedLevel;
  final double ratingAvg;
  final int ratingCount;

  const AppUser({
    required this.id,
    required this.phone,
    required this.fullName,
    this.avatarUrl,
    required this.role,
    required this.verifiedLevel,
    required this.ratingAvg,
    required this.ratingCount,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        phone: json['phone'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String?,
        role: json['role'] as String? ?? 'user',
        verifiedLevel: (json['verifiedLevel'] as num?)?.toInt() ?? 0,
        ratingAvg: (json['ratingAvg'] as num?)?.toDouble() ?? 0,
        ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      );

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

class Vehicle {
  final String id;
  final String make;
  final String model;
  final String plate;
  final int seats;

  const Vehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.plate,
    required this.seats,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['id'] as String,
        make: json['make'] as String? ?? '',
        model: json['model'] as String? ?? '',
        plate: json['plate'] as String? ?? '',
        seats: (json['seats'] as num?)?.toInt() ?? 4,
      );

  String get label {
    final name = [make, model].where((part) => part.trim().isNotEmpty).join(' ');
    return name.isEmpty ? plate : '$name · $plate';
  }
}

class Stop {
  final String id;
  final int seq;
  final String name;
  final double lat;
  final double lng;
  final int priceFromOrigin;
  final bool allowPickup;
  final bool allowDropoff;

  const Stop({
    required this.id,
    required this.seq,
    required this.name,
    required this.lat,
    required this.lng,
    required this.priceFromOrigin,
    required this.allowPickup,
    required this.allowDropoff,
  });

  factory Stop.fromJson(Map<String, dynamic> json) => Stop(
        id: json['id'] as String,
        seq: (json['seq'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        lat: (json['lat'] as num?)?.toDouble() ?? 0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0,
        priceFromOrigin: (json['priceFromOrigin'] as num?)?.toInt() ?? 0,
        allowPickup: json['allowPickup'] as bool? ?? false,
        allowDropoff: json['allowDropoff'] as bool? ?? false,
      );
}

class Trip {
  final String id;
  final AppUser driver;
  final Vehicle vehicle;
  final String originLabel;
  final String destinationLabel;
  final DateTime departureTime;
  final DateTime arriveEstimate;
  final int pricePerSeat;
  final int seatsTotal;
  final int seatsAvailable;
  final String bookingMode;
  final String status;
  final List<Stop> stops;

  const Trip({
    required this.id,
    required this.driver,
    required this.vehicle,
    required this.originLabel,
    required this.destinationLabel,
    required this.departureTime,
    required this.arriveEstimate,
    required this.pricePerSeat,
    required this.seatsTotal,
    required this.seatsAvailable,
    required this.bookingMode,
    required this.status,
    required this.stops,
  });

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        id: json['id'] as String,
        driver: AppUser.fromJson(json['driver'] as Map<String, dynamic>),
        vehicle: Vehicle.fromJson(json['vehicle'] as Map<String, dynamic>),
        originLabel: (json['origin'] as Map<String, dynamic>)['label'] as String? ?? '',
        destinationLabel: (json['destination'] as Map<String, dynamic>)['label'] as String? ?? '',
        departureTime: DateTime.parse(json['departureTime'] as String),
        arriveEstimate: DateTime.parse(json['arriveEstimate'] as String),
        pricePerSeat: (json['pricePerSeat'] as num?)?.toInt() ?? 0,
        seatsTotal: (json['seatsTotal'] as num?)?.toInt() ?? 0,
        seatsAvailable: (json['seatsAvailable'] as num?)?.toInt() ?? 0,
        bookingMode: json['bookingMode'] as String? ?? 'instant',
        status: json['status'] as String? ?? 'open',
        stops: (json['stops'] as List<dynamic>? ?? [])
            .map((e) => Stop.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SearchResult {
  final String tripId;
  final AppUser driver;
  final Vehicle vehicle;
  final String originLabel;
  final String destinationLabel;
  final DateTime departureTime;
  final DateTime arriveEstimate;
  final int pricePerSeat;
  final int seatsAvailable;
  final Stop pickupStop;
  final Stop dropoffStop;
  final String bookingMode;

  const SearchResult({
    required this.tripId,
    required this.driver,
    required this.vehicle,
    required this.originLabel,
    required this.destinationLabel,
    required this.departureTime,
    required this.arriveEstimate,
    required this.pricePerSeat,
    required this.seatsAvailable,
    required this.pickupStop,
    required this.dropoffStop,
    required this.bookingMode,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        tripId: json['tripId'] as String,
        driver: AppUser.fromJson(json['driver'] as Map<String, dynamic>),
        vehicle: Vehicle.fromJson(json['vehicle'] as Map<String, dynamic>),
        originLabel: json['originLabel'] as String? ?? '',
        destinationLabel: json['destinationLabel'] as String? ?? '',
        departureTime: DateTime.parse(json['departureTime'] as String),
        arriveEstimate: DateTime.parse(json['arriveEstimate'] as String),
        pricePerSeat: (json['pricePerSeat'] as num?)?.toInt() ?? 0,
        seatsAvailable: (json['seatsAvailable'] as num?)?.toInt() ?? 0,
        pickupStop: Stop.fromJson(json['pickupStop'] as Map<String, dynamic>),
        dropoffStop: Stop.fromJson(json['dropoffStop'] as Map<String, dynamic>),
        bookingMode: json['bookingMode'] as String? ?? 'instant',
      );
}

class Payment {
  final String id;
  final int amount;
  final String status;

  const Payment({required this.id, required this.amount, required this.status});

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['id'] as String,
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? '',
      );
}

class Booking {
  final String id;
  final String tripId;
  final AppUser passenger;
  final AppUser driver;
  final Stop fromStop;
  final Stop toStop;
  final int seats;
  final int priceTotal;
  final String status;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final String originLabel;
  final String destinationLabel;
  final DateTime departureTime;
  final Vehicle vehicle;
  final Payment? payment;

  const Booking({
    required this.id,
    required this.tripId,
    required this.passenger,
    required this.driver,
    required this.fromStop,
    required this.toStop,
    required this.seats,
    required this.priceTotal,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    required this.originLabel,
    required this.destinationLabel,
    required this.departureTime,
    required this.vehicle,
    required this.payment,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final trip = json['trip'] as Map<String, dynamic>? ?? {};
    return Booking(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      passenger: AppUser.fromJson(json['passenger'] as Map<String, dynamic>),
      driver: AppUser.fromJson(json['driver'] as Map<String, dynamic>),
      fromStop: Stop.fromJson(json['fromStop'] as Map<String, dynamic>),
      toStop: Stop.fromJson(json['toStop'] as Map<String, dynamic>),
      seats: (json['seats'] as num?)?.toInt() ?? 0,
      priceTotal: (json['priceTotal'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      expiresAt: json['expiresAt'] == null ? null : DateTime.parse(json['expiresAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      originLabel: trip['originLabel'] as String? ?? '',
      destinationLabel: trip['destinationLabel'] as String? ?? '',
      departureTime: DateTime.parse(trip['departureTime'] as String),
      vehicle: Vehicle(
        id: '',
        make: '',
        model: trip['vehicle'] as String? ?? '',
        plate: trip['plate'] as String? ?? '',
        seats: 4,
      ),
      payment: json['payment'] == null
          ? null
          : Payment.fromJson(json['payment'] as Map<String, dynamic>),
    );
  }

  bool get needsPayment => status == 'pending_payment';
  bool get confirmed => status == 'confirmed' || status == 'completed';
}

class ChatThread {
  final String id;
  final AppUser other;
  final String? lastMessage;
  final DateTime? lastAt;
  final int unread;
  final String originLabel;
  final String destinationLabel;

  const ChatThread({
    required this.id,
    required this.other,
    required this.lastMessage,
    required this.lastAt,
    required this.unread,
    required this.originLabel,
    required this.destinationLabel,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    final trip = json['trip'] as Map<String, dynamic>? ?? {};
    return ChatThread(
      id: json['id'] as String,
      other: AppUser.fromJson(json['other'] as Map<String, dynamic>),
      lastMessage: json['lastMessage'] as String?,
      lastAt: json['lastAt'] == null ? null : DateTime.parse(json['lastAt'] as String),
      unread: (json['unread'] as num?)?.toInt() ?? 0,
      originLabel: trip['originLabel'] as String? ?? '',
      destinationLabel: trip['destinationLabel'] as String? ?? '',
    );
  }
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String body;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.body,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        conversationId: json['conversationId'] as String? ?? '',
        senderId: json['senderId'] as String,
        senderName: json['senderName'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class LineStop {
  final String id;
  final int seq;
  final String name;
  final double lat;
  final double lng;

  const LineStop({
    required this.id,
    required this.seq,
    required this.name,
    required this.lat,
    required this.lng,
  });

  factory LineStop.fromJson(Map<String, dynamic> json) => LineStop(
        id: json['id'] as String,
        seq: (json['seq'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        lat: (json['lat'] as num?)?.toDouble() ?? 0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0,
      );
}

class Line {
  final String id;
  final String name;
  final String? brand;
  final String? description;
  final double? distanceMeters;
  final int stopsCount;
  final List<LineStop> stops;

  const Line({
    required this.id,
    required this.name,
    this.brand,
    this.description,
    this.distanceMeters,
    required this.stopsCount,
    required this.stops,
  });

  factory Line.fromJson(Map<String, dynamic> json) => Line(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        brand: json['brand'] as String?,
        description: json['description'] as String?,
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
        stopsCount: (json['stopsCount'] as num?)?.toInt() ?? 0,
        stops: (json['stops'] as List<dynamic>? ?? [])
            .map((e) => LineStop.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ETicket {
  final String id;
  final String lineName;
  final String stopName;
  final String status;
  final String code;
  final DateTime expiresAt;
  final String? driverName;
  final int? amountMinor;
  final String? passengerName;

  const ETicket({
    required this.id,
    required this.lineName,
    required this.stopName,
    required this.status,
    required this.code,
    required this.expiresAt,
    this.driverName,
    this.amountMinor,
    this.passengerName,
  });

  factory ETicket.fromJson(Map<String, dynamic> json) => ETicket(
        id: json['id'] as String,
        lineName: json['lineName'] as String? ?? '',
        stopName: json['stopName'] as String? ?? '',
        status: json['status'] as String? ?? '',
        code: json['code'] as String? ?? '',
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        driverName: json['driverName'] as String?,
        amountMinor: (json['amountMinor'] as num?)?.toInt(),
        passengerName: json['passengerName'] as String?,
      );
}

class AppNotification {  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        readAt: json['readAt'] == null ? null : DateTime.parse(json['readAt'] as String),
      );

  bool get unread => readAt == null;
}

class RecurringTrip {
  final String id;
  final String originLabel;
  final String destinationLabel;
  final String departureTime;
  final List<int> weekdays;
  final int pricePerSeat;
  final int seatsTotal;
  final bool active;
  final int upcomingTrips;

  const RecurringTrip({
    required this.id,
    required this.originLabel,
    required this.destinationLabel,
    required this.departureTime,
    required this.weekdays,
    required this.pricePerSeat,
    required this.seatsTotal,
    required this.active,
    required this.upcomingTrips,
  });

  factory RecurringTrip.fromJson(Map<String, dynamic> json) => RecurringTrip(
        id: json['id'] as String,
        originLabel: json['originLabel'] as String? ?? '',
        destinationLabel: json['destinationLabel'] as String? ?? '',
        departureTime: json['departureTime'] as String? ?? '',
        weekdays: (json['weekdays'] as List<dynamic>? ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
        pricePerSeat: (json['pricePerSeat'] as num?)?.toInt() ?? 0,
        seatsTotal: (json['seatsTotal'] as num?)?.toInt() ?? 0,
        active: json['active'] as bool? ?? true,
        upcomingTrips: (json['upcomingTrips'] as num?)?.toInt() ?? 0,
      );

  String get weekdayLabel {
    const names = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final sorted = [...weekdays]..sort();
    return sorted.map((d) => d >= 1 && d <= 7 ? names[d - 1] : '').join(' · ');
  }
}

class EarningItem {
  final String type;
  final String title;
  final int amount;
  final String currency;
  final DateTime at;

  const EarningItem({
    required this.type,
    required this.title,
    required this.amount,
    required this.currency,
    required this.at,
  });

  factory EarningItem.fromJson(Map<String, dynamic> json) => EarningItem(
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        currency: json['currency'] as String? ?? 'VND',
        at: DateTime.parse(json['at'] as String),
      );
}

class Earnings {
  final int tripEarnings;
  final int completedTrips;
  final int dailyEarningsMinor;
  final int dailyValidations;
  final int tipEarnings;
  final int tipCount;
  final int pendingTips;
  final List<EarningItem> recent;

  const Earnings({
    required this.tripEarnings,
    required this.completedTrips,
    required this.dailyEarningsMinor,
    required this.dailyValidations,
    required this.recent,
    this.tipEarnings = 0,
    this.tipCount = 0,
    this.pendingTips = 0,
  });

  factory Earnings.fromJson(Map<String, dynamic> json) => Earnings(
        tripEarnings: (json['tripEarnings'] as num?)?.toInt() ?? 0,
        completedTrips: (json['completedTrips'] as num?)?.toInt() ?? 0,
        dailyEarningsMinor: (json['dailyEarningsMinor'] as num?)?.toInt() ?? 0,
        dailyValidations: (json['dailyValidations'] as num?)?.toInt() ?? 0,
        tipEarnings: (json['tipEarnings'] as num?)?.toInt() ?? 0,
        tipCount: (json['tipCount'] as num?)?.toInt() ?? 0,
        pendingTips: (json['pendingTips'] as num?)?.toInt() ?? 0,
        recent: (json['recent'] as List<dynamic>? ?? [])
            .map((e) => EarningItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class LatLngPoint {
  final double lat;
  final double lng;
  const LatLngPoint(this.lat, this.lng);
  factory LatLngPoint.fromJson(Map<String, dynamic> json) =>
      LatLngPoint((json['lat'] as num).toDouble(), (json['lng'] as num).toDouble());
}

class LivePosition {
  final String userId;
  final String fullName;
  final String role;
  final double lat;
  final double lng;
  final double? heading;
  final double? speed;
  final DateTime updatedAt;

  const LivePosition({
    required this.userId,
    required this.fullName,
    required this.role,
    required this.lat,
    required this.lng,
    this.heading,
    this.speed,
    required this.updatedAt,
  });

  factory LivePosition.fromJson(Map<String, dynamic> json) => LivePosition(
        userId: json['userId'] as String,
        fullName: json['fullName'] as String? ?? '',
        role: json['role'] as String? ?? '',
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        heading: (json['heading'] as num?)?.toDouble(),
        speed: (json['speed'] as num?)?.toDouble(),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

class TripTracking {
  final String tripId;
  final String driverId;
  final String status;  final String trackingStatus;
  final String driverName;
  final String driverPhone;
  final Vehicle vehicle;
  final Stop pickup;
  final Stop dropoff;
  final List<LatLngPoint> route;
  final LivePosition? driver;
  final List<LivePosition> passengers;
  final int etaMinutes;
  final double distanceKm;
  final DateTime? startedAt;

  const TripTracking({
    required this.tripId,
    required this.driverId,
    required this.status,
    required this.trackingStatus,
    required this.driverName,
    required this.driverPhone,
    required this.vehicle,
    required this.pickup,
    required this.dropoff,
    required this.route,
    required this.driver,
    required this.passengers,
    required this.etaMinutes,
    required this.distanceKm,
    required this.startedAt,
  });

  factory TripTracking.fromJson(Map<String, dynamic> json) => TripTracking(
        tripId: json['tripId'] as String,
        driverId: json['driverId'] as String? ?? '',
        status: json['status'] as String? ?? '',
        trackingStatus: json['trackingStatus'] as String? ?? 'scheduled',
        driverName: json['driverName'] as String? ?? '',
        driverPhone: json['driverPhone'] as String? ?? '',
        vehicle: Vehicle.fromJson(json['vehicle'] as Map<String, dynamic>),
        pickup: Stop.fromJson(json['pickup'] as Map<String, dynamic>),
        dropoff: Stop.fromJson(json['dropoff'] as Map<String, dynamic>),
        route: (json['route'] as List<dynamic>? ?? [])
            .map((e) => LatLngPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        driver: json['driver'] == null
            ? null
            : LivePosition.fromJson(json['driver'] as Map<String, dynamic>),
        passengers: (json['passengers'] as List<dynamic>? ?? [])
            .map((e) => LivePosition.fromJson(e as Map<String, dynamic>))
            .toList(),
        etaMinutes: (json['etaMinutes'] as num?)?.toInt() ?? 0,
        distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
        startedAt: json['startedAt'] == null ? null : DateTime.parse(json['startedAt'] as String),
      );

  bool get active => trackingStatus != 'completed';
}

class PaymentConfig {
  final String provider;
  final bool enabled;

  const PaymentConfig({required this.provider, required this.enabled});

  factory PaymentConfig.fromJson(Map<String, dynamic> json) => PaymentConfig(
        provider: json['provider'] as String? ?? 'mock',
        enabled: json['enabled'] as bool? ?? false,
      );

  bool get isPayOs => provider == 'payos';
}

class PayOsCheckout {
  final int orderCode;
  final int amount;
  final String description;
  final String checkoutUrl;
  final String qrCode;
  final String paymentLinkId;
  final DateTime expiresAt;

  const PayOsCheckout({
    required this.orderCode,
    required this.amount,
    required this.description,
    required this.checkoutUrl,
    required this.qrCode,
    required this.paymentLinkId,
    required this.expiresAt,
  });

  factory PayOsCheckout.fromJson(Map<String, dynamic> json) => PayOsCheckout(
        orderCode: (json['orderCode'] as num?)?.toInt() ?? 0,
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        description: json['description'] as String? ?? '',
        checkoutUrl: json['checkoutUrl'] as String? ?? '',
        qrCode: json['qrCode'] as String? ?? '',
        paymentLinkId: json['paymentLinkId'] as String? ?? '',
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}

class TipAccount {
  final String driverId;
  final String bankBin;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String qrPayload;

  const TipAccount({
    required this.driverId,
    required this.bankBin,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.qrPayload,
  });

  factory TipAccount.fromJson(Map<String, dynamic> json) => TipAccount(
        driverId: json['driverId'] as String? ?? '',
        bankBin: json['bankBin'] as String? ?? '',
        bankName: json['bankName'] as String? ?? '',
        accountNumber: json['accountNumber'] as String? ?? '',
        accountName: json['accountName'] as String? ?? '',
        qrPayload: json['qrPayload'] as String? ?? '',
      );
}

class DriverTip {
  final String id;
  final String bookingId;
  final String tripId;
  final String passengerName;
  final String driverName;
  final int amount;
  final String? message;
  final String method;
  final String status;
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? confirmedAt;

  const DriverTip({
    required this.id,
    required this.bookingId,
    required this.tripId,
    required this.passengerName,
    required this.driverName,
    required this.amount,
    required this.message,
    required this.method,
    required this.status,
    required this.createdAt,
    required this.sentAt,
    required this.confirmedAt,
  });

  factory DriverTip.fromJson(Map<String, dynamic> json) => DriverTip(
        id: json['id'] as String,
        bookingId: json['bookingId'] as String? ?? '',
        tripId: json['tripId'] as String? ?? '',
        passengerName: json['passengerName'] as String? ?? '',
        driverName: json['driverName'] as String? ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        message: json['message'] as String?,
        method: json['method'] as String? ?? 'bank_transfer',
        status: json['status'] as String? ?? 'pending',
        createdAt: DateTime.parse(json['createdAt'] as String),
        sentAt: json['sentAt'] == null ? null : DateTime.parse(json['sentAt'] as String),
        confirmedAt:
            json['confirmedAt'] == null ? null : DateTime.parse(json['confirmedAt'] as String),
      );

  bool get pending => status == 'pending';
  bool get confirmed => status == 'confirmed';
  String get methodLabel => method == 'cash' ? 'Ti?n m?t' : 'Chuy?n kho?n QR';
}

class BookingTipInfo {
  final TipAccount? account;
  final DriverTip? existing;
  final String? qrPayload;

  const BookingTipInfo({required this.account, required this.existing, this.qrPayload});

  factory BookingTipInfo.fromJson(Map<String, dynamic> json) => BookingTipInfo(
        account: json['account'] == null
            ? null
            : TipAccount.fromJson(json['account'] as Map<String, dynamic>),
        existing: json['existingTip'] == null
            ? null
            : DriverTip.fromJson(json['existingTip'] as Map<String, dynamic>),
        qrPayload: json['qrPayload'] as String?,
      );
}

class CreateTipResult {
  final DriverTip tip;
  final TipAccount? account;
  final String? qrPayload;

  const CreateTipResult({required this.tip, required this.account, required this.qrPayload});

  factory CreateTipResult.fromJson(Map<String, dynamic> json) => CreateTipResult(
        tip: DriverTip.fromJson(json['tip'] as Map<String, dynamic>),
        account: json['account'] == null
            ? null
            : TipAccount.fromJson(json['account'] as Map<String, dynamic>),
        qrPayload: json['qrPayload'] as String?,
      );
}

class TipSummary {
  final int totalConfirmed;
  final int countConfirmed;
  final int countPending;
  final List<DriverTip> recent;

  const TipSummary({
    required this.totalConfirmed,
    required this.countConfirmed,
    required this.countPending,
    required this.recent,
  });

  factory TipSummary.fromJson(Map<String, dynamic> json) => TipSummary(
        totalConfirmed: (json['totalConfirmed'] as num?)?.toInt() ?? 0,
        countConfirmed: (json['countConfirmed'] as num?)?.toInt() ?? 0,
        countPending: (json['countPending'] as num?)?.toInt() ?? 0,
        recent: (json['recent'] as List<dynamic>? ?? [])
            .map((e) => DriverTip.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class VerificationDocument {
  final String id;
  final String type;
  final String originalName;
  final String mimeType;
  final int sizeBytes;

  const VerificationDocument({
    required this.id,
    required this.type,
    required this.originalName,
    required this.mimeType,
    required this.sizeBytes,
  });

  factory VerificationDocument.fromJson(Map<String, dynamic> json) => VerificationDocument(
        id: json['id'] as String,
        type: json['type'] as String? ?? '',
        originalName: json['originalName'] as String? ?? '',
        mimeType: json['mimeType'] as String? ?? '',
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      );
}

class VerificationInfo {
  final String status;
  final int level;
  final DateTime? expiresAt;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final String? legalName;
  final String? dateOfBirth;
  final String? idNumber;
  final String? idIssuedAt;
  final String? idExpiry;
  final String? licenseNumber;
  final String? licenseClass;
  final String? licenseExpiry;
  final String? vehicleRegistration;
  final String? insuranceExpiry;
  final List<VerificationDocument> documents;
  final List<String> requiredDocuments;

  const VerificationInfo({
    required this.status,
    required this.level,
    required this.expiresAt,
    required this.submittedAt,
    required this.reviewedAt,
    required this.rejectionReason,
    required this.legalName,
    required this.dateOfBirth,
    required this.idNumber,
    required this.idIssuedAt,
    required this.idExpiry,
    required this.licenseNumber,
    required this.licenseClass,
    required this.licenseExpiry,
    required this.vehicleRegistration,
    required this.insuranceExpiry,
    required this.documents,
    required this.requiredDocuments,
  });

  factory VerificationInfo.fromJson(Map<String, dynamic> json) => VerificationInfo(
        status: json['status'] as String? ?? 'unverified',
        level: (json['level'] as num?)?.toInt() ?? 1,
        expiresAt: json['expiresAt'] == null ? null : DateTime.parse(json['expiresAt'] as String),
        submittedAt:
            json['submittedAt'] == null ? null : DateTime.parse(json['submittedAt'] as String),
        reviewedAt:
            json['reviewedAt'] == null ? null : DateTime.parse(json['reviewedAt'] as String),
        rejectionReason: json['rejectionReason'] as String?,
        legalName: json['legalName'] as String?,
        dateOfBirth: json['dateOfBirth'] as String?,
        idNumber: json['idNumber'] as String?,
        idIssuedAt: json['idIssuedAt'] as String?,
        idExpiry: json['idExpiry'] as String?,
        licenseNumber: json['licenseNumber'] as String?,
        licenseClass: json['licenseClass'] as String?,
        licenseExpiry: json['licenseExpiry'] as String?,
        vehicleRegistration: json['vehicleRegistration'] as String?,
        insuranceExpiry: json['insuranceExpiry'] as String?,
        documents: (json['documents'] as List<dynamic>? ?? [])
            .map((e) => VerificationDocument.fromJson(e as Map<String, dynamic>))
            .toList(),
        requiredDocuments: (json['requiredDocuments'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );

  bool get approved => status == 'approved';
  bool get pending => status == 'pending';
  bool get rejected => status == 'rejected';
  bool get suspended => status == 'suspended';
  bool get canEdit => status != 'pending' && status != 'approved' && status != 'suspended';

  VerificationDocument? documentOf(String type) {
    for (final doc in documents) {
      if (doc.type == type) return doc;
    }
    return null;
  }
}

class EscrowInfo {
  final String bookingId;
  final int amount;
  final String method;
  final String status;

  const EscrowInfo({
    required this.bookingId,
    required this.amount,
    required this.method,
    required this.status,
  });

  factory EscrowInfo.fromJson(Map<String, dynamic> json) => EscrowInfo(
        bookingId: json['bookingId'] as String,
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        method: json['method'] as String? ?? '',
        status: json['status'] as String? ?? '',
      );
}

class AppealEvidence {
  final String id;
  final String originalName;
  final String mimeType;
  final int sizeBytes;
  final String uploaderName;

  const AppealEvidence({
    required this.id,
    required this.originalName,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploaderName,
  });

  factory AppealEvidence.fromJson(Map<String, dynamic> json) => AppealEvidence(
        id: json['id'] as String,
        originalName: json['originalName'] as String? ?? '',
        mimeType: json['mimeType'] as String? ?? '',
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
        uploaderName: json['uploaderName'] as String? ?? '',
      );
}

class AppealInfo {
  final String id;
  final String bookingId;
  final String openedByName;
  final String againstName;
  final String reason;
  final String description;
  final String status;
  final String? resolution;
  final String? resolutionNote;
  final DateTime createdAt;
  final List<AppealEvidence> evidence;

  const AppealInfo({
    required this.id,
    required this.bookingId,
    required this.openedByName,
    required this.againstName,
    required this.reason,
    required this.description,
    required this.status,
    required this.resolution,
    required this.resolutionNote,
    required this.createdAt,
    required this.evidence,
  });

  factory AppealInfo.fromJson(Map<String, dynamic> json) => AppealInfo(
        id: json['id'] as String,
        bookingId: json['bookingId'] as String,
        openedByName: json['openedByName'] as String? ?? '',
        againstName: json['againstName'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        description: json['description'] as String? ?? '',
        status: json['status'] as String? ?? 'open',
        resolution: json['resolution'] as String?,
        resolutionNote: json['resolutionNote'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        evidence: (json['evidence'] as List<dynamic>? ?? [])
            .map((e) => AppealEvidence.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ReputationInfo {
  final String userId;
  final String fullName;
  final double rating;
  final int reviewCount;
  final int completedAsDriver;
  final int completedAsPassenger;
  final int totalOrders;
  final int completionRate;
  final int score;
  final String tier;
  final List<String> badges;

  const ReputationInfo({
    required this.userId,
    required this.fullName,
    required this.rating,
    required this.reviewCount,
    required this.completedAsDriver,
    required this.completedAsPassenger,
    required this.totalOrders,
    required this.completionRate,
    required this.score,
    required this.tier,
    required this.badges,
  });

  factory ReputationInfo.fromJson(Map<String, dynamic> json) => ReputationInfo(
        userId: json['userId'] as String,
        fullName: json['fullName'] as String? ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
        completedAsDriver: (json['completedAsDriver'] as num?)?.toInt() ?? 0,
        completedAsPassenger: (json['completedAsPassenger'] as num?)?.toInt() ?? 0,
        totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
        completionRate: (json['completionRate'] as num?)?.toInt() ?? 0,
        score: (json['score'] as num?)?.toInt() ?? 0,
        tier: json['tier'] as String? ?? 'new',
        badges: (json['badges'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      );
}

class GeoPlace {
  final String label;
  final String fullName;
  final double lat;
  final double lng;
  final String? kind;

  const GeoPlace({
    required this.label,
    required this.fullName,
    required this.lat,
    required this.lng,
    this.kind,
  });

  factory GeoPlace.fromJson(Map<String, dynamic> json) => GeoPlace(
        label: json['label'] as String? ?? 'Vị trí',
        fullName: json['fullName'] as String? ?? '',
        lat: (json['lat'] as num?)?.toDouble() ?? 0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0,
        kind: json['kind'] as String?,
      );
}

class NearbyDriver {
  final String driverId;
  final String fullName;
  final double rating;
  final int ratingCount;
  final String? vehicleLabel;
  final String? plate;
  final double lat;
  final double lng;
  final int etaMinutes;

  const NearbyDriver({
    required this.driverId,
    required this.fullName,
    required this.rating,
    required this.ratingCount,
    required this.lat,
    required this.lng,
    required this.etaMinutes,
    this.vehicleLabel,
    this.plate,
  });

  factory NearbyDriver.fromJson(Map<String, dynamic> json) => NearbyDriver(
        driverId: json['driverId'] as String,
        fullName: json['fullName'] as String? ?? 'Tài xế',
        rating: (json['rating'] as num?)?.toDouble() ?? 5,
        ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
        vehicleLabel: json['vehicleLabel'] as String?,
        plate: json['plate'] as String?,
        lat: (json['lat'] as num?)?.toDouble() ?? 0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0,
        etaMinutes: (json['etaMinutes'] as num?)?.toInt() ?? 0,
      );
}

class RideDriver {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final double rating;
  final int ratingCount;
  final String vehicleLabel;
  final String? plate;
  final String? color;
  final String? phoneMasked;

  const RideDriver({
    required this.id,
    required this.fullName,
    required this.rating,
    required this.ratingCount,
    required this.vehicleLabel,
    this.avatarUrl,
    this.plate,
    this.color,
    this.phoneMasked,
  });

  factory RideDriver.fromJson(Map<String, dynamic> json) => RideDriver(
        id: json['id'] as String,
        fullName: json['fullName'] as String? ?? 'Tài xế',
        avatarUrl: json['avatarUrl'] as String?,
        rating: (json['rating'] as num?)?.toDouble() ?? 5,
        ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
        vehicleLabel: json['vehicleLabel'] as String? ?? 'Xe',
        plate: json['plate'] as String?,
        color: json['color'] as String?,
        phoneMasked: json['phoneMasked'] as String?,
      );
}

class RideInfo {
  final String id;
  final String passengerId;
  final String passengerName;
  final double? passengerRating;
  final String pickupLabel;
  final double pickupLat;
  final double pickupLng;
  final String dropoffLabel;
  final double dropoffLat;
  final double dropoffLng;
  final String vehicleClass;
  final String paymentMethod;
  final String? note;
  final String status;
  final RideDriver? driver;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const RideInfo({
    required this.id,
    required this.passengerId,
    required this.passengerName,
    required this.pickupLabel,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLabel,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.vehicleClass,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.passengerRating,
    this.note,
    this.driver,
    this.acceptedAt,
    this.arrivedAt,
    this.startedAt,
    this.completedAt,
  });

  String get paymentLabel => switch (paymentMethod) {
        'bank' => 'Chuyển khoản',
        'wallet' => 'Ví điện tử',
        _ => 'Tiền mặt',
      };

  String get statusLabel => switch (status) {
        'searching' => 'Đang tìm tài xế',
        'accepted' => 'Tài xế đang đến',
        'arrived' => 'Tài xế đã đến',
        'in_progress' => 'Đang di chuyển',
        'completed' => 'Đã hoàn tất',
        'cancelled' => 'Đã huỷ',
        _ => status,
      };

  factory RideInfo.fromJson(Map<String, dynamic> json) => RideInfo(
        id: json['id'] as String,
        passengerId: json['passengerId'] as String? ?? '',
        passengerName: json['passengerName'] as String? ?? '',
        passengerRating: (json['passengerRating'] as num?)?.toDouble(),
        pickupLabel: json['pickupLabel'] as String? ?? '',
        pickupLat: (json['pickupLat'] as num?)?.toDouble() ?? 0,
        pickupLng: (json['pickupLng'] as num?)?.toDouble() ?? 0,
        dropoffLabel: json['dropoffLabel'] as String? ?? '',
        dropoffLat: (json['dropoffLat'] as num?)?.toDouble() ?? 0,
        dropoffLng: (json['dropoffLng'] as num?)?.toDouble() ?? 0,
        vehicleClass: json['vehicleClass'] as String? ?? 'car',
        paymentMethod: json['paymentMethod'] as String? ?? 'cash',
        note: json['note'] as String?,
        status: json['status'] as String? ?? 'searching',
        driver: json['driver'] == null
            ? null
            : RideDriver.fromJson(json['driver'] as Map<String, dynamic>),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        acceptedAt: DateTime.tryParse(json['acceptedAt'] as String? ?? '')?.toLocal(),
        arrivedAt: DateTime.tryParse(json['arrivedAt'] as String? ?? '')?.toLocal(),
        startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '')?.toLocal(),
        completedAt: DateTime.tryParse(json['completedAt'] as String? ?? '')?.toLocal(),
      );
}

class DriverPresence {
  final bool online;
  final double lat;
  final double lng;
  final String? vehicleId;
  final DateTime updatedAt;

  const DriverPresence({
    required this.online,
    required this.lat,
    required this.lng,
    required this.updatedAt,
    this.vehicleId,
  });

  factory DriverPresence.fromJson(Map<String, dynamic> json) => DriverPresence(
        online: json['online'] as bool? ?? false,
        lat: (json['lat'] as num?)?.toDouble() ?? 21.0278,
        lng: (json['lng'] as num?)?.toDouble() ?? 105.8342,
        vehicleId: json['vehicleId'] as String?,
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );
}
