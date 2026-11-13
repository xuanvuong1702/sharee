import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import 'daily_screen.dart';
import 'home_screen.dart';
import 'my_trips_screen.dart';
import 'profile_screen.dart';
import 'publish_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    MyTripsScreen(),
    PublishScreen(),
    DailyScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        color: AppTheme.bg,
        child: SafeArea(
          top: false,
          child: Container(
            height: 66,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.line),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A1A2F).withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Trang chủ',
                  active: _index == 0,
                  onTap: () => _select(0),
                ),
                _NavItem(
                  icon: Icons.confirmation_number_outlined,
                  activeIcon: Icons.confirmation_number_rounded,
                  label: 'Chuyến đi',
                  active: _index == 1,
                  onTap: () => _select(1),
                ),
                _PublishItem(
                  active: _index == 2,
                  onTap: () => _select(2),
                ),
                _NavItem(
                  icon: Icons.route_outlined,
                  activeIcon: Icons.route_rounded,
                  label: 'Daily',
                  active: _index == 3,
                  onTap: () => _select(3),
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Tài khoản',
                  active: _index == 4,
                  onTap: () => _select(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _select(int index) {
    if (_index == index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = index);
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              height: 30,
              decoration: BoxDecoration(
                color: active ? AppTheme.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                active ? activeIcon : icon,
                size: 21,
                color: active ? AppTheme.primary : AppTheme.mutedLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? AppTheme.primary : AppTheme.mutedLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishItem extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _PublishItem({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1F63F0), Color(0xFF0B3FC0)]),
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: active ? 0.4 : 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 2),
            Text('Đăng',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: active ? AppTheme.primary : AppTheme.mutedLight,
                )),
          ],
        ),
      ),
    );
  }
}
