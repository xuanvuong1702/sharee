import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/app_state.dart';
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
            home: state.user == null ? const LoginScreen() : const HomeShell(),
          );
        },
      ),
    );
  }
}
