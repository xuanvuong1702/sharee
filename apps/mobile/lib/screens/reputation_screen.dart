import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../widgets/app_ui.dart';

class ReputationScreen extends StatefulWidget {
  const ReputationScreen({super.key});

  @override
  State<ReputationScreen> createState() => _ReputationScreenState();
}

class _ReputationScreenState extends State<ReputationScreen> {
  ReputationInfo? _info;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_info == null) _load();
  }

  Future<void> _load() async {
    try {
      final info = await AppScope.of(context).api.reputation();
      if (mounted) setState(() => _info = info);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chỉ số uy tín')),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.danger)))
          : _info == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      color: AppTheme.primary,
                      child: Column(
                        children: [
                          Text('${_info!.score}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
                          Text('ĐIỂM UY TÍN · ${_tier(_info!.tier).toUpperCase()}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _whiteStat('${_info!.rating.toStringAsFixed(1)}★', 'Đánh giá'),
                              _whiteStat('${_info!.completionRate}%', 'Hoàn thành'),
                              _whiteStat('${_info!.totalOrders}', 'Đơn'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Lịch sử giao dịch',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          _row('Hoàn thành với vai trò tài xế', '${_info!.completedAsDriver}'),
                          _row('Hoàn thành với vai trò khách', '${_info!.completedAsPassenger}'),
                          _row('Đánh giá', '${_info!.reviewCount} lượt'),
                          _row('Tỷ lệ hoàn thành', '${_info!.completionRate}%'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Huy hiệu',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          if (_info!.badges.isEmpty)
                            const Text('Chưa có huy hiệu',
                                style: TextStyle(fontSize: 11, color: AppTheme.muted))
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _info!.badges
                                  .map((b) => Pill(_badge(b),
                                      color: AppTheme.primary, background: AppTheme.primarySoft))
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Điểm uy tín dựa trên đánh giá, tỷ lệ hoàn thành và số giao dịch. '
                      'Hồ sơ KYC và xác thực tài xế giúp tăng độ tin cậy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: AppTheme.muted, height: 1.45),
                    ),
                  ],
                ),
    );
  }

  Widget _whiteStat(String value, String label) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 9.5)),
        ],
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label,
                style: const TextStyle(fontSize: 11, color: AppTheme.muted))),
            Text(value,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
          ],
        ),
      );

  String _tier(String tier) => switch (tier) {
        'elite' => 'Elite',
        'gold' => 'Vàng',
        'silver' => 'Bạc',
        'bronze' => 'Đồng',
        _ => 'Mới',
      };

  String _badge(String badge) => switch (badge) {
        'kyc' => 'Đã KYC',
        'verified_driver' => 'Tài xế xác thực',
        'top_rated' => 'Đánh giá cao',
        _ => badge,
      };
}
