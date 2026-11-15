import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}

class AuthResult {
  final String token;
  final String refreshToken;
  final AppUser user;
  AuthResult(this.token, this.refreshToken, this.user);
}

class Api {
  static const String _envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    if (kIsWeb) return 'http://localhost:8080';
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8080'
        : 'http://localhost:8080';
  }

  String? token;
  String? refreshToken;
  bool _refreshing = false;
  void Function(String accessToken, String refreshToken)? onTokensChanged;
  final http.Client _client = http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(
      queryParameters: query.map((key, value) => MapEntry(key, '$value')),
    );
  }

  Future<http.Response> _execute(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    Map<String, String>? extraHeaders,
  }) async {
    final request = http.Request(method, _uri(path, query));
    request.headers.addAll({..._headers, ...?extraHeaders});
    if (body != null) request.body = jsonEncode(body);
    final streamed = await _client.send(request).timeout(const Duration(seconds: 20));
    return http.Response.fromStream(streamed);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    Map<String, String>? extraHeaders,
  }) async {
    var response = await _execute(method, path, query: query, body: body, extraHeaders: extraHeaders);

    if (response.statusCode == 401 &&
        refreshToken != null &&
        !path.startsWith('/api/auth/') &&
        !_refreshing) {
      final refreshed = await tryRefresh();
      if (refreshed) {
        response = await _execute(method, path, query: query, body: body, extraHeaders: extraHeaders);
      }
    }

    final text = utf8.decode(response.bodyBytes);
    dynamic decoded;
    try {
      decoded = text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      decoded = text;
    }

    if (response.statusCode >= 400) {
      final message = decoded is Map && decoded['error'] != null
          ? decoded['error'].toString()
          : 'Lỗi ${response.statusCode}';
      throw ApiException(message, response.statusCode);
    }
    return decoded;
  }

  Future<bool> tryRefresh() async {
    if (refreshToken == null || _refreshing) return false;
    _refreshing = true;
    try {
      final response = await _client.post(
        _uri('/api/auth/refresh'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (response.statusCode != 200) return false;
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      token = data['accessToken'] as String;
      refreshToken = data['refreshToken'] as String;
      onTokensChanged?.call(token!, refreshToken!);
      return true;
    } catch (_) {
      return false;
    } finally {
      _refreshing = false;
    }
  }

  Future<Map<String, dynamic>> requestOtp(String phone) async {
    final data = await _send('POST', '/api/auth/otp/request', body: {'phone': phone});
    return data as Map<String, dynamic>;
  }

  Future<AuthResult> verifyOtp(String phone, String code) async {
    final data = await _send('POST', '/api/auth/otp/verify',
        body: {'phone': phone, 'code': code}) as Map<String, dynamic>;
    token = data['accessToken'] as String;
    refreshToken = data['refreshToken'] as String?;
    return AuthResult(token!, refreshToken ?? '', AppUser.fromJson(data['user'] as Map<String, dynamic>));
  }

  Future<void> logout() async {
    final value = refreshToken;
    if (value == null) return;
    try {
      await _client.post(_uri('/api/auth/logout'),
          headers: {'Content-Type': 'application/json'}, body: jsonEncode({'refreshToken': value}));
    } catch (_) {}
  }

  Future<AppUser> me() async {
    final data = await _send('GET', '/api/me') as Map<String, dynamic>;
    return AppUser.fromJson(data);
  }

  Future<Earnings> earnings() async {
    final data = await _send('GET', '/api/me/earnings') as Map<String, dynamic>;
    return Earnings.fromJson(data);
  }

  Future<void> registerDevice(String token, String platform) async {
    await _send('POST', '/api/me/devices', body: {'token': token, 'platform': platform});
  }

  Future<TripTracking> tracking(String tripId) async {
    final data = await _send('GET', '/api/trips/$tripId/tracking') as Map<String, dynamic>;
    return TripTracking.fromJson(data);
  }

  Future<TripTracking> sendLocation(
    String tripId, {
    required double lat,
    required double lng,
    double? heading,
    double? speed,
    double? accuracy,
  }) async {
    final data = await _send('POST', '/api/trips/$tripId/location', body: {
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'speed': speed,
      'accuracy': accuracy,
    }) as Map<String, dynamic>;
    return TripTracking.fromJson(data);
  }

  Future<TripTracking> setTrackingStatus(String tripId, String status) async {
    final data = await _send('POST', '/api/trips/$tripId/tracking/status',
        body: {'status': status}) as Map<String, dynamic>;
    return TripTracking.fromJson(data);
  }

  Future<List<SearchResult>> search({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    required String date,
    required int seats,
  }) async {
    final data = await _send('GET', '/api/trips/search', query: {
      'fromLat': fromLat,
      'fromLng': fromLng,
      'toLat': toLat,
      'toLng': toLng,
      'date': date,
      'seats': seats,
    }) as Map<String, dynamic>;
    return (data['items'] as List<dynamic>)
        .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Trip> trip(String id) async {
    final data = await _send('GET', '/api/trips/$id') as Map<String, dynamic>;
    return Trip.fromJson(data);
  }

  Future<List<Vehicle>> vehicles() async {
    final data = await _send('GET', '/api/vehicles') as List<dynamic>;
    return data.map((e) => Vehicle.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Vehicle> createVehicle({
    required String make,
    required String model,
    required String plate,
    required int seats,
  }) async {
    final data = await _send('POST', '/api/vehicles', body: {
      'make': make,
      'model': model,
      'year': 2020,
      'color': 'Trắng',
      'plate': plate,
      'seats': seats,
    }) as Map<String, dynamic>;
    return Vehicle.fromJson(data);
  }

  Future<Booking> createBooking({
    required String tripId,
    required int seats,
    required String fromStopId,
    required String toStopId,
  }) async {
    final data = await _send(
      'POST',
      '/api/trips/$tripId/bookings',
      body: {'seats': seats, 'fromStopId': fromStopId, 'toStopId': toStopId},
      extraHeaders: {'Idempotency-Key': 'app-${DateTime.now().microsecondsSinceEpoch}'},
    ) as Map<String, dynamic>;
    return Booking.fromJson(data);
  }

  Future<Booking> pay(String bookingId) async {
    final data = await _send('POST', '/api/bookings/$bookingId/pay', body: {})
        as Map<String, dynamic>;
    return Booking.fromJson(data);
  }

  Future<PaymentConfig> paymentConfig() async {
    final data = await _send('GET', '/api/payments/config') as Map<String, dynamic>;
    return PaymentConfig.fromJson(data);
  }

  Future<PayOsCheckout> createPayOsPayment(String bookingId) async {
    final data = await _send('POST', '/api/bookings/$bookingId/payos', body: {})
        as Map<String, dynamic>;
    return PayOsCheckout.fromJson(data);
  }

  Future<Booking> booking(String id) async {
    final data = await _send('GET', '/api/bookings/$id') as Map<String, dynamic>;
    return Booking.fromJson(data);
  }

  Future<List<Booking>> myBookings() async {
    final data = await _send('GET', '/api/bookings/mine') as List<dynamic>;
    return data.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TipAccount?> tipAccount() async {
    final data = await _send('GET', '/api/me/tip-account');
    return data == null ? null : TipAccount.fromJson(data as Map<String, dynamic>);
  }

  Future<TipAccount> saveTipAccount({
    required String bankBin,
    String? bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    final data = await _send('PUT', '/api/me/tip-account', body: {
      'bankBin': bankBin,
      'bankName': bankName ?? '',
      'accountNumber': accountNumber,
      'accountName': accountName,
    }) as Map<String, dynamic>;
    return TipAccount.fromJson(data);
  }

  Future<BookingTipInfo> bookingTipInfo(String bookingId) async {
    final data = await _send('GET', '/api/bookings/$bookingId/tip-info') as Map<String, dynamic>;
    return BookingTipInfo.fromJson(data);
  }

  Future<CreateTipResult> createTip(
    String bookingId, {
    required int amount,
    required String method,
    String? message,
  }) async {
    final data = await _send('POST', '/api/bookings/$bookingId/tips', body: {
      'amount': amount,
      'paymentMethod': method,
      'message': message,
    }) as Map<String, dynamic>;
    return CreateTipResult.fromJson(data);
  }

  Future<List<DriverTip>> bookingTips(String bookingId) async {
    final data = await _send('GET', '/api/bookings/$bookingId/tips') as List<dynamic>;
    return data.map((e) => DriverTip.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DriverTip> tipSent(String tipId) async {
    final data = await _send('POST', '/api/tips/$tipId/sent', body: {}) as Map<String, dynamic>;
    return DriverTip.fromJson(data);
  }

  Future<DriverTip> confirmTip(String tipId) async {
    final data = await _send('POST', '/api/tips/$tipId/confirm', body: {}) as Map<String, dynamic>;
    return DriverTip.fromJson(data);
  }

  Future<void> cancelTip(String tipId) async {
    await _send('POST', '/api/tips/$tipId/cancel', body: {});
  }

  Future<TipSummary> receivedTips() async {
    final data = await _send('GET', '/api/me/tips') as Map<String, dynamic>;
    return TipSummary.fromJson(data);
  }

  Future<VerificationInfo> verification() async {
    final data = await _send('GET', '/api/me/verification') as Map<String, dynamic>;
    return VerificationInfo.fromJson(data);
  }

  Future<VerificationInfo> saveVerificationProfile({
    required String legalName,
    required String? dateOfBirth,
    required String idNumber,
    required String? idIssuedAt,
    required String? idExpiry,
    required String licenseNumber,
    required String licenseClass,
    required String? licenseExpiry,
    required String vehicleRegistration,
    required String? insuranceExpiry,
  }) async {
    final data = await _send('PUT', '/api/me/verification/profile', body: {
      'legalName': legalName,
      'dateOfBirth': dateOfBirth,
      'idNumber': idNumber,
      'idIssuedAt': idIssuedAt,
      'idExpiry': idExpiry,
      'licenseNumber': licenseNumber,
      'licenseClass': licenseClass,
      'licenseExpiry': licenseExpiry,
      'vehicleRegistration': vehicleRegistration,
      'insuranceExpiry': insuranceExpiry,
    }) as Map<String, dynamic>;
    return VerificationInfo.fromJson(data);
  }

  Future<VerificationDocument> uploadVerificationDocument(
    String type,
    Uint8List bytes,
    String filename,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/api/me/verification/documents/$type'),
    );
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await _client.send(request).timeout(const Duration(seconds: 40));
    final response = await http.Response.fromStream(streamed);
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 400) {
      String message = 'Lỗi ${response.statusCode}';
      try {
        final data = jsonDecode(text);
        if (data is Map && data['error'] != null) message = data['error'].toString();
      } catch (_) {}
      throw ApiException(message, response.statusCode);
    }
    return VerificationDocument.fromJson(jsonDecode(text) as Map<String, dynamic>);
  }

  Future<VerificationInfo> submitVerification() async {
    final data = await _send('POST', '/api/me/verification/submit', body: {})
        as Map<String, dynamic>;
    return VerificationInfo.fromJson(data);
  }

  Future<void> cancelBooking(String id) async {
    await _send('POST', '/api/bookings/$id/cancel', body: {});
  }

  Future<Booking> acceptBooking(String id) async {
    final data = await _send('POST', '/api/bookings/$id/accept', body: {})
        as Map<String, dynamic>;
    return Booking.fromJson(data);
  }

  Future<Booking> rejectBooking(String id) async {
    final data = await _send('POST', '/api/bookings/$id/reject', body: {})
        as Map<String, dynamic>;
    return Booking.fromJson(data);
  }

  Future<Booking> completeBooking(String id) async {
    final data = await _send('POST', '/api/bookings/$id/complete', body: {})
        as Map<String, dynamic>;
    return Booking.fromJson(data);
  }

  Future<void> review(String bookingId, int rating, String comment) async {
    await _send('POST', '/api/bookings/$bookingId/reviews',
        body: {'rating': rating, 'comment': comment});
  }

  Future<Trip> createTrip(Map<String, dynamic> body) async {
    final data = await _send('POST', '/api/trips', body: body) as Map<String, dynamic>;
    return Trip.fromJson(data);
  }

  Future<List<RecurringTrip>> recurringTrips() async {
    final data = await _send('GET', '/api/trips/recurring') as List<dynamic>;
    return data.map((e) => RecurringTrip.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RecurringTrip> createRecurringTrip(Map<String, dynamic> body) async {
    final data = await _send('POST', '/api/trips/recurring', body: body)
        as Map<String, dynamic>;
    return RecurringTrip.fromJson(data);
  }

  Future<void> pauseRecurringTrip(String id) async {
    await _send('DELETE', '/api/trips/recurring/$id');
  }

  Future<List<ChatThread>> conversations() async {
    final data = await _send('GET', '/api/conversations') as List<dynamic>;
    return data.map((e) => ChatThread.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ChatMessage>> messages(String conversationId) async {
    final data = await _send('GET', '/api/conversations/$conversationId/messages')
        as List<dynamic>;
    return data.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ChatMessage> sendMessage(String conversationId, String body) async {
    final data = await _send('POST', '/api/conversations/$conversationId/messages',
        body: {'body': body}) as Map<String, dynamic>;
    return ChatMessage.fromJson(data);
  }

  Future<List<Line>> lines({double lat = 10.7725, double lng = 106.6980}) async {
    final data = await _send('GET', '/api/daily/lines', query: {'lat': lat, 'lng': lng})
        as List<dynamic>;
    return data.map((e) => Line.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Line> line(String id) async {
    final data = await _send('GET', '/api/daily/lines/$id') as Map<String, dynamic>;
    return Line.fromJson(data);
  }

  Future<ETicket> createTicket(String lineId, String stopId) async {
    final data = await _send('POST', '/api/daily/e-tickets',
        body: {'lineId': lineId, 'stopId': stopId}) as Map<String, dynamic>;
    return ETicket.fromJson(data);
  }

  Future<List<ETicket>> myTickets() async {
    final data = await _send('GET', '/api/daily/my-tickets') as List<dynamic>;
    return data.map((e) => ETicket.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ETicket>> driverQueue() async {
    final data = await _send('GET', '/api/daily/driver/queue') as List<dynamic>;
    return data.map((e) => ETicket.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ETicket> assignTicket(String id) async {
    final data = await _send('POST', '/api/daily/e-tickets/$id/assign', body: {})
        as Map<String, dynamic>;
    return ETicket.fromJson(data);
  }

  Future<ETicket> validateTicket(String id, String code) async {
    final data = await _send('POST', '/api/daily/e-tickets/$id/validate',
        body: {'code': code}) as Map<String, dynamic>;
    return ETicket.fromJson(data);
  }

  Future<List<AppNotification>> notifications() async {
    final data = await _send('GET', '/api/notifications') as List<dynamic>;
    return data.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> markNotificationsRead() async {
    await _send('POST', '/api/notifications/read-all', body: {});
  }

  Future<int> unreadNotifications() async {
    final data = await _send('GET', '/api/notifications/unread-count')
        as Map<String, dynamic>;
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  void close() => _client.close();
}
