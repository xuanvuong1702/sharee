import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/ui.dart';
import 'home_screen.dart';

class PublishScreen extends StatefulWidget {
  const PublishScreen({super.key});

  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> {
  late Future<List<Vehicle>> _vehicles;
  Vehicle? _vehicle;
  int _preset = 0;
  DateTime _departure = DateTime.now().add(const Duration(days: 1, hours: 1));
  final _price = TextEditingController(text: '180000');
  int _seats = 3;
  bool _manual = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _vehicles = AppScope.of(context).api.vehicles();
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
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Đã đăng chuyến'),
          content: const Text('Chuyến của bạn đã xuất hiện trong tìm kiếm.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng chuyến', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
      body: FutureBuilder<List<Vehicle>>(
        future: _vehicles,
        builder: (context, snapshot) {
          final vehicles = snapshot.data ?? [];
          if (snapshot.connectionState == ConnectionState.done && _vehicle == null && vehicles.isNotEmpty) {
            _vehicle = vehicles.first;
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tuyến đường', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      for (var i = 0; i < presets.length; i++)
                        RadioListTile<int>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: i,
                          groupValue: _preset,
                          onChanged: (value) => setState(() => _preset = value ?? 0),
                          title: Text(presets[i].name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          subtitle: Text('${presets[i].fromLabel} → ${presets[i].toLabel}',
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
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
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _vehicle?.id,
                        items: vehicles
                            .map((v) => DropdownMenuItem(value: v.id, child: Text(v.label, style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (value) => setState(() => _vehicle = vehicles.firstWhere((v) => v.id == value)),
                        decoration: const InputDecoration(isDense: true),
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule, color: AppTheme.primary),
                        title: const Text('Giờ khởi hành', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                        subtitle: Text('${dayLabel(_departure)} · ${hhmm(_departure)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _pickDateTime,
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
                      const Text('Giá & số ghế', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _price,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Giá mỗi ghế (VND)'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Số ghế trống', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          IconButton(
                            onPressed: _seats > 1 ? () => setState(() => _seats--) : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('$_seats', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          IconButton(
                            onPressed: _seats < 7 ? () => setState(() => _seats++) : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _manual,
                        onChanged: (value) => setState(() => _manual = value),
                        title: const Text('Duyệt khách thủ công', style: TextStyle(fontSize: 12.5)),
                        subtitle: const Text('Khách gửi yêu cầu, bạn chấp nhận', style: TextStyle(fontSize: 10)),
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
                    : const Text('Đăng chuyến'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Giá gợi ý dựa trên quãng đường. Bạn có thể sửa trước khi đăng.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: AppTheme.muted),
              ),
            ],
          );
        },
      ),
    );
  }
}
