import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/ui.dart';
import 'home_screen.dart';

class RecurringTripsScreen extends StatefulWidget {
  const RecurringTripsScreen({super.key});

  @override
  State<RecurringTripsScreen> createState() => _RecurringTripsScreenState();
}

class _RecurringTripsScreenState extends State<RecurringTripsScreen> {
  late Future<List<RecurringTrip>> _future;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  void _load() {
    _future = AppScope.of(context).api.recurringTrips();
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RecurringFormScreen()),
    );
    if (created == true) setState(_load);
  }

  Future<void> _pause(RecurringTrip trip) async {
    try {
      await AppScope.of(context).api.pauseRecurringTrip(trip.id);
      setState(_load);
      if (mounted) showInfo(context, 'Đã tạm dừng chuyến định kỳ');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chuyến định kỳ'),
        actions: [
          IconButton(onPressed: _create, icon: const Icon(Icons.add)),
        ],
      ),
      body: FutureBuilder<List<RecurringTrip>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_repeat, size: 54, color: AppTheme.muted),
                  const SizedBox(height: 10),
                  const Text('Chưa có lịch chạy định kỳ'),
                  const SizedBox(height: 6),
                  const Text('Tạo lịch để chuyến tự động xuất hiện mỗi tuần.',
                      style: TextStyle(fontSize: 11, color: AppTheme.muted)),
                  const SizedBox(height: 14),
                  FilledButton(onPressed: _create, child: const Text('Tạo lịch chạy')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(_load),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final trip = items[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(trip.departureTime,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(trip.weekdayLabel,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
                            ),
                            StatusPill(status: trip.active ? 'confirmed' : 'cancelled'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('${trip.originLabel} → ${trip.destinationLabel}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(
                            '${money(trip.pricePerSeat)}/ghế · ${trip.seatsTotal} ghế · ${trip.upcomingTrips} chuyến sắp tới',
                            style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                        if (trip.active)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _pause(trip),
                              child: const Text('Tạm dừng', style: TextStyle(color: AppTheme.danger)),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class RecurringFormScreen extends StatefulWidget {
  const RecurringFormScreen({super.key});

  @override
  State<RecurringFormScreen> createState() => _RecurringFormScreenState();
}

class _RecurringFormScreenState extends State<RecurringFormScreen> {
  late Future<List<Vehicle>> _vehicles;
  bool _started = false;
  Vehicle? _vehicle;
  int _preset = 0;
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 30);
  final Set<int> _weekdays = {1, 2, 3, 4, 5};
  final _price = TextEditingController(text: '180000');
  int _seats = 3;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _vehicles = AppScope.of(context).api.vehicles();
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(context: context, initialTime: _time);
    if (value != null) setState(() => _time = value);
  }

  Future<void> _submit() async {
    if (_vehicle == null) {
      showError(context, 'Bạn cần thêm xe trước');
      return;
    }
    if (_weekdays.isEmpty) {
      showError(context, 'Chọn ít nhất một ngày');
      return;
    }
    final price = int.tryParse(_price.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (price < 10000) {
      showError(context, 'Giá tối thiểu 10.000đ');
      return;
    }
    setState(() => _busy = true);
    try {
      final p = presets[_preset];
      final time =
          '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
      await AppScope.of(context).api.createRecurringTrip({
        'vehicleId': _vehicle!.id,
        'origin': {'lat': p.fromLat, 'lng': p.fromLng, 'label': p.fromLabel},
        'destination': {'lat': p.toLat, 'lng': p.toLng, 'label': p.toLabel},
        'departureTime': time,
        'weekdays': _weekdays.toList()..sort(),
        'pricePerSeat': price,
        'seatsTotal': _seats,
        'bookingMode': 'instant',
        'luggage': true,
        'petsAllowed': false,
        'smokingAllowed': false,
        'stops': [
          {'name': p.fromLabel, 'lat': p.fromLat, 'lng': p.fromLng, 'allowPickup': true, 'allowDropoff': false},
          {'name': p.toLabel, 'lat': p.toLat, 'lng': p.toLng, 'allowPickup': false, 'allowDropoff': true},
        ],
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch chạy định kỳ')),
      body: FutureBuilder<List<Vehicle>>(
        future: _vehicles,
        builder: (context, snapshot) {
          final vehicles = snapshot.data ?? [];
          if (snapshot.connectionState == ConnectionState.done && _vehicle == null && vehicles.isNotEmpty) {
            _vehicle = vehicles.first;
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tuyến', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      for (var i = 0; i < presets.length; i++)
                        RadioListTile<int>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: i,
                          groupValue: _preset,
                          onChanged: (value) => setState(() => _preset = value ?? 0),
                          title: Text(presets[i].name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Xe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      DropdownButtonFormField<String>(
                        initialValue: _vehicle?.id,
                        items: vehicles
                            .map((v) => DropdownMenuItem(
                                value: v.id,
                                child: Text(v.label, style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _vehicle = vehicles.firstWhere((v) => v.id == value)),
                        decoration: const InputDecoration(isDense: true),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule, color: AppTheme.primary),
                        title: const Text('Giờ khởi hành',
                            style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                        subtitle: Text(_time.format(context),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.ink)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _pickTime,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ngày chạy',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (var day = 1; day <= 7; day++)
                            FilterChip(
                              label: Text(day == 7 ? 'CN' : 'T$day',
                                  style: const TextStyle(fontSize: 11)),
                              selected: _weekdays.contains(day),
                              onSelected: (selected) => setState(() {
                                if (selected) {
                                  _weekdays.add(day);
                                } else {
                                  _weekdays.remove(day);
                                }
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _price,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Giá mỗi ghế (VND)'),
                      ),
                      Row(
                        children: [
                          const Text('Số ghế', style: TextStyle(fontSize: 12.5)),
                          const Spacer(),
                          IconButton(
                            onPressed: _seats > 1 ? () => setState(() => _seats--) : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('$_seats',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          IconButton(
                            onPressed: _seats < 7 ? () => setState(() => _seats++) : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Tạo lịch chạy'),
              ),
              const SizedBox(height: 8),
              const Text('Hệ thống tự tạo chuyến cho 14 ngày tới và tiếp tục mở rộng.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: AppTheme.muted)),
            ],
          );
        },
      ),
    );
  }
}
