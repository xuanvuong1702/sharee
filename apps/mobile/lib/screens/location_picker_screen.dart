import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../core/app_state.dart';
import '../core/map_config.dart';
import '../core/models.dart';
import '../widgets/app_ui.dart';

/// Search or tap the map to choose a pickup/dropoff.
class LocationPickerScreen extends StatefulWidget {
  final bool pickup;
  final GeoPlace? initial;

  const LocationPickerScreen({super.key, required this.pickup, this.initial});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const _hanoi = LatLng(21.0278, 105.8342);
  final _map = MapController();
  final _search = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  GeoPlace? _picked;
  List<GeoPlace> _results = const [];
  bool _searching = false;
  bool _reverse = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
    _search.addListener(_onQuery);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onQuery() {
    _debounce?.cancel();
    final q = _search.text.trim();
    if (q.length < 2) {
      setState(() => _results = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final items = await AppScope.of(context).api.geoSearch(q);
      if (!mounted) return;
      setState(() => _results = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectResult(GeoPlace place) {
    setState(() {
      _picked = place;
      _results = const [];
      _search.text = place.label;
      _focus.unfocus();
    });
    _map.move(LatLng(place.lat, place.lng), 16);
  }

  Future<void> _onMapTap(TapPosition _, LatLng point) async {
    setState(() {
      _reverse = true;
      _error = null;
      _picked = GeoPlace(
        label: 'Vị trí đã chọn',
        fullName: '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
        lat: point.latitude,
        lng: point.longitude,
      );
      _results = const [];
    });
    try {
      final place = await AppScope.of(context).api.geoReverse(point.latitude, point.longitude);
      if (!mounted) return;
      setState(() => _picked = place);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _reverse = false);
    }
  }

  Future<void> _locate() async {
    setState(() => _error = null);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Vui lòng bật định vị trên thiết bị.';
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'Bạn đã từ chối quyền vị trí. Hãy bật trong Cài đặt.';
      }
      if (permission == LocationPermission.denied) {
        throw 'Cần quyền vị trí để chọn điểm đón.';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      final place = await AppScope.of(context).api.geoReverse(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _picked = place);
      _map.move(LatLng(place.lat, place.lng), 16);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.pickup ? 'Chọn điểm đón' : 'Chọn điểm đến';
    final center = _picked == null ? _hanoi : LatLng(_picked!.lat, _picked!.lng);
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: center,
              initialZoom: _picked == null ? 14 : 16,
              onTap: _onMapTap,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.tileUrl,
                userAgentPackageName: MapConfig.userAgent,
              ),
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_picked!.lat, _picked!.lng),
                      width: 54,
                      height: 54,
                      child: _Pin(pickup: widget.pickup),
                    ),
                  ],
                ),
            ],
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      _RoundButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: AppTheme.softShadow,
                          ),
                          child: Center(
                            child: Text(title,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _RoundButton(icon: Icons.my_location_rounded, onTap: _locate),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _search,
                    focusNode: _focus,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: widget.pickup ? 'Tìm điểm đón...' : 'Tìm điểm đến...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : _search.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () => setState(() {
                                    _search.clear();
                                    _results = const [];
                                  }),
                                )
                              : null,
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  if (_results.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 340),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shrinkWrap: true,
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 52),
                        itemBuilder: (context, i) {
                          final p = _results[i];
                          return ListTile(
                            leading: _PlaceIcon(kind: p.kind),
                            title: Text(p.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(p.fullName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5)),
                            onTap: () => _selectResult(p),
                          );
                        },
                      ),
                    ),
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 18, color: AppTheme.danger),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(
                                      fontSize: 12, color: AppTheme.danger))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.pickup ? 'Điểm đón' : 'Điểm đến',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.muted,
                          letterSpacing: .5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _picked?.label ?? 'Chạm bản đồ hoặc tìm kiếm',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    if (_picked != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        _picked!.fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
                      ),
                    ],
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: _reverse ? 'Đang lấy địa chỉ...' : 'Chọn điểm này',
                      icon: Icons.check_rounded,
                      onPressed: _picked == null || _reverse
                          ? null
                          : () => Navigator.of(context).pop(_picked),
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
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  final bool pickup;
  const _Pin({required this.pickup});

  @override
  Widget build(BuildContext context) {
    final color = pickup ? AppTheme.primary : AppTheme.accent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: .3), blurRadius: 12),
            ],
          ),
          child: Icon(pickup ? Icons.my_location_rounded : Icons.place_rounded,
              color: Colors.white, size: 20),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _PinTail(color: color),
        ),
      ],
    );
  }
}

class _PinTail extends CustomPainter {
  final Color color;
  _PinTail({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PinTail old) => old.color != color;
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

class _PlaceIcon extends StatelessWidget {
  final String? kind;
  const _PlaceIcon({this.kind});

  @override
  Widget build(BuildContext context) {
    final icon = switch (kind) {
      'airport' => Icons.flight_rounded,
      'bus' => Icons.directions_bus_rounded,
      'mall' => Icons.storefront_rounded,
      'attraction' => Icons.park_rounded,
      _ => Icons.place_rounded,
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 19, color: AppTheme.primary),
    );
  }
}
