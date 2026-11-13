import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';
import 'realtime.dart';

class AppState extends ChangeNotifier {
  final Api api = Api();
  AppUser? user;
  String? refreshToken;
  bool ready = false;
  int unread = 0;
  RealtimeService? _realtime;
  StreamSubscription<AppNotification>? _notificationSub;

  RealtimeService get realtime => _realtime ??= RealtimeService(api);

  Future<void> load() async {
    api.onTokensChanged = _persistTokens;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final refresh = prefs.getString('refreshToken');
    if (token != null && token.isNotEmpty) {
      api.token = token;
      api.refreshToken = refresh;
      try {
        user = await api.me();
      } catch (_) {
        if (refresh != null && await api.tryRefresh()) {
          try {
            user = await api.me();
          } catch (_) {
            api.token = null;
          }
        }
        if (user == null) {
          api.token = null;
          await prefs.remove('token');
        }
      }
    }
    ready = true;
    notifyListeners();
    if (user != null) unawaited(_startRealtime());
  }

  Future<void> _startRealtime() async {
    if (user == null) return;
    await realtime.connect();
    _notificationSub ??= realtime.notifications.listen((_) {
      unread += 1;
      notifyListeners();
    });
    try {
      unread = await api.unreadNotifications();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markNotificationsRead() async {
    try {
      await api.markNotificationsRead();
    } catch (_) {}
    unread = 0;
    notifyListeners();
  }

  Future<void> signIn(String token, String refresh, AppUser value) async {
    api.token = token;
    api.refreshToken = refresh;
    refreshToken = refresh;
    user = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('refreshToken', refresh);
    notifyListeners();
    unawaited(_startRealtime());
  }

  Future<void> _persistTokens(String access, String refresh) async {
    refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', access);
    await prefs.setString('refreshToken', refresh);
  }

  Future<void> refreshUser() async {
    try {
      user = await api.me();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> signOut() async {
    await api.logout();
    await _notificationSub?.cancel();
    _notificationSub = null;
    final realtimeService = _realtime;
    _realtime = null;
    await realtimeService?.dispose();
    api.token = null;
    api.refreshToken = null;
    refreshToken = null;
    user = null;
    unread = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('refreshToken');
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!.notifier!;
  }
}

class AppTheme {
  static const primary = Color(0xFF1657E8);
  static const primaryDark = Color(0xFF0B3FC0);
  static const primarySoft = Color(0xFFEAF0FF);
  static const accent = Color(0xFFFF9F1C);
  static const ink = Color(0xFF0A1A2F);
  static const muted = Color(0xFF68778D);
  static const mutedLight = Color(0xFF95A2B5);
  static const bg = Color(0xFFF5F7FB);
  static const surface = Colors.white;
  static const line = Color(0xFFE8EDF5);
  static const success = Color(0xFF0FA968);
  static const successSoft = Color(0xFFE6F8F0);
  static const warning = Color(0xFFB45309);
  static const danger = Color(0xFFE5484D);
  static const dangerSoft = Color(0xFFFDECEC);

  static const gradient = LinearGradient(
    colors: [Color(0xFF0B2A6B), Color(0xFF1657E8), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const softShadow = [
    BoxShadow(color: Color(0x0D0A1A2F), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static const liftedShadow = [
    BoxShadow(color: Color(0x1A1657E8), blurRadius: 26, offset: Offset(0, 12)),
  ];

  static TextTheme get _textTheme => const TextTheme(
        displayLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.0, height: 1.1),
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.7, height: 1.15),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.2),
        titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.1),
        bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.5),
        bodyMedium: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, height: 1.45),
        bodySmall: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, height: 1.4),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        labelMedium: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        labelSmall: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.08),
      );

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      secondary: accent,
      surface: surface,
      error: danger,
      onSurface: ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      fontFamily: 'Roboto',
      splashFactory: InkSparkle.splashFactory,
      textTheme: _textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ink),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFD),
        hintStyle: const TextStyle(color: mutedLight, fontSize: 13, fontWeight: FontWeight.w500),
        labelStyle: const TextStyle(color: muted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: primary,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: const BorderSide(color: Color(0xFFD5E1FF)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: primary,
        disabledColor: const Color(0xFFF1F4F9),
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ink),
        secondaryLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
        dragHandleColor: Color(0xFFDDE4EF),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primarySoft,
        elevation: 0,
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: states.contains(WidgetState.selected) ? primary : mutedLight,
            )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 22,
              color: states.contains(WidgetState.selected) ? primary : mutedLight,
            )),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: const TextStyle(fontSize: 12.5, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.all(16),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }
}
