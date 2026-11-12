import 'dart:convert';

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
  final AppUser user;
  AuthResult(this.token, this.user);
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

  Future<dynamic> _send(
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
    final response = await http.Response.fromStream(streamed);
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

  Future<Map<String, dynamic>> requestOtp(String phone) async {
    final data = await _send('POST', '/api/auth/otp/request', body: {'phone': phone});
    return data as Map<String, dynamic>;
  }

  Future<AuthResult> verifyOtp(String phone, String code) async {
    final data = await _send('POST', '/api/auth/otp/verify',
        body: {'phone': phone, 'code': code}) as Map<String, dynamic>;
    token = data['accessToken'] as String;
    return AuthResult(token!, AppUser.fromJson(data['user'] as Map<String, dynamic>));
  }

  Future<AppUser> me() async {
    final data = await _send('GET', '/api/me') as Map<String, dynamic>;
    return AppUser.fromJson(data);
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

  Future<Booking> booking(String id) async {
    final data = await _send('GET', '/api/bookings/$id') as Map<String, dynamic>;
    return Booking.fromJson(data);
  }

  Future<List<Booking>> myBookings() async {
    final data = await _send('GET', '/api/bookings/mine') as List<dynamic>;
    return data.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
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

  Future<int> unreadNotifications() async {
    final data = await _send('GET', '/api/notifications/unread-count')
        as Map<String, dynamic>;
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  void close() => _client.close();
}
