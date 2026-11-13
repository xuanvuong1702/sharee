import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

class AppState extends ChangeNotifier {
  final Api api = Api();
  AppUser? user;
  String? refreshToken;
  bool ready = false;

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
    api.token = null;
    api.refreshToken = null;
    refreshToken = null;
    user = null;
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
  static const ink = Color(0xFF0B1B33);
  static const muted = Color(0xFF64748B);
  static const bg = Color(0xFFF6F8FC);
  static const success = Color(0xFF0FA968);
  static const warning = Color(0xFFB45309);
  static const danger = Color(0xFFB42318);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(primary: primary, surface: Colors.white);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE7ECF3)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE7ECF3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE7ECF3)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: Color(0xFFC9D8FF)),
        ),
      ),
    );
  }
}
