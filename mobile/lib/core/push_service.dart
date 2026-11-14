import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _started = false;

  Future<void> init(Api api) async {
    if (_started) return;
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    if (apiKey.isEmpty || appId.isEmpty || senderId.isEmpty || projectId.isEmpty) {
      debugPrint('Push disabled: Firebase dart-defines are not configured');
      return;
    }

    _started = true;
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: senderId,
          projectId: projectId,
        ),
      );
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken();
      if (token != null) await _register(api, token);
      messaging.onTokenRefresh.listen((value) => _register(api, value));

      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('Push foreground: ${message.notification?.title}');
      });
    } catch (e) {
      debugPrint('Push initialization failed: $e');
      _started = false;
    }
  }

  Future<void> _register(Api api, String token) async {
    try {
      final platform = kIsWeb
          ? 'web'
          : defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android';
      await api.registerDevice(token, platform);
    } catch (e) {
      debugPrint('Device token registration failed: $e');
    }
  }
}
