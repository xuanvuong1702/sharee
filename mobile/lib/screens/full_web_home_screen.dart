import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/app_ui.dart';
import 'chat_screen.dart';
import 'daily_screen.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'results_screen.dart';

class FullWebHomeScreen extends StatefulWidget {
  final VoidCallback? onPublish;
  const FullWebHomeScreen({super.key, this.onPublish});

  @override
  State<FullWebHomeScreen> createState() => _FullWebHomeScreenState();
}

class _FullWebHomeScreenState extends State<FullWebHomeScreen> {
  int _preset = 0;
  int _seats = 1;
  DateTime _date = DateTime.now().add(const Duration(days: 1));

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

  void _search([int? index]) {
    final p = presets[index ?? _preset];
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

  Future<void> _downloadApp() async {
    final uri = Uri.parse('https://github.com/xuanvuong1702/sharee/releases/latest');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được trang tải app')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.user;
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(28, top + 18, 28, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Xin chào, ${user?.fullName.split(' ').first ?? 'bạn'}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                        const SizedBox(height: 2),
                        const Text('Hôm nay bạn muốn đi đâu?',
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.7)),
                      ],
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _downloadApp,
                      icon: const Icon(Icons.android_rounded, size: 16),
                      label: const Text('Tải APK'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppTheme.line),
                        minimumSize: const Size(112, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _WebIcon(
                      icon: Icons.chat_bubble_outline_rounded,
                      onTap: () =>
                          Navigator.of(context).push(appRoute(const ChatThreadsScreen())),
                    ),
                    const SizedBox(width: 8),
                    _WebIcon(
                      icon: Icons.notifications_none_rounded,
                      badge: state.unread,
                      onTap: () =>
                          Navigator.of(context).push(appRoute(const NotificationsScreen())),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final hero = _Hero(
                    user: user,
                    onPublish: widget.onPublish,
                  );
                  final search = _SearchCard(
                    preset: _preset,
                    date: _date,
                    seats: _seats,
                    onPreset: (value) => setState(() => _preset = value),
                    onDate: _pickDate,
                    onSeats: (value) => setState(() => _seats = value),
                    onSearch: _search,
                  );
                  if (!wide) {
                    return Column(children: [hero, const SizedBox(height: 14), search]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 11, child: hero),
                      const SizedBox(width: 16),
                      Expanded(flex: 9, child: search),
                    ],
                  );
                }),
                const SizedBox(height: 26),
                Row(
                  children: [
                    const Text('Tuyến phổ biến',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    Text('Giá từ 90.000đ',
                        style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final cross = width > 1000 ? 4 : width > 650 ? 2 : 1;
                  return GridView.count(
                    crossAxisCount: cross,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: cross == 1 ? 2.4 : (cross == 2 ? 1.7 : 1.7),
                    children: [
                      _RouteCard(
                        title: 'Hà Nội → Hải Phòng',
                        subtitle: 'Bến xe Mỹ Đình → Lạch Tray',
                        price: 180000,
                        icon: Icons.directions_car_filled_rounded,
                        onTap: () {
                          setState(() => _preset = 0);
                          _search(0);
                        },
                      ),
                      _RouteCard(
                        title: 'Hà Nội → Nội Bài',
                        subtitle: 'Mỹ Đình → Sân bay Nội Bài',
                        price: 90000,
                        icon: Icons.flight_takeoff_rounded,
                        onTap: () {
                          setState(() => _preset = 1);
                          _search(1);
                        },
                      ),
                      _RouteCard(
                        title: 'Daily shuttle',
                        subtitle: 'Tuyến cố định hằng ngày',
                        price: 15000,
                        icon: Icons.route_rounded,
                        onTap: () => Navigator.of(context).push(appRoute(const DailyScreen())),
                      ),
                      _RouteCard(
                        title: 'Đăng chuyến',
                        subtitle: 'Chia sẻ ghế trống, giảm chi phí',
                        price: 0,
                        icon: Icons.add_road_rounded,
                        onTap: widget.onPublish,
                        actionLabel: 'Đăng ngay',
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 26),
                const Text('Vì sao chọn Sharee?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (context, constraints) {
                  final cross = constraints.maxWidth > 900 ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: cross,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: cross == 4 ? 2.2 : 1.6,
                    children: const [
                      _Feature(
                        icon: Icons.verified_user_rounded,
                        title: 'Tài xế xác thực',
                        text: 'Hồ sơ, GPLX và phương tiện rõ ràng.',
                      ),
                      _Feature(
                        icon: Icons.payments_rounded,
                        title: 'Giá minh bạch',
                        text: 'Biết trước chi phí, không phụ phí ẩn.',
                      ),
                      _Feature(
                        icon: Icons.near_me_rounded,
                        title: 'Theo dõi trực tiếp',
                        text: 'Xem vị trí và ETA trên bản đồ.',
                      ),
                      _Feature(
                        icon: Icons.favorite_rounded,
                        title: 'Tip tài xế',
                        text: 'Ủng hộ tài xế bằng VietQR hoặc tiền mặt.',
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 26),
                AppCard(
                  gradient: AppTheme.gradient,
                  border: null,
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Có chuyến đi trống?',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(
                              'Đăng chuyến miễn phí, chia sẻ chi phí và kết nối với hành khách.',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 11.5,
                                  height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton(
                        onPressed: widget.onPublish,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primary,
                          minimumSize: const Size(150, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        child: const Text('Đăng chuyến',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Center(
                  child: Text('Sharee · Đi chung để hành trình nhẹ nhàng hơn',
                      style: TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WebIcon extends StatelessWidget {
  final IconData icon;
  final int badge;
  final VoidCallback onTap;

  const _WebIcon({required this.icon, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppTheme.line),
            ),
            child: Icon(icon, size: 20, color: AppTheme.ink),
          ),
          if (badge > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.danger,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$badge',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final AppUser? user;
  final VoidCallback? onPublish;
  const _Hero({required this.user, this.onPublish});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF08265C), Color(0xFF1657E8)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: AppTheme.liftedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Text('CARPOOLING & DAILY SHUTTLE',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8)),
          ),
          const SizedBox(height: 18),
          const Text('Đi chung một chuyến,\nchia sẻ một hành trình.',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8)),
          const SizedBox(height: 10),
          Text(
            'Đặt ghế nhanh, theo dõi trực tiếp và tip tài xế ngay trên một ứng dụng.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75), fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              _HeroStat(value: '10K+', label: 'Hành khách'),
              const SizedBox(width: 22),
              _HeroStat(value: '4.9', label: 'Đánh giá'),
              const SizedBox(width: 22),
              _HeroStat(value: '24/7', label: 'Hỗ trợ'),
            ],
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: onPublish,
            icon: const Icon(Icons.add_road_rounded, size: 17),
            label: const Text('Đăng chuyến của bạn'),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  const _HeroStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        Text(label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 9.5)),
      ],
    );
  }
}

class _SearchCard extends StatelessWidget {
  final int preset;
  final DateTime date;
  final int seats;
  final ValueChanged<int> onPreset;
  final VoidCallback onDate;
  final ValueChanged<int> onSeats;
  final VoidCallback onSearch;

  const _SearchCard({
    required this.preset,
    required this.date,
    required this.seats,
    required this.onPreset,
    required this.onDate,
    required this.onSeats,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tìm chuyến',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          const Text('Chọn tuyến và ngày khởi hành',
              style: TextStyle(fontSize: 10.5, color: AppTheme.muted)),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: preset,
            decoration: const InputDecoration(labelText: 'Tuyến đường'),
            items: [
              for (var i = 0; i < presets.length; i++)
                DropdownMenuItem(value: i, child: Text(presets[i].name)),
            ],
            onChanged: (value) => value == null ? null : onPreset(value),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Ngày đi'),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 15, color: AppTheme.muted),
                        const SizedBox(width: 7),
                        Text(dayLabel(date), style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Số ghế'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('$seats ghế',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                      _RoundIcon(
                        icon: Icons.remove_rounded,
                        onTap: seats > 1 ? () => onSeats(seats - 1) : null,
                      ),
                      const SizedBox(width: 4),
                      _RoundIcon(
                        icon: Icons.add_rounded,
                        onTap: seats < 4 ? () => onSeats(seats + 1) : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PrimaryButton(label: 'Tìm chuyến', onPressed: onSearch),
          const SizedBox(height: 9),
          const Row(
            children: [
              Icon(Icons.verified_rounded, size: 13, color: AppTheme.success),
              SizedBox(width: 4),
              Expanded(
                child: Text('Thanh toán an toàn · Hỗ trợ hoàn tiền',
                    style: TextStyle(fontSize: 9.5, color: AppTheme.muted)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundIcon({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F4F9),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 15, color: AppTheme.ink),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int price;
  final IconData icon;
  final VoidCallback? onTap;
  final String? actionLabel;

  const _RouteCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.icon,
    this.onTap,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primary),
          ),
          const Spacer(),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
          const SizedBox(height: 8),
          Text(actionLabel ?? (price > 0 ? 'Từ ${money(price)}' : ''),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _Feature({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      shadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppTheme.primary),
          const Spacer(),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppTheme.muted, height: 1.35)),
        ],
      ),
    );
  }
}
