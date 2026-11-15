import 'package:flutter/material.dart';

import '../core/app_state.dart';

class DesktopSidebar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  const DesktopSidebar({super.key, required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.user;
    return Container(
      width: 236,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF071B3E), Color(0xFF0A2C66)],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 22, 20, 22),
              child: Row(
                children: [
                  _BrandMark(),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sharee',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5)),
                      Text('Đi chung, đi xa hơn',
                          style: TextStyle(color: Colors.white54, fontSize: 9.5)),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 2, 20, 7),
              child: Text('ĐIỀU HƯỚNG',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2)),
            ),
            _SideItem(
              icon: Icons.home_rounded,
              label: 'Trang chủ',
              active: index == 0,
              onTap: () => onSelect(0),
            ),
            _SideItem(
              icon: Icons.confirmation_number_rounded,
              label: 'Chuyến của tôi',
              active: index == 1,
              onTap: () => onSelect(1),
            ),
            _SideItem(
              icon: Icons.add_road_rounded,
              label: 'Đăng chuyến',
              active: index == 2,
              onTap: () => onSelect(2),
            ),
            _SideItem(
              icon: Icons.route_rounded,
              label: 'Daily shuttle',
              active: index == 3,
              onTap: () => onSelect(3),
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 2, 20, 7),
              child: Text('TÀI KHOẢN',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2)),
            ),
            _SideItem(
              icon: Icons.person_rounded,
              label: 'Hồ sơ & cài đặt',
              active: index == 4,
              onTap: () => onSelect(4),
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                              colors: [Color(0xFF7C9BFF), Color(0xFF2F5BE0)]),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          (user?.fullName.isNotEmpty == true ? user!.fullName[0] : '?')
                              .toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.fullName ?? 'Khách',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                            Text(user?.phone ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    const TextStyle(color: Colors.white54, fontSize: 9)),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: state.signOut,
                        child: const Icon(Icons.logout_rounded,
                            color: Colors.white70, size: 17),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  const Row(
                    children: [
                      _OnlineDot(),
                      SizedBox(width: 5),
                      Text('Bản web đầy đủ',
                          style: TextStyle(color: Colors.white54, fontSize: 8.5)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const Text('S',
          style: TextStyle(
              color: Color(0xFF1657E8), fontSize: 21, fontWeight: FontWeight.w900)),
    );
  }
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle),
    );
  }
}

class _SideItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SideItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: active
                ? Border.all(color: Colors.white.withValues(alpha: 0.12))
                : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: active ? Colors.white : Colors.white54),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      color: active ? Colors.white : Colors.white60,
                      fontSize: 11.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
              const Spacer(),
              if (active)
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                      color: Color(0xFF4ADE80), shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
