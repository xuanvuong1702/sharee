import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/app_ui.dart';
import '../widgets/ui.dart';
import 'home_screen.dart';

class PublishScreen extends StatefulWidget {
  const PublishScreen({super.key});

  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> {
  late Future<List<Vehicle>> _vehicles;
  bool _started = false;
  Vehicle? _vehicle;
  int _preset = 0;
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
    setState(() => _busy = true);
    try {
      final p = presets[_preset];
      final body = {
        'vehicleId': _vehicle!.id,
        'origin': {'lat': p.fromLat, 'lng': p.fromLng, 'label': p.fromLabel},
        'destination': {'lat': p.toLat, 'lng': p.toLng, 'label': p.toLabel},
        'departureTime': _departure.toUtc().toIso8601String(),
        'pricePerSeat': price,
        'seatsTotal': _seats,
        'bookingMode': _manual ? 'manual' : 'instant',
        'luggage': true,
        'petsAllowed': false,
        'smokingAllowed': false,
        'stops': [
          {'name': p.fromLabel, 'lat': p.fromLat, 'lng': p.fromLng, 'allowPickup': true, 'allowDropoff': false},
          {'name': p.toLabel, 'lat': p.toLat, 'lng': p.toLng, 'allowPickup': false, 'allowDropoff': true},
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(presets[_preset].name,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text('${presets[_preset].fromLabel.split(',').first} → ${presets[_preset].toLabel.split(',').first}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                        ],
                      ),
                    ),
                    const Pill('Tuyến cố định', color: AppTheme.primary, background: AppTheme.primarySoft),
                  ],
                ),
              ),
              const SectionHeader('Chọn tuyến đường'),
              AppCard(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    for (var i = 0; i < presets.length; i++)
                      GestureDetector(
                        onTap: () => setState(() => _preset = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          margin: EdgeInsets.only(bottom: i == presets.length - 1 ? 0 : 6),
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: _preset == i ? AppTheme.primarySoft : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: _preset == i ? AppTheme.primary : AppTheme.line,
                                width: _preset == i ? 1.4 : 1),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _preset == i
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 18,
                                color: _preset == i ? AppTheme.primary : AppTheme.mutedLight,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(presets[i].name,
                                        style: const TextStyle(
                                            fontSize: 12.5, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 1),
                                    Text('${presets[i].fromLabel.split(',').first} → ${presets[i].toLabel.split(',').first}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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
