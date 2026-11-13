import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/app_ui.dart';
import '../widgets/ui.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _future;
  bool _started = false;
  final List<AppNotification> _live = [];
  StreamSubscription<AppNotification>? _sub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
    _sub = AppScope.of(context).realtime.notifications.listen((item) {
      if (!mounted) return;
      setState(() {
        if (!_live.any((n) => n.id == item.id)) _live.insert(0, item);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _load() {
    _future = AppScope.of(context).api.notifications();
  }

  Future<void> _markAll() async {
    try {
      await AppScope.of(context).markNotificationsRead();
      if (!mounted) return;
      setState(() {
        _live.clear();
        _load();
      });
      if (mounted) showInfo(context, 'Đã đánh dấu tất cả là đã đọc');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        actions: [
          TextButton(onPressed: _markAll, child: const Text('Đọc tất cả')),
          const SizedBox(width: 6),
        ],
      ),
      body: FutureBuilder<List<AppNotification>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                Skeleton(height: 76, radius: 18),
                SizedBox(height: 8),
                Skeleton(height: 76, radius: 18),
                SizedBox(height: 8),
                Skeleton(height: 76, radius: 18),
              ],
            );
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Không tải được thông báo',
              message: '${snapshot.error}',
              actionLabel: 'Thử lại',
              onAction: () => setState(_load),
            );
          }
          final fetched = snapshot.data ?? [];
          final items = [..._live, ...fetched.where((n) => !_live.any((l) => l.id == n.id))];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Chưa có thông báo',
              message: 'Cập nhật về chuyến đi, thanh toán và ưu đãi sẽ xuất hiện ở đây.',
            );
          }
          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async => setState(_load),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _NotificationCard(item: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification item;
  const _NotificationCard({required this.item});

  IconData get _icon {
    if (item.type.contains('booking')) return Icons.event_seat_rounded;
    if (item.type.contains('review')) return Icons.star_rounded;
    if (item.type.contains('chat')) return Icons.chat_bubble_rounded;
    return Icons.notifications_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(13),
      color: item.unread ? const Color(0xFFF7FAFF) : Colors.white,
      border: Border.all(color: item.unread ? const Color(0xFFD5E1FF) : AppTheme.line),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: item.unread ? AppTheme.primarySoft : const Color(0xFFF3F6FA),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(_icon, size: 19, color: item.unread ? AppTheme.primary : AppTheme.muted),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.title,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                    ),
                    if (item.unread)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: const BoxDecoration(
                            color: AppTheme.primary, shape: BoxShape.circle),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(item.body,
                    style: const TextStyle(fontSize: 11, color: AppTheme.muted, height: 1.4)),
                const SizedBox(height: 5),
                Text('${shortDate(item.createdAt)} · ${hhmm(item.createdAt)}',
                    style: const TextStyle(fontSize: 9.5, color: AppTheme.mutedLight)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
