import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/app_ui.dart';
import '../widgets/ui.dart';
import 'chat_screen.dart';

class TrackingScreen extends StatefulWidget {
  final String tripId;
  const TrackingScreen({super.key, required this.tripId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final MapController _map = MapController();
  TripTracking? _data;
  Timer? _poll;
  Timer? _sender;
  Timer? _simTimer;
  bool _started = false;
  bool _busy = false;
  bool _locating = false;
  bool _sharing = false;
  bool _simulated = false;
  bool _follow = true;
  double _simT = 0.02;
  LatLng? _simStart;
  String? _error;
  LatLng? _myPosition;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load(initial: true);
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _sender?.cancel();
    _simTimer?.cancel();
    super.dispose();
  }

  bool get _isDriver =>
      _data != null && _data!.driverId == AppScope.of(context).user?.id;

  Future<void> _load({bool initial = false}) async {
    try {
      final data = await AppScope.of(context).api.tracking(widget.tripId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
      if (initial) {
        _fitMap();
        await _initLocation();
      } else if (_follow && data.driver != null) {
        _map.move(LatLng(data.driver!.lat, data.driver!.lng), _map.camera.zoom);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _fitMap() {
    final d = _data;
    if (d == null) return;
    final points = <LatLng>[
      if (d.driver != null) LatLng(d.driver!.lat, d.driver!.lng),
      ...d.route.map((p) => LatLng(p.lat, p.lng)),
    ];
    if (points.isEmpty) return;
    final center = LatLng(
      points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length,
      points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length,
    );
    final zoom = points.length > 2 ? 12.2 : 14.0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _map.move(center, zoom);
    });
  }

  Future<void> _initLocation() async {
    final d = _data;
    if (d == null) return;
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _useFallback();
        return;
      }
      if (_isDriver) {
        _sender = Timer.periodic(const Duration(seconds: 5), (_) async {
          try {
            final pos = await Geolocator.getCurrentPosition(
                locationSettings:
                    const LocationSettings(accuracy: LocationAccuracy.high));
            await _sendPosition(pos.latitude, pos.longitude,
                heading: pos.heading, speed: pos.speed, accuracy: pos.accuracy);
          } catch (_) {}
        });
        final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
        await _sendPosition(pos.latitude, pos.longitude,
            heading: pos.heading, speed: pos.speed, accuracy: pos.accuracy);
      } else {
        await _sharePassengerLocation();
        _sender = Timer.periodic(
            const Duration(seconds: 12), (_) => _sharePassengerLocation());
      }
      if (mounted) setState(() => _sharing = true);
    } catch (_) {
      _useFallback();
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _sharePassengerLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (mounted) setState(() => _myPosition = LatLng(pos.latitude, pos.longitude));
      await _sendPosition(pos.latitude, pos.longitude,
          heading: pos.heading, speed: pos.speed, accuracy: pos.accuracy);
      if (mounted) setState(() => _sharing = true);
    } catch (_) {
      _useFallback();
    }
  }

  void _useFallback() {
    final d = _data;
    if (d == null) return;
    if (_isDriver) {
      _startSimulation();
    } else {
      setState(() {
        _myPosition = LatLng(d.pickup.lat, d.pickup.lng);
        _sharing = true;
      });
      _sendPosition(d.pickup.lat, d.pickup.lng);
    }
  }

  void _startSimulation() {
    if (_simTimer != null) return;
    final d = _data;
    if (d == null) return;
    _simStart = LatLng(d.pickup.lat + 0.022, d.pickup.lng - 0.02);
    setState(() {
      _simulated = true;
      _sharing = true;
    });
    _simTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final data = _data;
      if (data == null || data.route.length < 2) return;
      final status = data.trackingStatus;
      LatLng point;
      LatLng next;
      double heading;
      if (status == 'in_progress') {
        _simT = math.min(1.0, _simT + 0.02);
        point = _pointAlong(data.route, _simT);
        next = _pointAlong(data.route, math.min(1.0, _simT + 0.01));
        heading = _bearing(point, next);
      } else if (status == 'arrived') {
        point = LatLng(data.pickup.lat, data.pickup.lng);
        next = point;
        heading = 0;
      } else {
        _simT = math.min(1.0, _simT + 0.05);
        final start = _simStart!;
        final pickup = LatLng(data.pickup.lat, data.pickup.lng);
        point = LatLng(
          start.latitude + (pickup.latitude - start.latitude) * _simT,
          start.longitude + (pickup.longitude - start.longitude) * _simT,
        );
        next = pickup;
        heading = _bearing(point, next);
      }
      await _sendPosition(point.latitude, point.longitude,
          heading: heading, speed: 28, accuracy: 8);
    });
  }

  LatLng _pointAlong(List<LatLngPoint> route, double t) {
    final total = <double>[];
    var sum = 0.0;
    for (var i = 1; i < route.length; i++) {
      final d = _distance(route[i - 1], route[i]);
      total.add(d);
      sum += d;
    }
    if (sum == 0) return LatLng(route.first.lat, route.first.lng);
    var target = sum * t.clamp(0.0, 1.0);
    for (var i = 0; i < total.length; i++) {
      if (target <= total[i]) {
        final f = target / total[i];
        return LatLng(
          route[i].lat + (route[i + 1].lat - route[i].lat) * f,
          route[i].lng + (route[i + 1].lng - route[i].lng) * f,
        );
      }
      target -= total[i];
    }
    return LatLng(route.last.lat, route.last.lng);
  }

  double _distance(LatLngPoint a, LatLngPoint b) {
    final dx = (b.lng - a.lng) * 111320 * math.cos(a.lat * math.pi / 180);
    final dy = (b.lat - a.lat) * 110540;
    return math.sqrt(dx * dx + dy * dy);
  }

  double _bearing(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return math.atan2(y, x) * 180 / math.pi;
  }

  Future<void> _sendPosition(double lat, double lng,
      {double? heading, double? speed, double? accuracy}) async {
    try {
      await AppScope.of(context).api.sendLocation(widget.tripId,
          lat: lat, lng: lng, heading: heading, speed: speed, accuracy: accuracy);
      if (mounted) setState(() => _sharing = true);
    } catch (_) {}
  }

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    try {
      final data = await AppScope.of(context).api.setTrackingStatus(widget.tripId, status);
      if (!mounted) return;
      setState(() => _data = data);
      if (status == 'arrived' || status == 'in_progress') _simT = 0.02;
      if (status == 'completed') {
        _simTimer?.cancel();
        _sender?.cancel();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      backgroundColor: const Color(0xFFE9EFF7),
      body: Stack(
        children: [
          if (d == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: LatLng(d.pickup.lat, d.pickup.lng),
                initialZoom: 13,
                minZoom: 7,
                maxZoom: 18,
                backgroundColor: const Color(0xFFE9EFF7),
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture && _follow) setState(() => _follow = false);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'vn.sharee.mobile',
                  maxZoom: 19,
                ),
                if (d.route.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: d.route
                            .map((p) => LatLng(p.lat, p.lng))
                            .toList(),
                        strokeWidth: 5,
                        color: AppTheme.primary.withValues(alpha: 0.8),
                        borderStrokeWidth: 2,
                        borderColor: Colors.white.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(d.pickup.lat, d.pickup.lng),
                      width: 40,
                      height: 40,
                      child: _MapPin(
                        color: AppTheme.success,
                        icon: Icons.trip_origin_rounded,
                      ),
                    ),
                    Marker(
                      point: LatLng(d.dropoff.lat, d.dropoff.lng),
                      width: 40,
                      height: 40,
                      child: _MapPin(
                        color: AppTheme.accent,
                        icon: Icons.flag_rounded,
                      ),
                    ),
                    if (_myPosition != null && d.passengers.isEmpty)
                      Marker(
                        point: _myPosition!,
                        width: 30,
                        height: 30,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.35),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.person_rounded,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    for (final p in d.passengers)
                      Marker(
                        point: LatLng(p.lat, p.lng),
                        width: 30,
                        height: 30,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.person_rounded,
                              size: 13, color: Colors.white),
                        ),
                      ),
                    if (d.driver != null)
                      Marker(
                        point: LatLng(d.driver!.lat, d.driver!.lng),
                        width: 52,
                        height: 52,
                        child: _CarMarker(heading: d.driver!.heading ?? 0),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 14,
              top: MediaQuery.of(context).padding.top + 10,
              right: 14,
              child: _TopBar(
                tracking: d,
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              left: 16,
              top: MediaQuery.of(context).padding.top + 60,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text('© OpenStreetMap',
                    style: TextStyle(fontSize: 7.5, color: AppTheme.muted)),
              ),
            ),
            Positioned(
              right: 14,
              bottom: MediaQuery.of(context).size.height * 0.46,
              child: Column(
                children: [
                  _MapButton(
                    icon: Icons.my_location_rounded,
                    onTap: () {
                      setState(() => _follow = true);
                      final point = d.driver != null
                          ? LatLng(d.driver!.lat, d.driver!.lng)
                          : LatLng(d.pickup.lat, d.pickup.lng);
                      _map.move(point, 14.5);
                    },
                  ),
                  const SizedBox(height: 8),
                  _MapButton(
                    icon: Icons.layers_outlined,
                    onTap: () => showInfo(context, 'Bản đồ OpenStreetMap · cập nhật 3 giây'),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: MediaQuery.of(context).size.height * 0.44 + 8,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _sharing
                        ? (_simulated ? 'Đang chia sẻ vị trí · chế độ mô phỏng' : 'Đang chia sẻ vị trí trực tiếp')
                        : 'Đang lấy vị trí…',
                    style: const TextStyle(fontSize: 9, color: AppTheme.muted),
                  ),
                ),
              ),
            ),
            DraggableScrollableSheet(
              initialChildSize: 0.44,
              minChildSize: 0.32,
              maxChildSize: 0.9,
              builder: (context, controller) => Container(
                decoration: const BoxDecoration(
                  color: AppTheme.bg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 24,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCE3EE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.trackingStatus == 'completed'
                                    ? 'Chuyến đã hoàn thành'
                                    : d.trackingStatus == 'in_progress'
                                        ? 'Đang di chuyển'
                                        : d.trackingStatus == 'arrived'
                                            ? 'Tài xế đã đến'
                                            : 'Tài xế đang đến',
                                style: const TextStyle(
                                    fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.4),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                d.trackingStatus == 'completed'
                                    ? 'Cảm ơn bạn đã đi cùng Sharee'
                                    : d.trackingStatus == 'arrived'
                                        ? 'Tài xế đang chờ bạn tại điểm đón'
                                        : 'Còn ${d.etaMinutes} phút · ${d.distanceKm.toStringAsFixed(1)} km',
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: d.trackingStatus == 'completed'
                                ? AppTheme.successSoft
                                : AppTheme.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text(
                                d.trackingStatus == 'completed' ? '✓' : '${d.etaMinutes}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: d.trackingStatus == 'completed'
                                      ? AppTheme.success
                                      : AppTheme.primary,
                                ),
                              ),
                              Text(
                                d.trackingStatus == 'completed' ? 'xong' : 'phút',
                                style: const TextStyle(fontSize: 8, color: AppTheme.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AppCard(
                      padding: const EdgeInsets.all(13),
                      child: Column(
                        children: [
                          _RouteRow(
                            color: AppTheme.success,
                            label: 'Đón khách',
                            name: d.pickup.name,
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: SizedBox(
                              height: 18,
                              child: VerticalDivider(width: 2, thickness: 2, color: AppTheme.line),
                            ),
                          ),
                          _RouteRow(
                            color: AppTheme.accent,
                            label: 'Trả khách',
                            name: d.dropoff.name,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    AppCard(
                      padding: const EdgeInsets.all(13),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [
                                AppTheme.primary.withValues(alpha: 0.9),
                                AppTheme.primaryDark,
                              ]),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              d.driverName.isNotEmpty ? d.driverName[0] : '?',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(d.driverName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13, fontWeight: FontWeight.w800)),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified_rounded,
                                        size: 14, color: AppTheme.success),
                                  ],
                            ),
                                Text(d.vehicle.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
                              ],
                            ),
                          ),
                          _CircleAction(
                            icon: Icons.chat_bubble_outline_rounded,
                            onTap: () =>
                                Navigator.of(context).push(appRoute(const ChatThreadsScreen())),
                          ),
                          const SizedBox(width: 7),
                          _CircleAction(
                            icon: Icons.call_outlined,
                            onTap: () => showInfo(context, 'Gọi ${d.driverPhone}'),
                          ),
                        ],
                      ),
                    ),
                    if (d.passengers.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      AppCard(
                        padding: const EdgeInsets.all(13),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Vị trí khách',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            for (final p in d.passengers)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person_pin_circle_rounded,
                                        size: 15, color: AppTheme.primary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(p.fullName,
                                          style: const TextStyle(fontSize: 11)),
                                    ),
                                    Text(
                                      '${p.lat.toStringAsFixed(4)}, ${p.lng.toStringAsFixed(4)}',
                                      style: const TextStyle(
                                          fontSize: 9, color: AppTheme.muted),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (_isDriver) _driverControls(d),
                    if (!_isDriver && d.trackingStatus != 'completed')
                      OutlinedButton.icon(
                        onPressed: () => showInfo(context, 'Huỷ chuyến trong mục Chuyến của tôi'),
                        icon: const Icon(Icons.close_rounded, size: 17),
                        label: const Text('Huỷ chuyến'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(fontSize: 10, color: AppTheme.danger)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _driverControls(TripTracking d) {
    if (d.trackingStatus == 'completed') {
      return const Center(
        child: Text('Chuyến đã hoàn thành',
            style: TextStyle(fontSize: 11, color: AppTheme.muted)),
      );
    }
    final (label, next) = switch (d.trackingStatus) {
      'arrived' => ('Bắt đầu chuyến', 'in_progress'),
      'in_progress' => ('Hoàn thành chuyến', 'completed'),
      _ => ('Tôi đã đến điểm đón', 'arrived'),
    };
    return PrimaryButton(
      label: label,
      loading: _busy,
      icon: Icons.navigation_rounded,
      onPressed: () => _setStatus(next),
    );
  }
}

class _TopBar extends StatelessWidget {
  final TripTracking tracking;
  final VoidCallback onBack;

  const _TopBar({required this.tracking, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 3,
          child: InkWell(
            onTap: onBack,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.arrow_back_rounded, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              boxShadow: AppTheme.softShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tracking.trackingStatus == 'completed'
                        ? AppTheme.mutedLight
                        : AppTheme.success,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('Theo dõi trực tiếp',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text(
                  tracking.trackingStatus == 'completed' ? 'Đã xong' : 'LIVE',
                  style: TextStyle(
                    fontSize: 8.5,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w900,
                    color: tracking.trackingStatus == 'completed'
                        ? AppTheme.muted
                        : AppTheme.success,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteRow extends StatelessWidget {
  final Color color;
  final String label;
  final String name;

  const _RouteRow({required this.color, required this.label, required this.name});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 8.5, color: AppTheme.muted, fontWeight: FontWeight.w600)),
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _MapPin({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 17),
    );
  }
}

class _CarMarker extends StatelessWidget {
  final double heading;

  const _CarMarker({required this.heading});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: heading * math.pi / 180,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.primary, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.navigation_rounded, color: AppTheme.primary, size: 24),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 19)),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primarySoft,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(width: 34, height: 34, child: Icon(icon, size: 17, color: AppTheme.primary)),
      ),
    );
  }
}
