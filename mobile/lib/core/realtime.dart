import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

import 'api.dart';
import 'models.dart';

class RealtimeService {
  final Api api;
  HubConnection? _chat;
  HubConnection? _notifications;
  final _conversations = <String>{};

  final _messages = StreamController<ChatMessage>.broadcast();
  final _threads = StreamController<ChatMessage>.broadcast();
  final _notificationsStream = StreamController<AppNotification>.broadcast();

  Stream<ChatMessage> get messages => _messages.stream;
  Stream<ChatMessage> get threads => _threads.stream;
  Stream<AppNotification> get notifications => _notificationsStream.stream;

  RealtimeService(this.api);

  Future<void> connect() async {
    if (_chat != null) return;
    try {
      final chat = HubConnectionBuilder()
          .withUrl(
            '${Api.baseUrl}/hubs/chat',
            options: HttpConnectionOptions(
              accessTokenFactory: () async => api.token ?? '',
            ),
          )
          .withAutomaticReconnect()
          .build();

      chat.on('message', (args) {
        final message = _message(args);
        if (message != null) _messages.add(message);
      });
      chat.on('thread', (args) {
        final message = _message(args);
        if (message != null) _threads.add(message);
      });
      chat.onreconnected(({connectionId}) {
        for (final id in _conversations) {
          chat.invoke('JoinConversation', args: [id]).catchError((_) => null);
        }
      });

      await chat.start();
      _chat = chat;
    } catch (e) {
      debugPrint('SignalR chat unavailable: $e');
    }

    try {
      final notifications = HubConnectionBuilder()
          .withUrl(
            '${Api.baseUrl}/hubs/notifications',
            options: HttpConnectionOptions(
              accessTokenFactory: () async => api.token ?? '',
            ),
          )
          .withAutomaticReconnect()
          .build();
      notifications.on('notification', (args) {
        final item = _notification(args);
        if (item != null) _notificationsStream.add(item);
      });
      await notifications.start();
      _notifications = notifications;
    } catch (e) {
      debugPrint('SignalR notifications unavailable: $e');
    }
  }

  Future<void> joinConversation(String conversationId) async {
    _conversations.add(conversationId);
    final chat = _chat;
    if (chat == null || chat.state != HubConnectionState.Connected) return;
    try {
      await chat.invoke('JoinConversation', args: [conversationId]);
    } catch (e) {
      debugPrint('Cannot join conversation: $e');
    }
  }

  ChatMessage? _message(List<Object?>? args) {
    try {
      final raw = args?.first;
      if (raw is Map) {
        return ChatMessage.fromJson(Map<String, dynamic>.from(raw));
      }
    } catch (e) {
      debugPrint('Bad chat payload: $e');
    }
    return null;
  }

  AppNotification? _notification(List<Object?>? args) {
    try {
      final raw = args?.first;
      if (raw is Map) {
        return AppNotification.fromJson(Map<String, dynamic>.from(raw));
      }
    } catch (e) {
      debugPrint('Bad notification payload: $e');
    }
    return null;
  }

  Future<void> dispose() async {
    _conversations.clear();
    await _chat?.stop();
    await _notifications?.stop();
    _chat = null;
    _notifications = null;
    await _messages.close();
    await _threads.close();
    await _notificationsStream.close();
  }
}
