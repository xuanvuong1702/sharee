import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import 'daily_screen.dart';
import 'desktop_sidebar.dart';
import 'full_web_home_screen.dart';
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
    final desktop = MediaQuery.sizeOf(context).width >= 1000;
    final screens = desktop
        ? <Widget>[
            FullWebHomeScreen(onPublish: () => _select(2)),
            const MyTripsScreen(),
            const PublishScreen(),
            const DailyScreen(),
            const ProfileScreen(),
          ]
        : _screens;

    if (desktop) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: Row(
          children: [
            DesktopSidebar(index: _index, onSelect: _select),
            Expanded(
              child: Container(
                color: AppTheme.bg,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: _index == 0 ? 1240 : 920),
                    child: IndexedStack(index: _index, children: screens),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      height: 64,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.ink.withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _GlassTabItem(
                            icon: Icons.home_outlined,
                            activeIcon: Icons.home_rounded,
                            label: 'Trang chủ',
                            active: _index == 0,
                            onTap: () => _select(0),
                          ),
                          _GlassTabItem(
                            icon: Icons.confirmation_number_outlined,
                            activeIcon: Icons.confirmation_number_rounded,
                            label: 'Chuyến đi',
                            active: _index == 1,
                            onTap: () => _select(1),
                          ),
                          _GlassTabItem(
                            icon: Icons.route_outlined,
                            activeIcon: Icons.route_rounded,
                            label: 'Daily',
                            active: _index == 3,
                            onTap: () => _select(3),
                          ),
                          _GlassTabItem(
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
              ),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: 'Đăng chuyến',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _select(2),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2CCBD3), Color(0xFF0E7F88)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2CCBD3).withValues(alpha: 0.38),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        _index == 2 ? Icons.close_rounded : Icons.add_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ],
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

class _GlassTabItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _GlassTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          selected: active,
          label: label,
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppTheme.primarySoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.18),
                            blurRadius: 14,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  active ? activeIcon : icon,
                  size: 22,
                  color: active ? AppTheme.primary : AppTheme.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
