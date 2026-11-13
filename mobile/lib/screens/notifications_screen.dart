import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _future;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  void _load() {
    final api = AppScope.of(context).api;
    _future = api.notifications();
    api.markNotificationsRead();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      body: FutureBuilder<List<AppNotification>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('Chưa có thông báo'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: item.unread ? const Color(0xFFEAF0FF) : const Color(0xFFF3F6FA),
                  child: Icon(
                    item.type.contains('booking') ? Icons.event_seat : Icons.notifications_none,
                    size: 20,
                    color: item.unread ? AppTheme.primary : AppTheme.muted,
                  ),
                ),
                title: Text(item.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                subtitle: Text(item.body, style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
                trailing: Text(
                  '${item.createdAt.toLocal().hour.toString().padLeft(2, '0')}:${item.createdAt.toLocal().minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.muted),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
