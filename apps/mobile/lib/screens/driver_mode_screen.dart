import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../widgets/app_ui.dart';
import '../widgets/ui.dart';

/// Minimal driver mode: go online, see incoming ride requests, accept one and
/// advance its status. Payment is collected directly from the passenger.
class DriverModeScreen extends StatefulWidget {
  const DriverModeScreen({super.key});

  @override
  State<DriverModeScreen> createState() => _DriverModeScreenState();
}

class _DriverModeScreenState extends State<DriverModeScreen> {
  bool _online = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<RideInfo> _incoming = const [];
  RideInfo? _current;
  Timer? _poll;
  double _lat = 21.0278;
  double _lng = 105.8342;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final presence = await AppScope.of(context).api.driverPresence();
      _online = presence.online;
      _lat = presence.lat;
      _lng = presence.lng;
      if (_online) {
        await _refreshRides();
        _poll?.cancel();
        _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refreshRides());
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshRides() async {
    try {
      final current = await AppScope.of(context).api.currentDriverRide();
      final incoming = current == null
          ? await AppScope.of(context).api.incomingRides()
          : <RideInfo>[];
      if (!mounted) return;
      setState(() {
        _current = current;
        _incoming = incoming;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _position() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        _lat = pos.latitude;
        _lng = pos.longitude;
      }
    } catch (_) {
      // Keep last known location; the API still works for the demo.
    }
  }

  Future<void> _toggle(bool value) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (value) await _position();
      final presence = await AppScope.of(context).api.setDriverPresence(
            online: value,
            lat: _lat,
            lng: _lng,
          );
      if (!mounted) return;
      setState(() {
        _online = presence.online;
        _lat = presence.lat;
        _lng = presence.lng;
        _incoming = const [];
        _current = null;
      });
      if (presence.online) {
        await _refreshRides();
        _poll?.cancel();
        _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refreshRides());
      } else {
        _poll?.cancel();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(RideInfo ride) async {
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      final accepted = await AppScope.of(context).api.acceptRide(ride.id);
      if (!mounted) return;
      setState(() {
        _current = accepted;
        _incoming = const [];
      });
      showInfo(context, 'Đã nhận chuyến. Di chuyển tới điểm đón khách.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
      await _refreshRides();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _action(String action) async {
    final ride = _current;
    if (ride == null) return;
    if (action == 'complete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hoàn tất chuyến?'),
          content: Text('Xác nhận bạn đã thu ${ride.paymentLabel.toLowerCase()} từ khách.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Chưa')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Đã thu tiền')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final updated = await AppScope.of(context).api.rideAction(ride.id, action);
      if (!mounted) return;
      setState(() => _current = updated.status == 'completed' ? null : updated);
      if (updated.status == 'completed') {
        showInfo(context, 'Chuyến đã hoàn tất. Thanh toán đã ghi nhận trực tiếp.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Chế độ tài xế'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Text(_online ? 'Online' : 'Offline',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _online ? AppTheme.success : AppTheme.muted)),
                Switch(
                  value: _online,
                  onChanged: _busy ? null : _toggle,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppTheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshRides,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                children: [
                  _OnlineCard(online: _online, busy: _busy, onToggle: _toggle),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(_error!,
                          style: const TextStyle(fontSize: 12, color: AppTheme.danger)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_current != null)
                    _CurrentRideCard(
                      ride: _current!,
                      busy: _busy,
                      onAction: _action,
                    )
                  else if (!_online)
                    const _OfflineState()
                  else if (_incoming.isEmpty)
                    const _NoRequests()
                  else ...[
                    const SectionHeader('Chuyến đang chờ'),
                    for (final ride in _incoming) ...[
                      _IncomingRideCard(
                        ride: ride,
                        busy: _busy,
                        onAccept: () => _accept(ride),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}

class _OnlineCard extends StatelessWidget {
  final bool online;
  final bool busy;
  final ValueChanged<bool> onToggle;
  const _OnlineCard({required this.online, required this.busy, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: online ? AppTheme.successSoft : AppTheme.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(online ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded,
                color: online ? AppTheme.success : AppTheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(online ? 'Bạn đang nhận chuyến' : 'Bạn đang offline',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                Text(
                  online
                      ? 'Yêu cầu mới sẽ hiện trong vài giây.'
                      : 'Bật online để nhận yêu cầu gần bạn.',
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
              ],
            ),
          ),
          Switch(
            value: online,
            onChanged: busy ? null : onToggle,
            activeThumbColor: Colors.white,
            activeTrackColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}

class _CurrentRideCard extends StatelessWidget {
  final RideInfo ride;
  final bool busy;
  final ValueChanged<String> onAction;
  const _CurrentRideCard({
    required this.ride,
    required this.busy,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final (label, action) = switch (ride.status) {
      'accepted' => ('Đã đến điểm đón', 'arrive'),
      'arrived' => ('Bắt đầu chuyến', 'start'),
      'in_progress' => ('Hoàn tất chuyến', 'complete'),
      _ => ('Đang xử lý...', ''),
    };
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(ride.statusLabel,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary)),
              ),
              const Spacer(),
              Text(ride.paymentLabel,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.muted)),
            ],
          ),
          const SizedBox(height: 10),
          Text(ride.passengerName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          if (ride.passengerRating != null)
            Text('★ ${ride.passengerRating!.toStringAsFixed(1)} · Khách hàng',
                style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
          const Divider(height: 20),
          _Stop(icon: Icons.my_location_rounded, color: AppTheme.primary, text: ride.pickupLabel),
          const SizedBox(height: 8),
          _Stop(icon: Icons.place_rounded, color: AppTheme.accent, text: ride.dropoffLabel),
          if (ride.note != null && ride.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Ghi chú: ${ride.note}',
                style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
          ],
          const SizedBox(height: 14),
          PrimaryButton(
            label: busy ? 'Đang cập nhật...' : label,
            icon: action == 'complete' ? Icons.check_rounded : Icons.arrow_forward_rounded,
            onPressed: busy || action.isEmpty ? null : () => onAction(action),
          ),
        ],
      ),
    );
  }
}

class _IncomingRideCard extends StatelessWidget {
  final RideInfo ride;
  final bool busy;
  final VoidCallback onAccept;
  const _IncomingRideCard({
    required this.ride,
    required this.busy,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(ride.passengerName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              if (ride.passengerRating != null) ...[
                const SizedBox(width: 5),
                const Icon(Icons.star_rounded, size: 13, color: AppTheme.accent),
                Text(' ${ride.passengerRating!.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
              ],
              const Spacer(),
              Text(ride.paymentLabel,
                  style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
            ],
          ),
          const SizedBox(height: 9),
          _Stop(icon: Icons.my_location_rounded, color: AppTheme.primary, text: ride.pickupLabel),
          const SizedBox(height: 6),
          _Stop(icon: Icons.place_rounded, color: AppTheme.accent, text: ride.dropoffLabel),
          if (ride.note != null && ride.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Ghi chú: ${ride.note}',
                style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text('Giá thỏa thuận trực tiếp với khách',
                    style: TextStyle(fontSize: 10, color: AppTheme.muted)),
              ),
              FilledButton(
                onPressed: busy ? null : onAccept,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  minimumSize: const Size(112, 42),
                ),
                child: const Text('Nhận chuyến'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Stop({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _OfflineState extends StatelessWidget {
  const _OfflineState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 30),
      child: Column(
        children: [
          Icon(Icons.local_taxi_outlined, size: 54, color: AppTheme.mutedLight),
          SizedBox(height: 10),
          Text('Bật online để bắt đầu',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text('Các yêu cầu gần bạn sẽ xuất hiện ở đây.',
              style: TextStyle(fontSize: 11.5, color: AppTheme.muted)),
        ],
      ),
    );
  }
}

class _NoRequests extends StatelessWidget {
  const _NoRequests();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 30),
      child: Column(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(height: 12),
          Text('Đang chờ chuyến mới...',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text('Kéo xuống để làm mới.',
              style: TextStyle(fontSize: 11, color: AppTheme.muted)),
        ],
      ),
    );
  }
}
