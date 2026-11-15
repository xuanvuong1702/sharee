import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/app_ui.dart';
import '../widgets/ui.dart';

class TipsReceivedScreen extends StatefulWidget {
  const TipsReceivedScreen({super.key});

  @override
  State<TipsReceivedScreen> createState() => _TipsReceivedScreenState();
}

class _TipsReceivedScreenState extends State<TipsReceivedScreen> {
  TipSummary? _data;
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loading || _data != null) return;
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await AppScope.of(context).api.receivedTips();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _confirm(DriverTip tip) async {
    setState(() => _busyId = tip.id);
    try {
      await AppScope.of(context).api.confirmTip(tip.id);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      setState(() => _busyId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xác nhận nhận tip')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busyId = null;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tip đã nhận')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Không tải được tip',
                  message: _error!,
                  actionLabel: 'Thử lại',
                  onAction: () => setState(_load),
                )
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    children: [
                      AppCard(
                        gradient: AppTheme.gradient,
                        border: null,
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TỔNG TIP ĐÃ XÁC NHẬN',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 9.5, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text(money(_data?.totalConfirmed ?? 0),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 3),
                            Text(
                                '${_data?.countConfirmed ?? 0} lần · ${_data?.countPending ?? 0} đang chờ xác nhận',
                                style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                      if ((_data?.countPending ?? 0) > 0) ...[
                        const SectionTitle('Chờ xác nhận'),
                        for (final tip in _data!.recent.where((t) => t.pending))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _TipCard(
                              tip: tip,
                              busy: _busyId == tip.id,
                              onConfirm: () => _confirm(tip),
                            ),
                          ),
                      ],
                      const SectionTitle('Gần đây'),
                      if (_data == null || _data!.recent.isEmpty)
                        const EmptyState(
                          icon: Icons.favorite_border_rounded,
                          title: 'Chưa có tip',
                          message: 'Cấu hình tài khoản nhận tip để khách có thể ủng hộ bạn.',
                        )
                      else
                        for (final tip in _data!.recent)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _TipCard(tip: tip, busy: false),
                          ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tip chuyển khoản được xác nhận thủ công sau khi bạn kiểm tra tài khoản. Tip tiền mặt được ghi nhận ngay.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: AppTheme.muted, height: 1.4),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final DriverTip tip;
  final bool busy;
  final VoidCallback? onConfirm;

  const _TipCard({required this.tip, required this.busy, this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final confirmed = tip.confirmed;
    return AppCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: confirmed ? AppTheme.successSoft : const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              confirmed ? Icons.favorite_rounded : Icons.schedule_rounded,
              color: confirmed ? AppTheme.success : const Color(0xFFB45309),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(tip.passengerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                    ),
                    Text(money(tip.amount),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${tip.methodLabel} · ${tip.confirmed ? 'Đã xác nhận' : 'Chờ xác nhận'}',
                  style: const TextStyle(fontSize: 9.5, color: AppTheme.muted),
                ),
                if (tip.message != null) ...[
                  const SizedBox(height: 3),
                  Text('“${tip.message}”',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
                ],
              ],
            ),
          ),
          if (!confirmed && onConfirm != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: busy ? null : onConfirm,
              child: busy
                  ? const SizedBox(
                      width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Xác nhận', style: TextStyle(fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }
}
