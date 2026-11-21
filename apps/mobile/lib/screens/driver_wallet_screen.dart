import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../widgets/app_ui.dart';
import '../widgets/ui.dart';

class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await AppScope.of(context).api.driverWallet();
      if (mounted) setState(() { _data = data; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _withdraw() async {
    final amount = TextEditingController();
    final bank = TextEditingController();
    final account = TextEditingController();
    final name = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Rút tiền về ngân hàng',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Yêu cầu sẽ được admin duyệt và chuyển khoản thủ công.',
                style: TextStyle(fontSize: 11, color: AppTheme.muted)),
            const SizedBox(height: 12),
            TextField(controller: amount, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Số tiền (đ)')),
            const SizedBox(height: 8),
            TextField(controller: bank,
                decoration: const InputDecoration(labelText: 'Ngân hàng')),
            const SizedBox(height: 8),
            TextField(controller: account,
                decoration: const InputDecoration(labelText: 'Số tài khoản')),
            const SizedBox(height: 8),
            TextField(controller: name,
                decoration: const InputDecoration(labelText: 'Chủ tài khoản')),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Gửi yêu cầu rút',
              icon: Icons.account_balance_rounded,
              onPressed: () {
                final value = int.tryParse(amount.text.replaceAll(RegExp(r'[^0-9]'), ''));
                if (value == null || value < 50000) {
                  showInfo(context, 'Số tiền tối thiểu 50.000đ');
                  return;
                }
                if (bank.text.trim().isEmpty || account.text.trim().isEmpty || name.text.trim().isEmpty) {
                  showInfo(context, 'Nhập đủ thông tin ngân hàng');
                  return;
                }
                Navigator.pop(context, true);
              },
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final value = int.parse(amount.text.replaceAll(RegExp(r'[^0-9]'), ''));
      await AppScope.of(context).api.requestWithdrawal(
            amount: value,
            bankName: bank.text.trim(),
            accountNumber: account.text.trim(),
            accountName: name.text.trim(),
          );
      if (!mounted) return;
      showInfo(context, 'Đã gửi yêu cầu rút tiền');
      await _load();
    } catch (e) {
      if (mounted) showInfo(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(title: const Text('Ví tài xế')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SỐ DƯ KHẢ DỤNG',
                            style: TextStyle(fontSize: 10, letterSpacing: .6, color: AppTheme.muted)),
                        const SizedBox(height: 4),
                        Text(money((data?['available'] as num?)?.toInt() ?? 0),
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _Mini(label: 'Tổng kiếm', value: money((data?['balance'] as num?)?.toInt() ?? 0))),
                            Expanded(child: _Mini(label: 'Đang chờ', value: money((data?['pending'] as num?)?.toInt() ?? 0))),
                          ],
                        ),
                        const SizedBox(height: 14),
                        PrimaryButton(label: 'Rút tiền', icon: Icons.account_balance_rounded, onPressed: _withdraw),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
                  ],
                  const SectionHeader('Lịch sử rút tiền'),
                  if ((data?['withdrawals'] as List?)?.isEmpty ?? true)
                    const EmptyState(icon: Icons.account_balance_wallet_outlined,
                        title: 'Chưa có yêu cầu rút tiền',
                        message: 'Thu nhập từ chuyến hoàn tất sẽ được cộng vào ví.')
                  else
                    for (final w in (data?['withdrawals'] as List? ?? []))
                      AppCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_rounded, color: AppTheme.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(money((w['amount'] as num?)?.toInt() ?? 0),
                                      style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text('${w['bankName']} · ${w['accountNumber']}',
                                      style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
                                ],
                              ),
                            ),
                            Text(w['status'] as String? ?? '',
                                style: const TextStyle(fontSize: 10, color: AppTheme.primary)),
                          ],
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}

class _Mini extends StatelessWidget {
  final String label;
  final String value;
  const _Mini({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
        ],
      );
}
