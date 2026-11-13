import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../widgets/ui.dart';
import 'chat_screen.dart';
import 'notifications_screen.dart';
import 'results_screen.dart';

class RoutePreset {
  final String name;
  final String fromLabel;
  final double fromLat;
  final double fromLng;
  final String toLabel;
  final double toLat;
  final double toLng;
  const RoutePreset(this.name, this.fromLabel, this.fromLat, this.fromLng, this.toLabel, this.toLat, this.toLng);
}

const presets = [
  RoutePreset('Hà Nội → Hải Phòng', 'Bến xe Mỹ Đình, Hà Nội', 21.0285, 105.7749, 'Lạch Tray, Hải Phòng', 20.8449, 106.6881),
  RoutePreset('Hà Nội → Nội Bài', 'Bến xe Mỹ Đình, Hà Nội', 21.0285, 105.7749, 'Sân bay Nội Bài', 21.2187, 105.7999),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _preset = 0;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  int _seats = 1;

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (value != null) setState(() => _date = value);
  }

  void _search() {
    final p = presets[_preset];
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultsScreen(
        fromLabel: p.fromLabel,
        fromLat: p.fromLat,
        fromLng: p.fromLng,
        toLabel: p.toLabel,
        toLat: p.toLat,
        toLng: p.toLng,
        date: _date,
        seats: _seats,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Xin chào, ${user?.fullName.split(' ').last ?? 'bạn'}',
                style: const TextStyle(fontSize: 13, color: AppTheme.muted, fontWeight: FontWeight.w500)),
            const Text('Đi đâu hôm nay?',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppTheme.ink)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatThreadsScreen())),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  for (var i = 0; i < presets.length; i++)
                    InkWell(
                      onTap: () => setState(() => _preset = i),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Icon(
                              i == _preset ? Icons.radio_button_checked : Icons.radio_button_off,
                              size: 18,
                              color: i == _preset ? AppTheme.primary : AppTheme.muted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(presets[i].name,
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 2),
                                  Text('${presets[i].fromLabel} → ${presets[i].toLabel}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Divider(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Ngày đi',
                                    style: TextStyle(fontSize: 9.5, color: AppTheme.muted, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 3),
                                Text(dayLabel(_date),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(width: 1, height: 30, color: const Color(0xFFE7ECF3)),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Số ghế',
                              style: TextStyle(fontSize: 9.5, color: AppTheme.muted, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: _seats > 1 ? () => setState(() => _seats--) : null,
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                              ),
                              Text('$_seats', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: _seats < 4 ? () => setState(() => _seats++) : null,
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _search,
            icon: const Icon(Icons.search_rounded),
            label: const Text('Tìm chuyến'),
          ),
          const SectionTitle('Tuyến phổ biến'),
          Card(
            child: Column(
              children: [
                _popular('Hà Nội → Hải Phòng', 'từ 150.000đ'),
                const Divider(height: 1),
                _popular('Hà Nội → Nội Bài', 'từ 90.000đ'),
                const Divider(height: 1),
                _popular('TP.HCM → Vũng Tàu', 'từ 180.000đ'),
              ],
            ),
          ),
          const SectionTitle('Vì sao chọn Sharee?'),
          Row(
            children: [
              Expanded(child: _benefit(Icons.verified_user_outlined, 'Đã xác thực', 'CCCD & GPLX')),
              const SizedBox(width: 8),
              Expanded(child: _benefit(Icons.payments_outlined, 'Giá rõ ràng', 'Không phụ phí')),
              const SizedBox(width: 8),
              Expanded(child: _benefit(Icons.support_agent, 'Hỗ trợ 24/7', 'Khi cần')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _popular(String title, String price) => ListTile(
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        trailing: Text(price, style: const TextStyle(fontSize: 11.5, color: AppTheme.muted)),
        onTap: _search,
      );

  Widget _benefit(IconData icon, String title, String sub) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7ECF3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppTheme.primary),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            Text(sub, style: const TextStyle(fontSize: 9.5, color: AppTheme.muted)),
          ],
        ),
      );
}
