import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/ui.dart';
import 'tip_account_screen.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  late Future<Earnings> _future;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _future = AppScope.of(context).api.earnings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thu nhập')),
      body: FutureBuilder<Earnings>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0B2A6B), Color(0xFF1657E8)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('THU NHẬP CHUYẾN ĐI',
                        style: TextStyle(color: Colors.white70, fontSize: 9.5, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(money(data.tripEarnings),
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text('${data.completedTrips} chuyến đã hoàn thành',
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.favorite_rounded, color: Color(0xFFFFC46B), size: 18),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    'Tip: ${money(data.tipEarnings)} · ${data.tipCount} lần',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (data.pendingTips > 0) ...[
                      const SizedBox(height: 7),
                      Text('${data.pendingTips} tip đang chờ bạn xác nhận',
                          style: const TextStyle(color: Color(0xFFFFD9A0), fontSize: 10)),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.route, color: Colors.white, size: 18),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    'Daily: ${(data.dailyEarningsMinor / 100).toStringAsFixed(2)} € · ${data.dailyValidations} lượt',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const TipAccountScreen())),
                        icon: const Icon(Icons.qr_code_2_rounded, size: 17),
                        label: const Text('Tài khoản nhận tip'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SectionTitle('Gần đây'),
              if (data.recent.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('Chưa có khoản thu nào')),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < data.recent.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFEAF0FF),
                            child: Icon(
                              data.recent[i].type == 'daily'
                                  ? Icons.route
                                  : data.recent[i].type == 'tip'
                                      ? Icons.favorite_rounded
                                      : Icons.directions_car,
                              size: 18,
                              color: AppTheme.primary,
                            ),
                          ),
                          title: Text(data.recent[i].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            '${shortDate(data.recent[i].at)} · ${data.recent[i].type == 'daily' ? 'Daily' : data.recent[i].type == 'tip' ? 'Tip' : 'Chuyến đi'}',
                            style: const TextStyle(fontSize: 10.5, color: AppTheme.muted),
                          ),
                          trailing: Text(
                            data.recent[i].currency == 'EUR'
                                ? '${(data.recent[i].amount / 100).toStringAsFixed(2)} €'
                                : money(data.recent[i].amount),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              const Text('Thu nhập chuyến đi được tính từ các booking đã hoàn thành. Daily hiển thị theo euro.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: AppTheme.muted)),
            ],
          );
        },
      ),
    );
  }
}
