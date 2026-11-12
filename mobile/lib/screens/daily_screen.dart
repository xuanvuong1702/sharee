import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/ui.dart';

class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đi chung hằng ngày', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          bottom: const TabBar(
            tabs: [Tab(text: 'Tuyến'), Tab(text: 'Vé của tôi')],
          ),
        ),
        body: const TabBarView(
          children: [_LineList(), _MyTickets()],
        ),
      ),
    );
  }
}

class _LineList extends StatefulWidget {
  const _LineList();

  @override
  State<_LineList> createState() => _LineListState();
}

class _LineListState extends State<_LineList> {
  late Future<List<Line>> _future;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _future = AppScope.of(context).api.lines();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Line>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
        final lines = snapshot.data ?? [];
        if (lines.isEmpty) return const Center(child: Text('Chưa có tuyến nào'));
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0B2A6B), Color(0xFF1657E8)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('KHÔNG CẦN ĐẶT TRƯỚC',
                      style: TextStyle(color: Colors.white70, fontSize: 9.5, letterSpacing: 1)),
                  SizedBox(height: 5),
                  Text('Quét QR tại trạm, lên xe trong vài phút',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  SizedBox(height: 3),
                  Text('Tài xế đi làm như bình thường, nhận thêm thu nhập.',
                      style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (final line in lines)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: const Color(0xFFEAF0FF), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.route, color: AppTheme.primary, size: 22),
                  ),
                  title: Text(line.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  subtitle: Text('${line.stopsCount} trạm · ${line.distanceMeters == null ? '—' : (line.distanceMeters! / 1000).toStringAsFixed(1)} km',
                      style: const TextStyle(fontSize: 10.5)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LineDetailScreen(lineId: line.id),
                  )),
                ),
              ),
          ],
        );
      },
    );
  }
}

class LineDetailScreen extends StatefulWidget {
  final String lineId;
  const LineDetailScreen({super.key, required this.lineId});

  @override
  State<LineDetailScreen> createState() => _LineDetailScreenState();
}

class _LineDetailScreenState extends State<LineDetailScreen> {
  late Future<Line> _future;
  bool _started = false;
  String? _stopId;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _future = AppScope.of(context).api.line(widget.lineId);
  }

  Future<void> _createTicket(Line line) async {
    _stopId ??= line.stops.first.id;
    setState(() => _busy = true);
    try {
      final ticket = await AppScope.of(context).api.createTicket(line.id, _stopId!);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Đã tạo vé'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Mã vé: ${ticket.code}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4)),
              const SizedBox(height: 6),
              Text(ticket.stopName, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Text('Hiệu lực đến ${hhmm(ticket.expiresAt)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
              const SizedBox(height: 10),
              const Text('Đưa mã này cho tài xế khi lên xe.',
                  style: TextStyle(fontSize: 11, color: AppTheme.muted)),
            ],
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Xong')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết tuyến')),
      body: FutureBuilder<Line>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
          final line = snapshot.data!;
          _stopId ??= line.stops.isNotEmpty ? line.stops.first.id : null;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(line.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('${line.stopsCount} trạm · ${((line.distanceMeters ?? 0) / 1000).toStringAsFixed(1)} km · miễn phí cho khách',
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
              const SizedBox(height: 14),
              const Text('Chọn trạm lên xe', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Card(
                child: Column(
                  children: [
                    for (final stop in line.stops)
                      RadioListTile<String>(
                        value: stop.id,
                        groupValue: _stopId,
                        dense: true,
                        onChanged: (value) => setState(() => _stopId = value),
                        title: Text(stop.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        subtitle: Text('Trạm ${stop.seq + 1}', style: const TextStyle(fontSize: 10)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _busy ? null : () => _createTicket(line),
                icon: const Icon(Icons.qr_code_2),
                label: Text(_busy ? 'Đang tạo vé…' : 'Tạo vé tại trạm'),
              ),
              const SizedBox(height: 8),
              const Text('Vé có hiệu lực 30 phút. Không cần chọn giờ.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppTheme.muted)),
            ],
          );
        },
      ),
    );
  }
}

class _MyTickets extends StatefulWidget {
  const _MyTickets();

  @override
  State<_MyTickets> createState() => _MyTicketsState();
}

class _MyTicketsState extends State<_MyTickets> {
  late Future<List<ETicket>> _future;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _future = AppScope.of(context).api.myTickets();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ETicket>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final tickets = snapshot.data ?? [];
        if (tickets.isEmpty) {
          return const Center(child: Text('Bạn chưa có vé nào'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tickets.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final t = tickets[index];
            final active = t.status == 'waiting' || t.status == 'assigned';
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 58, height: 58,
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFFE6F8F0) : const Color(0xFFF3F6FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(t.code,
                          style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900,
                            color: active ? AppTheme.success : AppTheme.muted,
                            letterSpacing: 1,
                          )),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.stopName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                          Text(t.lineName, style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                          Text(
                            active ? 'Hiệu lực đến ${hhmm(t.expiresAt)}' : 'Đã dùng · ${shortDate(t.expiresAt)}',
                            style: const TextStyle(fontSize: 10, color: AppTheme.muted),
                          ),
                        ],
                      ),
                    ),
                    StatusPill(status: active ? 'confirmed' : 'completed'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
