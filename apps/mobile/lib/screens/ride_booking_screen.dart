import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_state.dart';
import '../core/map_config.dart';
import '../core/models.dart';
import '../widgets/app_ui.dart';
import '../widgets/ui.dart';
import 'location_picker_screen.dart';
import 'ride_waiting_screen.dart';

/// Map-first ride request. No fare is set by the app: the passenger chooses
/// points/payment, the nearest online drivers are notified, and the first
/// driver to accept takes the ride.
class RideBookingScreen extends StatefulWidget {
  final GeoPlace? initialPickup;

  const RideBookingScreen({super.key, this.initialPickup});

  @override
  State<RideBookingScreen> createState() => _RideBookingScreenState();
}

class _RideBookingScreenState extends State<RideBookingScreen> {
  static const _hanoi = LatLng(21.0278, 105.8342);
  final _map = MapController();
  final _note = TextEditingController();
  GeoPlace? _pickup;
  GeoPlace? _dropoff;
  List<NearbyDriver> _nearby = const [];
  String _payment = 'cash';
  String _vehicleClass = 'car';
  bool _locating = true;
  bool _loadingDrivers = false;
  bool _booking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pickup = widget.initialPickup;
    _init();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (_pickup == null) {
      final current = await _currentPlace();
      if (!mounted) return;
      setState(() {
        _pickup = current;
        _locating = false;
      });
    } else {
      setState(() => _locating = false);
    }
    await _loadNearby();
  }

  Future<GeoPlace> _currentPlace() async {
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          );
          return await AppScope.of(context).api.geoReverse(pos.latitude, pos.longitude);
        }
      }
    } catch (_) {
      // Fall back to a usable city-centre pickup.
    }
    return const GeoPlace(
      label: 'Vị trí của tôi',
      fullName: 'Hà Nội, Việt Nam',
      lat: 21.0278,
      lng: 105.8342,
      kind: 'pin',
    );
  }

  Future<void> _loadNearby() async {
    final p = _pickup;
    if (p == null) return;
    setState(() => _loadingDrivers = true);
    try {
      final drivers = await AppScope.of(context).api.nearbyDrivers(p.lat, p.lng);
      if (!mounted) return;
      setState(() => _nearby = drivers);
      if (_dropoff == null) _fitNearby();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingDrivers = false);
    }
  }

  Future<void> _pick({required bool pickup}) async {
    final initial = pickup ? _pickup : _dropoff;
    final place = await Navigator.of(context).push<GeoPlace>(
      appRoute(LocationPickerScreen(pickup: pickup, initial: initial)),
    );
    if (place == null || !mounted) return;
    setState(() {
      if (pickup) {
        _pickup = place;
      } else {
        _dropoff = place;
      }
      _error = null;
    });
    if (pickup) {
      await _loadNearby();
    }
    _fitMap();
  }

  void _fitMap() {
    final points = <LatLng>[
      if (_pickup != null) LatLng(_pickup!.lat, _pickup!.lng),
      if (_dropoff != null) LatLng(_dropoff!.lat, _dropoff!.lng),
    ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      _map.move(points.first, 15);
      return;
    }
    final bounds = LatLngBounds.fromPoints(points);
    _map.fitCamera(CameraFit.bounds(
      bounds: bounds,
      padding: const EdgeInsets.fromLTRB(40, 130, 40, 400),
    ));
  }

  /// Keep pickup + nearby cars in the area not covered by the bottom sheet.
  void _fitNearby() {
    final p = _pickup;
    if (p == null || _nearby.isEmpty) return;
    final points = <LatLng>[
      LatLng(p.lat, p.lng),
      for (final d in _nearby) LatLng(d.lat, d.lng),
    ];
    _map.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.fromLTRB(48, 140, 48, 500),
    ));
  }

  Future<void> _book() async {
    final p = _pickup;
    final d = _dropoff;
    if (p == null || d == null) {
      showInfo(context, 'Chọn điểm đón và điểm đến trước nhé.');
      return;
    }
    setState(() {
      _booking = true;
      _error = null;
    });
    try {
      final ride = await AppScope.of(context).api.createRide(
            pickupLabel: p.label,
            pickupLat: p.lat,
            pickupLng: p.lng,
            dropoffLabel: d.label,
            dropoffLat: d.lat,
            dropoffLng: d.lng,
            vehicleClass: _vehicleClass,
            paymentMethod: _payment,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      if (!mounted) return;
      await Navigator.of(context).push(appRoute(RideWaitingScreen(rideId: ride.id)));
      if (mounted) await _loadNearby();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _pickup == null
        ? _hanoi
        : LatLng(_pickup!.lat, _pickup!.lng);
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.tileUrl,
                userAgentPackageName: MapConfig.userAgent,
              ),
              MarkerLayer(
                markers: [
                  if (_pickup != null)
                    Marker(
                      point: LatLng(_pickup!.lat, _pickup!.lng),
                      width: 44,
                      height: 52,
                      child: const _MapPin(pickup: true),
                    ),
                  if (_dropoff != null)
                    Marker(
                      point: LatLng(_dropoff!.lat, _dropoff!.lng),
                      width: 44,
                      height: 52,
                      child: const _MapPin(pickup: false),
                    ),
                  for (final d in _nearby)
                    Marker(
                      point: LatLng(d.lat, d.lng),
                      width: 40,
                      height: 40,
                      child: _DriverDot(driver: d),
                    ),
                ],
              ),
            ],
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  _RoundButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_taxi_rounded,
                              color: AppTheme.primary, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('Đặt xe',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                          ),
                          if (_nearby.isNotEmpty)
                            Text('${_nearby.length} tài xế gần',
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _RoundButton(
                    icon: Icons.my_location_rounded,
                    onTap: () async {
                      final place = await _currentPlace();
                      if (!mounted) return;
                      setState(() => _pickup = place);
                      _map.move(LatLng(place.lat, place.lng), 15);
                      await _loadNearby();
                    },
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .52),
                child: SingleChildScrollView(
                  child: AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PointRow(
                          dotColor: AppTheme.primary,
                          label: 'Điểm đón',
                          value: _pickup?.label ?? 'Đang lấy vị trí...',
                          hint: _pickup?.fullName,
                          trailing: _locating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : null,
                          onTap: () => _pick(pickup: true),
                        ),
                        const Divider(height: 18),
                        _PointRow(
                          dotColor: AppTheme.accent,
                          label: 'Điểm đến',
                          value: _dropoff?.label ?? 'Bạn muốn đi đâu?',
                          hint: _dropoff?.fullName,
                          onTap: () => _pick(pickup: false),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Text('Loại xe',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                children: [
                                  _TinyChoice(
                                    label: '4 chỗ',
                                    active: _vehicleClass == 'car',
                                    onTap: () => setState(() => _vehicleClass = 'car'),
                                  ),
                                  _TinyChoice(
                                    label: '7 chỗ',
                                    active: _vehicleClass == 'premium',
                                    onTap: () => setState(() => _vehicleClass = 'premium'),
                                  ),
                                  _TinyChoice(
                                    label: 'Xe máy',
                                    active: _vehicleClass == 'bike',
                                    onTap: () => setState(() => _vehicleClass = 'bike'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('Thanh toán',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _PaymentChoice(
                                icon: Icons.payments_outlined,
                                label: 'Tiền mặt',
                                active: _payment == 'cash',
                                onTap: () => setState(() => _payment = 'cash'),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _PaymentChoice(
                                icon: Icons.account_balance_outlined,
                                label: 'Chuyển khoản',
                                active: _payment == 'bank',
                                onTap: () => setState(() => _payment = 'bank'),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _PaymentChoice(
                                icon: Icons.account_balance_wallet_outlined,
                                label: 'Ví',
                                active: _payment == 'wallet',
                                onTap: () => setState(() => _payment = 'wallet'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _note,
                          maxLines: 1,
                          decoration: const InputDecoration(
                            hintText: 'Ghi chú cho tài xế (không bắt buộc)',
                            prefixIcon: Icon(Icons.edit_note_rounded, size: 20),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                  color: AppTheme.success, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _loadingDrivers
                                    ? 'Đang tìm tài xế gần bạn...'
                                    : _nearby.isEmpty
                                        ? 'Chưa thấy tài xế online — vẫn có thể gửi yêu cầu'
                                        : '${_nearby.length} tài xế đang online gần bạn',
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.muted),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadNearby,
                              child: const Text('Làm mới', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(_error!,
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.danger)),
                          ),
                        PrimaryButton(
                          label: _booking ? 'Đang gửi yêu cầu...' : 'Đặt xe',
                          icon: Icons.local_taxi_rounded,
                          onPressed: _booking || _dropoff == null ? null : _book,
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'Giá cước do bạn và tài xế tự thoả thuận. Sharee không đặt giá, chỉ hỗ trợ phương thức thanh toán.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, color: AppTheme.muted, height: 1.35),
                        ),
                        const SizedBox(height: 4),
                        Text(MapConfig.attribution,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 8, color: AppTheme.mutedLight)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  final Color dotColor;
  final String label;
  final String value;
  final String? hint;
  final Widget? trailing;
  final VoidCallback onTap;

  const _PointRow({
    required this.dotColor,
    required this.label,
    required this.value,
    required this.onTap,
    this.hint,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
                Container(width: 2, height: 22, color: AppTheme.line),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 9.5,
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 1),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  if (hint != null)
                    Text(hint!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            const Icon(Icons.chevron_right_rounded, color: AppTheme.muted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _TinyChoice extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TinyChoice({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? AppTheme.primary : AppTheme.line),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: active ? AppTheme.primary : AppTheme.muted)),
      ),
    );
  }
}

class _PaymentChoice extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _PaymentChoice({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AppTheme.primary : AppTheme.line),
        ),
        child: Column(
          children: [
            Icon(icon, size: 17, color: active ? AppTheme.primary : AppTheme.muted),
            const SizedBox(height: 4),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: active ? AppTheme.primary : AppTheme.muted)),
          ],
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final bool pickup;
  const _MapPin({required this.pickup});

  @override
  Widget build(BuildContext context) {
    final color = pickup ? AppTheme.primary : AppTheme.accent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: .28), blurRadius: 10),
            ],
          ),
          child: Icon(pickup ? Icons.my_location_rounded : Icons.place_rounded,
              size: 17, color: Colors.white),
        ),
        const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 18),
      ],
    );
  }
}

class _DriverDot extends StatelessWidget {
  final NearbyDriver driver;
  const _DriverDot({required this.driver});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${driver.fullName} · ${driver.vehicleLabel ?? 'Xe'}',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.primary, width: 2),
          boxShadow: [
            BoxShadow(
                color: AppTheme.primary.withValues(alpha: .25),
                blurRadius: 12,
                spreadRadius: 2),
          ],
        ),
        child: const Icon(Icons.local_taxi_rounded, color: AppTheme.primary, size: 20),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, size: 21, color: AppTheme.ink),
        ),
      ),
    );
  }
}
