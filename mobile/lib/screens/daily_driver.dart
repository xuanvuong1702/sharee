import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../widgets/ui.dart';

class DriverQueueTab extends StatefulWidget {
  const DriverQueueTab({super.key});

  @override
  State<DriverQueueTab> createState() => _DriverQueueTabState();
}

class _DriverQueueTabState extends State<DriverQueueTab> {
  late Future<List<ETicket>> _future;
  bool _started = false;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  void _load() {
    _future = AppScope.of(context).api.driverQueue();
  }

  Future<void> _assign(ETicket ticket) async {
    setState(() => _busy = true);
    try {
      await AppScope.of(context).api.assignTicket(ticket.id);
      setState(_load);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _validate(ETicket ticket) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận khách lên xe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${ticket.passengerName ?? 'Khách'} · ${ticket.stopName}',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 6),
              decoration: const InputDecoration(counterText: '', hintText: 'Mã 4 số'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xác nhận')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context).api.validateTicket(ticket.id, controller.text.trim());
      setState(_load);
      if (mounted) showInfo(context, 'Đã xác nhận vé');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ETicket>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
        final tickets = snapshot.data ?? [];
        if (tickets.isEmpty) {
          return const Center(child: Text('Không có vé nào đang chờ'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tickets.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final t = tickets[index];
            final waiting = t.status == 'waiting';
            final assigned = t.status == 'assigned';
            final validated = t.status == 'validated';
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('${t.passengerName ?? 'Khách'} · ${t.stopName}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                        ),
                        StatusPill(
                            status: validated
                                ? 'completed'
                                : (waiting ? 'pending_driver' : 'confirmed')),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(t.lineName, style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                    const SizedBox(height: 8),
                    if (waiting)
                      FilledButton(
                        onPressed: _busy ? null : () => _assign(t),
                        child: const Text('Nhận vé'),
                      )
                    else if (assigned)
                      FilledButton(
                        onPressed: _busy ? null : () => _validate(t),
                        child: const Text('Xác nhận khách lên xe'),
                      )
                    else
                      Text('Đã xác nhận · thưởng ${(t.amountMinor ?? 0) / 100} €',
                          style: const TextStyle(fontSize: 11, color: AppTheme.success)),
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
