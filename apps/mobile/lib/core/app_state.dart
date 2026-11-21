import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';
import 'push_service.dart';
import 'realtime.dart';

class AppState extends ChangeNotifier {
  final Api api = Api();
  static const _secure = FlutterSecureStorage();
  AppUser? user;
  String? refreshToken;
  bool ready = false;
  int unread = 0;
  RealtimeService? _realtime;
  StreamSubscription<AppNotification>? _notificationSub;

  RealtimeService get realtime => _realtime ??= RealtimeService(api);

  Future<void> load() async {
    api.onTokensChanged = _persistTokens;
    var token = await _secure.read(key: 'token');
    var refresh = await _secure.read(key: 'refreshToken');
    if (token == null) {
      // One-time migration from the old plaintext SharedPreferences store.
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('token');
      refresh = prefs.getString('refreshToken');
      if (token != null) {
        await _secure.write(key: 'token', value: token);
        if (refresh != null) await _secure.write(key: 'refreshToken', value: refresh);
        await prefs.remove('token');
        await prefs.remove('refreshToken');
      }
    }
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
          await _secure.delete(key: 'token');
          await _secure.delete(key: 'refreshToken');
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
    unawaited(PushService.instance.init(api));
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
    await _secure.write(key: 'token', value: token);
    await _secure.write(key: 'refreshToken', value: refresh);
    notifyListeners();
    unawaited(_startRealtime());
  }

  Future<void> _persistTokens(String access, String refresh) async {
    refreshToken = refresh;
    await _secure.write(key: 'token', value: access);
    await _secure.write(key: 'refreshToken', value: refresh);
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
    await _secure.delete(key: 'token');
    await _secure.delete(key: 'refreshToken');
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
  static const primary = Color(0xFF0E7F88);
  static const primaryDark = Color(0xFF0A646C);
  static const primarySoft = Color(0xFFE6F7F8);
  static const accent = Color(0xFFD4A82C);
  static const mint = Color(0xFF2CCBD3);
  static const ink = Color(0xFF1E2528);
  static const muted = Color(0xFF6B7479);
  static const mutedLight = Color(0xFF9AA2A7);
  static const bg = Color(0xFFF4F6F8);
  static const sand = Color(0xFFF6F1E7);
  static const surface = Colors.white;
  static const surfaceAlt = Color(0xFFFBFCFE);
  static const line = Color(0xFFE3E7EA);
  static const success = Color(0xFF2E9E6A);
  static const successSoft = Color(0xFFE6F8F0);
  static const warning = Color(0xFFB45309);
  static const danger = Color(0xFFD64545);
  static const dangerSoft = Color(0xFFFDECEC);

  static const gradient = LinearGradient(
    colors: [Color(0xFF0B1B22), Color(0xFF0E4F55), Color(0xFF0E7F88)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const softShadow = [
    BoxShadow(color: Color(0x0A071A33), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static const liftedShadow = [
    BoxShadow(color: Color(0x1F1F5EFF), blurRadius: 28, offset: Offset(0, 14)),
  ];

  static TextTheme get _textTheme => const TextTheme(
        displayLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1.2, height: 1.08),
        headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.12),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.18),
        titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.1),
        bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.5),
        bodyMedium: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w400, height: 1.45),
        bodySmall: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w400, height: 1.4),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        labelMedium: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.08),
      );

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      secondary: mint,
      surface: surface,
      error: danger,
      onSurface: ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      fontFamily: 'BeVietnamPro',
      splashFactory: InkSparkle.splashFactory,
      textTheme: _textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: ink),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFD),
        hintStyle: const TextStyle(color: mutedLight, fontSize: 13, fontWeight: FontWeight.w400),
        labelStyle: const TextStyle(color: muted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
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
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: primary,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: const BorderSide(color: Color(0xFFD5E1FF)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
              fontWeight: FontWeight.w600,
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
