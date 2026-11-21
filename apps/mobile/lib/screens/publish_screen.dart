import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/map_config.dart';
import '../core/models.dart';
import '../widgets/app_ui.dart';
import '../widgets/ui.dart';
import 'location_picker_screen.dart';
import 'verification_screen.dart';

class PublishScreen extends StatefulWidget {
  const PublishScreen({super.key});

  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> {
  late Future<List<Vehicle>> _vehicles;
  bool _started = false;
  bool _checkingVerification = true;
  VerificationInfo? _verification;
  Vehicle? _vehicle;
  GeoPlace? _from;
  GeoPlace? _to;
  DateTime _departure = DateTime.now().add(const Duration(days: 1, hours: 1));
  final _price = TextEditingController(text: '180000');
  int _seats = 3;
  bool _manual = false;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final api = AppScope.of(context).api;
    api.verification().then((info) {
      if (mounted) {
        setState(() {
          _verification = info;
          _checkingVerification = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _checkingVerification = false);
    });
    _vehicles = api.vehicles();
    _vehicles.then((list) {
      if (mounted && _vehicle == null && list.isNotEmpty) {
        setState(() => _vehicle = list.first);
      }
    });
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _departure,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_departure),
    );
    if (time == null) return;
    setState(() => _departure = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _addVehicle() async {
    final plate = TextEditingController();
    final model = TextEditingController(text: 'Toyota Vios');
    var seats = 4;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm xe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: plate,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Biển số', hintText: '30A-123.45'),
              ),
              const SizedBox(height: 9),
              TextField(
                controller: model,
                decoration: const InputDecoration(labelText: 'Dòng xe'),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  const Text('Số chỗ', style: TextStyle(fontSize: 12)),
                  const Spacer(),
                  IconButton(
                    onPressed: seats > 2 ? () => setDialogState(() => seats--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$seats', style: const TextStyle(fontWeight: FontWeight.w900)),
                  IconButton(
                    onPressed: seats < 7 ? () => setDialogState(() => seats++) : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Thêm')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (plate.text.trim().isEmpty) {
      if (mounted) showError(context, 'Nhập biển số xe');
      return;
    }
    try {
      final vehicle = await AppScope.of(context).api.createVehicle(
        make: 'Toyota',
        model: model.text.trim().isEmpty ? 'Toyota Vios' : model.text.trim(),
        plate: plate.text.trim(),
        seats: seats,
      );
      if (!mounted) return;
      setState(() {
        _vehicle = vehicle;
        _vehicles = AppScope.of(context).api.vehicles();
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _pickPoint(bool from) async {
    final place = await Navigator.of(context).push<GeoPlace>(
      appRoute(LocationPickerScreen(pickup: from)),
    );
    if (place == null || !mounted) return;
    setState(() {
      if (from) {
        _from = place;
      } else {
        _to = place;
      }
    });
  }

  Future<void> _submit() async {
    if (_vehicle == null) {
      showError(context, 'Bạn cần thêm xe trước khi đăng chuyến');
      return;
    }
    final price = int.tryParse(_price.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (price < 10000) {
      showError(context, 'Giá mỗi ghế tối thiểu 10.000đ');
      return;
    }
    if (_from == null || _to == null) {
      showError(context, 'Chọn điểm đón và điểm đến trên bản đồ');
      return;
    }
    setState(() => _busy = true);
    try {
      final from = _from!;
      final to = _to!;
      final body = {
        'vehicleId': _vehicle!.id,
        'origin': {'lat': from.lat, 'lng': from.lng, 'label': from.label},
        'destination': {'lat': to.lat, 'lng': to.lng, 'label': to.label},
        'departureTime': _departure.toUtc().toIso8601String(),
        'pricePerSeat': price,
        'seatsTotal': _seats,
        'bookingMode': _manual ? 'manual' : 'instant',
        'luggage': true,
        'petsAllowed': false,
        'smokingAllowed': false,
        'stops': [
          {'name': from.label, 'lat': from.lat, 'lng': from.lng, 'allowPickup': true, 'allowDropoff': false},
          {'name': to.label, 'lat': to.lat, 'lng': to.lng, 'allowPickup': false, 'allowDropoff': true},
        ],
      };
      await AppScope.of(context).api.createTrip(body);
      if (!mounted) return;
      showAppSheet<void>(
        context,
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(color: AppTheme.successSoft, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: AppTheme.success, size: 32),
              ),
              const SizedBox(height: 14),
              const Text('Đã đăng chuyến',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              const Text('Chuyến của bạn đã xuất hiện trong tìm kiếm.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.muted)),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Xong',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
      setState(() {
        _departure = DateTime.now().add(const Duration(days: 1, hours: 1));
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int get _priceValue => int.tryParse(_price.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    if (_checkingVerification) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_verification?.approved != true) {
      return Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Đăng chuyến', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              Text('Cần xác thực tài xế trước', style: TextStyle(fontSize: 11, color: AppTheme.muted)),
            ],
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                        color: Color(0xFFF3E8FF), shape: BoxShape.circle),
                    child: const Icon(Icons.verified_user_rounded,
                        color: Color(0xFF7C3AED), size: 24),
                  ),
                  const SizedBox(height: 12),
                  const Text('Xác thực tài xế để đăng chuyến',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text(
                    'Vì an toàn của hành khách, tài xế cần xác thực CCCD, GPLX, đăng ký xe, bảo hiểm và selfie trước khi đăng chuyến hoặc nhận booking.',
                    style: TextStyle(fontSize: 11.5, color: AppTheme.muted, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: 'Bắt đầu xác thực',
                    onPressed: () async {
                      await Navigator.of(context)
                          .push(appRoute(const VerificationScreen()));
                      if (!mounted) return;
                      final info = await AppScope.of(context).api.verification();
                      if (!mounted) return;
                      setState(() => _verification = info);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Đăng chuyến', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text('Chia sẻ ghế trống, giảm chi phí', style: TextStyle(fontSize: 11, color: AppTheme.muted)),
          ],
        ),
      ),
      body: FutureBuilder<List<Vehicle>>(
        future: _vehicles,
        builder: (context, snapshot) {
          final vehicles = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
            children: [
              AppCard(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.alt_route_rounded, color: AppTheme.primary, size: 21),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Chọn tuyến của bạn',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                          SizedBox(height: 2),
                          Text('Chạm bản đồ hoặc tìm địa chỉ để chọn điểm đón và điểm đến.',
                              style: TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                        ],
                      ),
                    ),
                    Pill('Bản đồ', color: AppTheme.primary, background: AppTheme.primarySoft),
                  ],
                ),
              ),
              const SectionHeader('Tuyến đường trên bản đồ'),
              AppCard(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 190,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: _from == null
                                ? const LatLng(21.0278, 105.8342)
                                : LatLng(_from!.lat, _from!.lng),
                            initialZoom: 12,
                            onTap: (_, point) => _pickPoint(_from == null),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: MapConfig.tileUrl,
                              userAgentPackageName: MapConfig.userAgent,
                            ),
                            if (_from != null && _to != null)
                              PolylineLayer(polylines: [
                                Polyline(
                                  points: [
                                    LatLng(_from!.lat, _from!.lng),
                                    LatLng(_to!.lat, _to!.lng),
                                  ],
                                  strokeWidth: 4,
                                  color: AppTheme.primary,
                                ),
                              ]),
                            MarkerLayer(markers: [
                              if (_from != null)
                                Marker(
                                  point: LatLng(_from!.lat, _from!.lng),
                                  width: 40,
                                  height: 40,
                                  child: const Icon(Icons.trip_origin_rounded,
                                      color: AppTheme.success, size: 30),
                                ),
                              if (_to != null)
                                Marker(
                                  point: LatLng(_to!.lat, _to!.lng),
                                  width: 40,
                                  height: 40,
                                  child: const Icon(Icons.location_on_rounded,
                                      color: AppTheme.accent, size: 34),
                                ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.trip_origin_rounded, color: AppTheme.success),
                      title: Text(_from?.label ?? 'Chọn điểm đón trên bản đồ',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.map_rounded, size: 18),
                      onTap: () => _pickPoint(true),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on_rounded, color: AppTheme.accent),
                      title: Text(_to?.label ?? 'Chọn điểm đến trên bản đồ',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.map_rounded, size: 18),
                      onTap: () => _pickPoint(false),
                    ),
                  ],
                ),
              ),
              const SectionHeader('Xe và thời gian'),
              AppCard(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    if (vehicles.isEmpty)
                      InkWell(
                        onTap: _addVehicle,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySoft,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFD5E1FF)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add_circle_outline_rounded,
                                  color: AppTheme.primary, size: 20),
                              SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Bạn chưa có xe',
                                        style: TextStyle(
                                            fontSize: 12, fontWeight: FontWeight.w800)),
                                    Text('Thêm xe để bắt đầu đăng chuyến',
                                        style: TextStyle(
                                            fontSize: 10, color: AppTheme.muted)),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded,
                                  size: 18, color: AppTheme.primary),
                            ],
                          ),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        key: ValueKey(_vehicle?.id ?? 'none'),
                        initialValue: _vehicle?.id,
                        items: vehicles
                            .map((v) => DropdownMenuItem(
                                value: v.id,
                                child: Text(v.label, style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _vehicle = vehicles.firstWhere((v) => v.id == value)),
                        decoration: InputDecoration(
                          labelText: 'Xe sử dụng',
                          prefixIcon: const Icon(Icons.directions_car_rounded, size: 19),
                          isDense: true,
                          suffixIcon: IconButton(
                            onPressed: _addVehicle,
                            icon: const Icon(Icons.add_rounded, size: 18),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _pickDateTime,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFD),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.line),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule_rounded, color: AppTheme.primary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Khởi hành',
                                      style: TextStyle(fontSize: 9.5, color: AppTheme.muted)),
                                  Text('${dayLabel(_departure)} · ${hhmm(_departure)}',
                                      style: const TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                size: 19, color: AppTheme.mutedLight),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SectionHeader('Giá và chỗ trống'),
              AppCard(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Giá mỗi ghế (VND)',
                        prefixIcon: Icon(Icons.payments_rounded, size: 19),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        for (final value in [150000, 180000, 200000])
                          Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: GestureDetector(
                              onTap: () => setState(() => _price.text = '$value'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _priceValue == value ? AppTheme.primary : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: _priceValue == value ? AppTheme.primary : AppTheme.line),
                                ),
                                child: Text(money(value),
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: _priceValue == value
                                            ? Colors.white
                                            : AppTheme.muted)),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 22),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Số ghế trống',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                            Text('Tối đa 7 ghế',
                                style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _seats > 1 ? () => setState(() => _seats--) : null,
                          icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
                          color: AppTheme.primary,
                        ),
                        Text('$_seats',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        IconButton(
                          onPressed: _seats < 7 ? () => setState(() => _seats++) : null,
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                          color: AppTheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SectionHeader('Cách nhận khách'),
              Row(
                children: [
                  Expanded(
                    child: _BookingModeCard(
                      icon: Icons.bolt_rounded,
                      title: 'Đặt ngay',
                      subtitle: 'Khách tự đặt, giữ ghế 10 phút',
                      active: !_manual,
                      onTap: () => setState(() => _manual = false),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _BookingModeCard(
                      icon: Icons.how_to_reg_rounded,
                      title: 'Duyệt tay',
                      subtitle: 'Bạn chấp nhận từng yêu cầu',
                      active: _manual,
                      onTap: () => setState(() => _manual = true),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Giá mỗi ghế',
                      style: TextStyle(fontSize: 9.5, color: AppTheme.muted)),
                  Text(money(_priceValue),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: PrimaryButton(
                  label: 'Đăng chuyến',
                  icon: Icons.arrow_forward_rounded,
                  loading: _busy,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  const _BookingModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? AppTheme.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? AppTheme.primary : AppTheme.line, width: active ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: active ? AppTheme.primary : AppTheme.muted),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 9.5, color: AppTheme.muted, height: 1.3)),
          ],
        ),
      ),
    );
  }
}
