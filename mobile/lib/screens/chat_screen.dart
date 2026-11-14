import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/app_ui.dart';
import '../widgets/ui.dart';

class ChatThreadsScreen extends StatefulWidget {
  const ChatThreadsScreen({super.key});

  @override
  State<ChatThreadsScreen> createState() => _ChatThreadsScreenState();
}

class _ChatThreadsScreenState extends State<ChatThreadsScreen> {
  late Future<List<ChatThread>> _future;
  bool _started = false;
  StreamSubscription<ChatMessage>? _sub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
    _sub = AppScope.of(context).realtime.threads.listen((_) {
      if (mounted) setState(_load);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _load() {
    _future = AppScope.of(context).api.conversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tin nhắn', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            Text('Trao đổi với tài xế và khách',
                style: TextStyle(fontSize: 11, color: AppTheme.muted)),
          ],
        ),
      ),
      body: FutureBuilder<List<ChatThread>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                Skeleton(height: 78, radius: 18),
                SizedBox(height: 9),
                Skeleton(height: 78, radius: 18),
                SizedBox(height: 9),
                Skeleton(height: 78, radius: 18),
              ],
            );
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Không tải được hội thoại',
              message: '${snapshot.error}',
              actionLabel: 'Thử lại',
              onAction: () => setState(_load),
            );
          }
          final threads = snapshot.data ?? [];
          if (threads.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Chưa có hội thoại nào',
              message: 'Sau khi đặt chuyến, bạn có thể nhắn tin trực tiếp với tài xế.',
            );
          }
          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async => setState(_load),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              itemCount: threads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 9),
              itemBuilder: (context, index) {
                final t = threads[index];
                return AppCard(
                  padding: const EdgeInsets.all(13),
                  onTap: () => Navigator.of(context).push(appRoute(ChatScreen(thread: t))),
                  child: Row(
                    children: [
                      AvatarCircle(name: t.other.fullName, size: 46),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(t.other.fullName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w800)),
                                ),
                                if (t.lastAt != null)
                                  Text(hhmm(t.lastAt!),
                                      style: const TextStyle(
                                          fontSize: 9.5, color: AppTheme.muted)),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(t.lastMessage ?? 'Bắt đầu trò chuyện',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: t.unread > 0 ? AppTheme.ink : AppTheme.muted,
                                    fontWeight:
                                        t.unread > 0 ? FontWeight.w600 : FontWeight.w500)),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Flexible(
                                  child: Pill('${t.originLabel.split(',').first} → ${t.destinationLabel.split(',').first}',
                                      color: AppTheme.primary,
                                      background: AppTheme.primarySoft),
                                ),
                                const Spacer(),
                                if (t.unread > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Text('${t.unread}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w900)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final ChatThread thread;
  const ChatScreen({super.key, required this.thread});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage> _messages = [];
  Timer? _timer;
  Timer? _readTimer;
  StreamSubscription<ChatMessage>? _sub;
  bool _sending = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => _load(silent: true));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
    final realtime = AppScope.of(context).realtime;
    realtime.joinConversation(widget.thread.id);
    _sub = realtime.messages
        .where((m) => m.conversationId == widget.thread.id)
        .listen(_onMessage);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _readTimer?.cancel();
    _sub?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onMessage(ChatMessage message) {
    if (_messages.any((m) => m.id == message.id)) return;
    setState(() {
      _messages = [..._messages, message]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
    _jumpToEnd();
    _readTimer?.cancel();
    _readTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _load(silent: true);
    });
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final messages = await AppScope.of(context).api.messages(widget.thread.id);
      if (!mounted) return;
      setState(() => _messages = messages);
      if (!silent) _jumpToEnd();
    } catch (_) {}
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final message = await AppScope.of(context).api.sendMessage(widget.thread.id, text);
      _controller.clear();
      _onMessage(message);
      _jumpToEnd();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = AppScope.of(context).user?.id;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.thread.other.fullName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            Text('${widget.thread.originLabel} → ${widget.thread.destinationLabel}',
                style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final mine = m.senderId == myId;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: mine ? AppTheme.primary : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(14),
                        topRight: const Radius.circular(14),
                        bottomLeft: Radius.circular(mine ? 14 : 4),
                        bottomRight: Radius.circular(mine ? 4 : 14),
                      ),
                      border: mine ? null : Border.all(color: const Color(0xFFE7ECF3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.body,
                            style: TextStyle(fontSize: 13, color: mine ? Colors.white : AppTheme.ink)),
                        const SizedBox(height: 3),
                        Text(hhmm(m.createdAt),
                            style: TextStyle(
                                fontSize: 8.5,
                                color: mine ? Colors.white70 : AppTheme.muted)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Nhắn tin…',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
