import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/app_state.dart';
import 'core/route_observer.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi', null);
  final state = AppState();
  await state.load();
  runApp(ShareeApp(state: state));
}

class ShareeApp extends StatelessWidget {
  final AppState state;
  const ShareeApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          return MaterialApp(
            title: 'Sharee',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            navigatorObservers: [appRouteObserver],
            builder: (context, child) {
              if (!kIsWeb) return child!;
              final media = MediaQuery.of(context);
              return ColoredBox(
                color: const Color(0xFF07152C),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 480),
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: MediaQuery(
                      data: media.copyWith(
                        padding: const EdgeInsets.only(top: 20),
                        viewPadding: const EdgeInsets.only(top: 20),
                      ),
                      child: ClipRect(child: child),
                    ),
                  ),
                ),
              );
            },
            home: state.user == null ? const LoginScreen() : const HomeShell(),
          );
        },
      ),
    );
  }
}
