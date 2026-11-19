import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/route_observer.dart';
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

class _HomeShellState extends State<HomeShell> with RouteAware {
  int _index = 0;
  bool _navVisible = true;
  double _scrollAccum = 0;
  double? _lastPixels;
  ModalRoute<dynamic>? _route;

  final _screens = const [
    HomeScreen(),
    MyTripsScreen(),
    PublishScreen(),
    DailyScreen(),
    ProfileScreen(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _route) {
      if (_route != null) appRouteObserver.unsubscribe(this);
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    if (_route != null) appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Returning from a pushed screen: never leave the user stranded without
    // navigation because the previous tab was scrolled down.
    _setNavVisible(true);
  }

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
                    constraints: BoxConstraints(
                      maxWidth: _index == 0 ? 1240 : 920,
                    ),
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
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: IndexedStack(index: _index, children: _screens),
      ),
      bottomNavigationBar: IgnorePointer(
        ignoring: !_navVisible,
        child: ExcludeSemantics(
          excluding: !_navVisible,
          child: AnimatedSlide(
            offset: _navVisible ? Offset.zero : const Offset(0, 1.25),
            duration: _navDuration(context),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: _navVisible ? 1 : 0,
              duration: _navFadeDuration(context),
              curve: Curves.easeOut,
              child: Padding(
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
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
                                    activeIcon:
                                        Icons.confirmation_number_rounded,
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
                                  colors: [
                                    Color(0xFF2CCBD3),
                                    Color(0xFF0E7F88),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2CCBD3)
                                        .withValues(alpha: 0.38),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _index == 2
                                    ? Icons.close_rounded
                                    : Icons.add_rounded,
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
            ),
          ),
        ),
      ),
    );
  }

  Duration _navDuration(BuildContext context) =>
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
      ? Duration.zero
      : const Duration(milliseconds: 220);

  Duration _navFadeDuration(BuildContext context) =>
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
      ? Duration.zero
      : const Duration(milliseconds: 160);

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification.metrics.axis != Axis.vertical) return false;

    // Web wheel events can jump the position before the start notification,
    // so remember the initial metrics and diff on start as well as update.
    if (notification is ScrollMetricsNotification) {
      _lastPixels ??= notification.metrics.pixels;
      if (notification.metrics.pixels <= 0) _setNavVisible(true);
      return false;
    }

    if (notification is ScrollStartNotification) {
      final pixels = notification.metrics.pixels;
      final previous = _lastPixels;
      _scrollAccum = 0;
      _lastPixels = pixels;
      if (previous != null && pixels != previous) {
        _applyScrollDelta(pixels - previous, pixels);
      }
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final pixels = notification.metrics.pixels;
      final delta = pixels - (_lastPixels ?? pixels);
      _lastPixels = pixels;
      _applyScrollDelta(delta, pixels);
      return false;
    }

    if (notification is ScrollEndNotification) {
      _scrollAccum = 0;
      _lastPixels = notification.metrics.pixels;
      if (notification.metrics.pixels <= 0) _setNavVisible(true);
    }
    return false;
  }

  void _applyScrollDelta(double delta, double pixels) {
    // Pull-to-refresh / overscroll at the top: never hide the bar.
    if (pixels <= 0) {
      _setNavVisible(true);
      _scrollAccum = 0;
      return;
    }

    _scrollAccum += delta;
    if (delta > 0 && _scrollAccum > 10) {
      _setNavVisible(false);
      _scrollAccum = 0;
    } else if (delta < 0 && _scrollAccum < -6) {
      _setNavVisible(true);
      _scrollAccum = 0;
    }
  }

  void _setNavVisible(bool visible) {
    if (_navVisible == visible || !mounted) return;
    setState(() => _navVisible = visible);
  }

  void _select(int index) {
    if (_index == index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _index = index;
      _navVisible = true;
      _scrollAccum = 0;
      _lastPixels = null;
    });
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
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
