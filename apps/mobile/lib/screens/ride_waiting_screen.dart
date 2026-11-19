import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_state.dart';
import '../core/map_config.dart';
import '../core/models.dart';
import '../widgets/app_ui.dart';

/// Live status for a ride request. The app never shows or changes a fare;
/// payment is settled between passenger and driver.
class RideWaitingScreen extends StatefulWidget {
  final String rideId;
  const RideWaitingScreen({super.key, required this.rideId});

  @override
  State<RideWaitingScreen> createState() => _RideWaitingScreenState();
}

class _RideWaitingScreenState extends State<RideWaitingScreen> {
  final _map = MapController();
  RideInfo? _ride;
  Timer? _poll;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _error = null);
    try {
      final ride = await AppScope.of(context).api.ride(widget.rideId);
      if (!mounted) return;
      setState(() {
        _ride = ride;
        _error = null;
      });
      if (ride.status == 'completed' || ride.status == 'cancelled') {
        _poll?.cancel();
      }
      if (silent && ride.driver != null) {
        // Keep the camera around both points when the driver is assigned.
        _fit();
      }
    } catch (e) {
      if (!mounted) return;
      if (!silent) setState(() => _error = e.toString());
    }
  }

  void _fit() {
    final r = _ride;
    if (r == null) return;
    _map.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints([
        LatLng(r.pickupLat, r.pickupLng),
        LatLng(r.dropoffLat, r.dropoffLng),
      ]),
      padding: const EdgeInsets.fromLTRB(36, 120, 36, 380),
    ));
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Huỷ chuyến?'),
        content: const Text('Tài xế sẽ được thông báo. Bạn có thể đặt lại sau.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Giữ chuyến')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Huỷ chuyến')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context).api.cancelRide(widget.rideId, 'Người đi huỷ');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _ride;
    final center = r == null
        ? const LatLng(21.0278, 105.8342)
        : LatLng(r.pickupLat, r.pickupLng);
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
              if (r != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(r.pickupLat, r.pickupLng),
                      width: 40,
                      height: 48,
                      child: const _SmallPin(color: AppTheme.primary, icon: Icons.my_location_rounded),
                    ),
                    Marker(
                      point: LatLng(r.dropoffLat, r.dropoffLng),
                      width: 40,
                      height: 48,
                      child: const _SmallPin(color: AppTheme.accent, icon: Icons.place_rounded),
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
                          Icon(
                            r?.status == 'completed'
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_checked_rounded,
                            color: r?.status == 'completed'
                                ? AppTheme.success
                                : AppTheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(r?.statusLabel ?? 'Đang kết nối...',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w800)),
                          ),
                          if (r?.status == 'searching')
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
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
              child: r == null
                  ? const AppCard(child: Center(child: CircularProgressIndicator()))
                  : AppCard(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StatusHeader(ride: r),
                          const SizedBox(height: 14),
                          _RouteRow(
                            icon: Icons.my_location_rounded,
                            color: AppTheme.primary,
                            label: 'Điểm đón',
                            value: r.pickupLabel,
                          ),
                          const SizedBox(height: 9),
                          _RouteRow(
                            icon: Icons.place_rounded,
                            color: AppTheme.accent,
                            label: 'Điểm đến',
                            value: r.dropoffLabel,
                          ),
                          if (r.driver != null) ...[
                            const Divider(height: 22),
                            _DriverCard(ride: r),
                          ],
                          const Divider(height: 22),
                          Row(
                            children: [
                              const Icon(Icons.payments_outlined,
                                  size: 17, color: AppTheme.muted),
                              const SizedBox(width: 6),
                              Text('Thanh toán: ${r.paymentLabel}',
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w700)),
                              const Spacer(),
                              const Text('Trực tiếp với tài xế',
                                  style: TextStyle(fontSize: 10, color: AppTheme.muted)),
                            ],
                          ),
                          if (r.status == 'searching' || r.status == 'accepted' || r.status == 'arrived') ...[
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _busy ? null : _cancel,
                              style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.danger,
                                  minimumSize: const Size.fromHeight(42)),
                              child: const Text('Huỷ chuyến'),
                            ),
                          ],
                          if (r.status == 'completed') ...[
                            const SizedBox(height: 12),
                            PrimaryButton(
                              label: 'Xong',
                              icon: Icons.check_rounded,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(_error!,
                                  style: const TextStyle(
                                      fontSize: 11, color: AppTheme.danger)),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  final RideInfo ride;
  const _StatusHeader({required this.ride});

  @override
  Widget build(BuildContext context) {
    final (icon, title, body) = switch (ride.status) {
      'searching' => (
          Icons.wifi_tethering_rounded,
          'Đang gửi đến tài xế',
          'Yêu cầu đã được gửi đến các tài xế đang online gần bạn.'
        ),
      'accepted' => (
          Icons.local_taxi_rounded,
          'Tài xế đang đến',
          'Tài xế đã nhận chuyến và đang di chuyển tới điểm đón.'
        ),
      'arrived' => (
          Icons.location_on_rounded,
          'Tài xế đã đến',
          'Bạn kiểm tra biển số xe trước khi lên xe nhé.'
        ),
      'in_progress' => (
          Icons.route_rounded,
          'Đang di chuyển',
          'Chuyến đi đang diễn ra. Liên hệ tài xế nếu cần hỗ trợ.'
        ),
      'completed' => (
          Icons.check_circle_rounded,
          'Chuyến đã hoàn tất',
          'Cảm ơn bạn đã đi cùng Sharee. Thanh toán trực tiếp cho tài xế.'
        ),
      _ => (Icons.info_outline_rounded, 'Chuyến đã huỷ', 'Bạn có thể đặt chuyến mới.'),
    };
    final color = ride.status == 'completed'
        ? AppTheme.success
        : ride.status == 'cancelled'
            ? AppTheme.muted
            : AppTheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(body,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppTheme.muted, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _RouteRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(fontSize: 10, color: AppTheme.muted, fontWeight: FontWeight.w700)),
        Expanded(
          child: Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _DriverCard extends StatelessWidget {
  final RideInfo ride;
  const _DriverCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    final d = ride.driver!;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primarySoft,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            d.fullName.isNotEmpty ? d.fullName[0].toUpperCase() : 'T',
            style: const TextStyle(
                color: AppTheme.primary, fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.fullName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                '${d.vehicleLabel}${d.plate != null ? ' · ${d.plate}' : ''}',
                style: const TextStyle(fontSize: 10.5, color: AppTheme.muted),
              ),
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 12, color: AppTheme.accent),
                  Text(' ${d.rating.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
        if (d.phoneMasked != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(d.phoneMasked!,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

class _SmallPin extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _SmallPin({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
        const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 18),
      ],
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
