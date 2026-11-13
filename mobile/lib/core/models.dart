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
  final String senderId;
  final String senderName;
  final String body;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.body,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
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
  final List<EarningItem> recent;

  const Earnings({
    required this.tripEarnings,
    required this.completedTrips,
    required this.dailyEarningsMinor,
    required this.dailyValidations,
    required this.recent,
  });

  factory Earnings.fromJson(Map<String, dynamic> json) => Earnings(
        tripEarnings: (json['tripEarnings'] as num?)?.toInt() ?? 0,
        completedTrips: (json['completedTrips'] as num?)?.toInt() ?? 0,
        dailyEarningsMinor: (json['dailyEarningsMinor'] as num?)?.toInt() ?? 0,
        dailyValidations: (json['dailyValidations'] as num?)?.toInt() ?? 0,
        recent: (json['recent'] as List<dynamic>? ?? [])
            .map((e) => EarningItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
