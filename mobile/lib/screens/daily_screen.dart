import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/app_ui.dart';
import '../widgets/ui.dart';
import 'daily_driver.dart';

class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Daily', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              Text('Đi chung hằng ngày, không cần đặt trước',
                  style: TextStyle(fontSize: 11, color: AppTheme.muted)),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Container(
              height: 40,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppTheme.line),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.muted,
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                tabs: const [Tab(text: 'Tuyến'), Tab(text: 'Vé của tôi'), Tab(text: 'Tài xế')],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [_LineList(), _MyTickets(), DriverQueueTab()],
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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            AppCard(
              gradient: AppTheme.gradient,
              border: null,
              padding: const EdgeInsets.all(17),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 25),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('KHÔNG CẦN ĐẶT TRƯỚC',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 8.5,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w700)),
                        SizedBox(height: 4),
                        Text('Tạo vé tại trạm, lên xe trong vài phút',
                            style: TextStyle(
                                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                        SizedBox(height: 3),
                        Text('Vé điện tử có hiệu lực 30 phút.',
                            style: TextStyle(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Tuyến đang chạy',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            const Text('Chọn tuyến và trạm gần bạn nhất',
                style: TextStyle(fontSize: 10.5, color: AppTheme.muted)),
            const SizedBox(height: 10),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: AppCard(
                  onTap: () => Navigator.of(context).push(appRoute(
                    LineDetailScreen(lineId: line.id),
                  )),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.success, width: 2.5),
                            ),
                          ),
                          Container(width: 2, height: 28, color: AppTheme.line),
                          Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.accent, width: 2.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(line.name,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 3),
                            Text(
                                line.distanceMeters != null && line.distanceMeters! > 0
                                    ? '${line.stopsCount} trạm · ${(line.distanceMeters! / 1000).toStringAsFixed(1)} km'
                                    : '${line.stopsCount} trạm',
                                style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Pill('Vé 30 phút',
                                    color: AppTheme.primary, background: AppTheme.primarySoft),
                                const SizedBox(width: 5),
                                if (line.stops.isNotEmpty)
                                  Flexible(
                                    child: Text(
                                      '${line.stops.first.name.split(',').first} → ${line.stops.last.name.split(',').first}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 9.5, color: AppTheme.muted),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F6FA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.chevron_right_rounded,
                            size: 19, color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),
            const SectionHeader('Cách hoạt động', padding: EdgeInsets.only(top: 8, bottom: 8)),
            AppCard(
              padding: const EdgeInsets.all(15),
              child: const Column(
                children: [
                  _HowStep(number: '1', title: 'Chọn trạm gần bạn', sub: 'Mỗi tuyến có nhiều trạm dọc đường.'),
                  Divider(height: 20),
                  _HowStep(number: '2', title: 'Tạo vé điện tử', sub: 'Vé có hiệu lực 30 phút, không cần chọn giờ.'),
                  Divider(height: 20),
                  _HowStep(number: '3', title: 'Đưa mã cho tài xế', sub: 'Tài xế nhập mã 4 số để xác nhận.'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HowStep extends StatelessWidget {
  final String number;
  final String title;
  final String sub;

  const _HowStep({required this.number, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(color: AppTheme.primarySoft, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(number,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.primary)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              Text(sub, style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

class LineDetailScreen extends StatefulWidget {  final String lineId;
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
              Text(
                  '${line.stopsCount} trạm · ${((line.distanceMeters ?? 0) / 1000).toStringAsFixed(1)} km · miễn phí cho khách',
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
              const SizedBox(height: 14),
              const Text('Chọn trạm lên xe',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
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
                        title: Text(stop.name,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
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
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: AppTheme.muted)),
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
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFFE6F8F0) : const Color(0xFFF3F6FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(t.code,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: active ? AppTheme.success : AppTheme.muted,
                            letterSpacing: 1,
                          )),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.stopName,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                          Text(t.lineName,
                              style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                          Text(
                            active
                                ? 'Hiệu lực đến ${hhmm(t.expiresAt)}'
                                : 'Đã dùng · ${shortDate(t.expiresAt)}',
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
