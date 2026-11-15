import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../widgets/app_ui.dart';
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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (value != null) setState(() => _date = value);
  }

  void _search() {
    final p = presets[_preset];
    Navigator.of(context).push(appRoute(ResultsScreen(
      fromLabel: p.fromLabel,
      fromLat: p.fromLat,
      fromLng: p.fromLng,
      toLabel: p.toLabel,
      toLat: p.toLat,
      toLng: p.toLng,
      date: _date,
      seats: _seats,
    )));
  }

  Future<void> _pickRoute() async {
    await showAppSheet<void>(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chọn tuyến đường',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Các tuyến đang có nhiều tài xế hoạt động',
                style: TextStyle(fontSize: 11.5, color: AppTheme.muted)),
            const SizedBox(height: 14),
            for (var i = 0; i < presets.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  onTap: () {
                    setState(() => _preset = i);
                    Navigator.pop(context);
                  },
                  padding: const EdgeInsets.all(14),
                  border: Border.all(
                      color: i == _preset ? AppTheme.primary : AppTheme.line,
                      width: i == _preset ? 1.5 : 1),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: i == _preset ? AppTheme.primarySoft : const Color(0xFFF3F6FA),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(Icons.route_rounded, size: 19, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(presets[i].name,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text('${presets[i].fromLabel} → ${presets[i].toLabel}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                          ],
                        ),
                      ),
                      if (i == _preset)
                        const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    final unread = AppScope.of(context).unread;
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 300 + top,
              decoration: const BoxDecoration(
                gradient: AppTheme.gradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
              ),
            ),
          ),
          ListView(
            padding: EdgeInsets.fromLTRB(18, top + 14, 18, 28),
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      (user?.fullName.isNotEmpty == true ? user!.fullName[0] : 'B').toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Xin chào, ${user?.fullName.split(' ').first ?? 'bạn'}',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        const Text('Bạn muốn đi đâu?',
                            style: TextStyle(
                                fontSize: 18, color: Colors.white, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  _HeaderIcon(
                    icon: Icons.chat_bubble_outline_rounded,
                    onTap: () => Navigator.of(context).push(appRoute(const ChatThreadsScreen())),
                  ),
                  const SizedBox(width: 8),
                  _HeaderIcon(
                    icon: Icons.notifications_none_rounded,
                    badge: unread,
                    onTap: () => Navigator.of(context).push(appRoute(const NotificationsScreen())),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              AppCard(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                shadow: true,
                child: Column(
                  children: [
                    InkWell(
                      onTap: _pickRoute,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppTheme.success, width: 2),
                                  ),
                                ),
                                Container(
                                  width: 2,
                                  height: 24,
                                  margin: const EdgeInsets.symmetric(vertical: 3),
                                  color: const Color(0xFFD8E2F3),
                                ),
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppTheme.accent, width: 2),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Điểm đón',
                                      style: TextStyle(
                                          fontSize: 9.5,
                                          color: AppTheme.muted,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2)),
                                  Text(presets[_preset].fromLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12.5, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 9),
                                  Text('Điểm đến',
                                      style: TextStyle(
                                          fontSize: 9.5,
                                          color: AppTheme.muted,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2)),
                                  Text(presets[_preset].toLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12.5, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F4F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.unfold_more_rounded,
                                  size: 18, color: AppTheme.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Ngày đi',
                                      style: TextStyle(
                                          fontSize: 9.5,
                                          color: AppTheme.muted,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded,
                                          size: 12, color: AppTheme.primary),
                                      const SizedBox(width: 5),
                                      Text(dayLabel(_date),
                                          style: const TextStyle(
                                              fontSize: 12.5, fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(width: 1, height: 30, color: AppTheme.line),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Số ghế',
                                style: TextStyle(
                                    fontSize: 9.5,
                                    color: AppTheme.muted,
                                    fontWeight: FontWeight.w700)),
                            Row(
                              children: [
                                _SeatButton(
                                  icon: Icons.remove_rounded,
                                  enabled: _seats > 1,
                                  onTap: () => setState(() => _seats--),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text('$_seats',
                                      style: const TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.w900)),
                                ),
                                _SeatButton(
                                  icon: Icons.add_rounded,
                                  enabled: _seats < 4,
                                  onTap: () => setState(() => _seats++),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Tìm chuyến',
                      icon: Icons.search_rounded,
                      onPressed: _search,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _DateQuick(
                    label: 'Hôm nay',
                    active: _isSameDay(_date, DateTime.now()),
                    onTap: () => setState(() => _date = DateTime.now()),
                  ),
                  const SizedBox(width: 8),
                  _DateQuick(
                    label: 'Ngày mai',
                    active: _isSameDay(_date, DateTime.now().add(const Duration(days: 1))),
                    onTap: () => setState(() => _date = DateTime.now().add(const Duration(days: 1))),
                  ),
                  const SizedBox(width: 8),
                  _DateQuick(label: 'Chọn ngày', active: false, onTap: _pickDate),
                ],
              ),
              const SectionHeader('Tuyến phổ biến'),
              SizedBox(
                height: 148,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  children: [
                    _PopularCard(
                      title: 'Hà Nội → Hải Phòng',
                      subtitle: '2 giờ 30 · 150.000đ',
                      icon: Icons.directions_car_filled_rounded,
                      image: 'assets/images/coast.jpg',
                      onTap: () {
                        setState(() => _preset = 0);
                        _search();
                      },
                    ),
                    const SizedBox(width: 10),
                    _PopularCard(
                      title: 'Hà Nội → Nội Bài',
                      subtitle: '45 phút · 90.000đ',
                      icon: Icons.flight_takeoff_rounded,
                      image: 'assets/images/hanoi.jpg',
                      onTap: () {
                        setState(() => _preset = 1);
                        _search();
                      },
                    ),
                  ],
                ),
              ),
              const SectionHeader('An tâm mỗi chuyến'),
              Row(
                children: const [
                  Expanded(
                      child: _Benefit(
                          icon: Icons.verified_user_rounded,
                          title: 'Tài xế KYC',
                          sub: 'CCCD & GPLX')),
                  SizedBox(width: 8),
                  Expanded(
                      child: _Benefit(
                          icon: Icons.lock_rounded,
                          title: 'Escrow',
                          sub: 'Giữ tiền an toàn')),
                  SizedBox(width: 8),
                  Expanded(
                      child: _Benefit(
                          icon: Icons.star_rounded,
                          title: 'Đánh giá thật',
                          sub: 'Sao & hoàn thành')),
                ],
              ),
              const SizedBox(height: 16),
              AppCard(
                gradient: const LinearGradient(colors: [Color(0xFF071A33), Color(0xFF12306B)]),
                border: null,
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.eco_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mỗi chuyến đi là một lựa chọn xanh',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
                          SizedBox(height: 3),
                          Text('Giảm xe cá nhân, giảm phát thải và chia sẻ chi phí.',
                              style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  const _HeaderIcon({required this.icon, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Badge.count(
            count: badge,
            isLabelVisible: badge > 0,
            backgroundColor: AppTheme.accent,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _SeatButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _SeatButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F4F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 15, color: enabled ? AppTheme.ink : AppTheme.mutedLight),
      ),
    );
  }
}

class _DateQuick extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DateQuick({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.ink : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppTheme.ink : AppTheme.line),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppTheme.muted)),
      ),
    );
  }
}

class _PopularCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String image;
  final IconData icon;
  final VoidCallback onTap;

  const _PopularCard({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 142,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(image, fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF071A33).withValues(alpha: 0.18),
                      const Color(0xFF071A33).withValues(alpha: 0.88),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(icon, color: Colors.white, size: 16),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_outward_rounded,
                            color: Colors.white70, size: 16),
                      ],
                    ),
                    const Spacer(),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;

  const _Benefit({required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(11),
      shadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: AppTheme.primary),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
          Text(sub, style: const TextStyle(fontSize: 9.5, color: AppTheme.muted)),
        ],
      ),
    );
  }
}
