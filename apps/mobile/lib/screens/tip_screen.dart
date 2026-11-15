import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/app_ui.dart';
import '../widgets/ui.dart';

class TipScreen extends StatefulWidget {
  final String bookingId;
  final String driverName;
  const TipScreen({super.key, required this.bookingId, required this.driverName});

  @override
  State<TipScreen> createState() => _TipScreenState();
}

class _TipScreenState extends State<TipScreen> {
  final _custom = TextEditingController();
  final _message = TextEditingController();
  BookingTipInfo? _info;
  CreateTipResult? _result;
  int _amount = 50000;
  String _method = 'bank_transfer';
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loading) return;
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await AppScope.of(context).api.bookingTipInfo(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _info = info;
        if (info.existing != null) {
          _result = CreateTipResult(
            tip: info.existing!,
            account: info.account,
            qrPayload: info.qrPayload,
          );
          _amount = info.existing!.amount;
        }
        if (info.account == null) _method = 'cash';
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

  Future<void> _send() async {
    final amount = int.tryParse(_custom.text.trim()) ?? _amount;
    if (amount < 1000 || amount > 1000000) {
      setState(() => _error = 'Tip phải từ 1.000đ đến 1.000.000đ');
      return;
    }
    if (_method == 'bank_transfer' && _info?.account == null) {
      setState(() => _error = 'Tài xế chưa cấu hình tài khoản nhận tip');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await AppScope.of(context).api.createTip(
            widget.bookingId,
            amount: amount,
            method: _method,
            message: _message.text.trim().isEmpty ? null : _message.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _result = result;
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _sending = false;
      });
    }
  }

  Future<void> _markSent() async {
    final tip = _result?.tip;
    if (tip == null) return;
    setState(() => _sending = true);
    try {
      final updated = await AppScope.of(context).api.tipSent(tip.id);
      if (!mounted) return;
      setState(() {
        _result = CreateTipResult(
          tip: updated,
          account: _result?.account,
          qrPayload: _result?.qrPayload,
        );
        _sending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã báo tài xế kiểm tra khoản tip')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = '$e';
      });
    }
  }

  Future<void> _cancel() async {
    final tip = _result?.tip;
    if (tip == null) return;
    try {
      await AppScope.of(context).api.cancelTip(tip.id);
      if (!mounted) return;
      Navigator.pop(context, false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _custom.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tip tài xế')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                AppCard(
                  gradient: AppTheme.gradient,
                  border: null,
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      AvatarCircle(name: widget.driverName, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Cảm ơn chuyến đi',
                                style: TextStyle(color: Colors.white70, fontSize: 10)),
                            const SizedBox(height: 2),
                            Text(widget.driverName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 3),
                            const Text('Một chút tip giúp tài xế có thêm động lực.',
                                style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                          ],
                        ),
                      ),
                      const Icon(Icons.favorite_rounded, color: Color(0xFFFFC46B), size: 26),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_result != null)
                  _ExistingTip(
                    result: _result!,
                    sending: _sending,
                    onSent: _markSent,
                    onCancel: _cancel,
                  )
                else
                  _buildForm(),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.danger, fontSize: 11)),
                ],
              ],
            ),
    );
  }

  Widget _buildForm() {
    final account = _info?.account;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Chọn số tiền'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final amount in [20000, 50000, 100000, 200000])
              _AmountChip(
                amount: amount,
                active: _amount == amount && _custom.text.trim().isEmpty,
                onTap: () => setState(() {
                  _amount = amount;
                  _custom.clear();
                }),
              ),
          ],
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: TextField(
            controller: _custom,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Số tiền khác',
              hintText: '1.000 – 1.000.000',
              suffixText: 'đ',
              border: InputBorder.none,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 14),
        const SectionTitle('Lời nhắn'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: TextField(
            controller: _message,
            maxLength: 200,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Cảm ơn tài xế... (không bắt buộc)',
              border: InputBorder.none,
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: 14),
        const SectionTitle('Cách gửi'),
        _MethodCard(
          icon: Icons.qr_code_2_rounded,
          title: 'Chuyển khoản / QR',
          subtitle: account == null
              ? 'Tài xế chưa cấu hình nhận tip'
              : 'Quét VietQR, chuyển thẳng vào tài khoản tài xế',
          active: _method == 'bank_transfer',
          enabled: account != null,
          onTap: () => setState(() => _method = 'bank_transfer'),
        ),
        const SizedBox(height: 8),
        _MethodCard(
          icon: Icons.payments_rounded,
          title: 'Tiền mặt',
          subtitle: 'Đưa trực tiếp cho tài xế và ghi nhận lại',
          active: _method == 'cash',
          enabled: true,
          onTap: () => setState(() => _method = 'cash'),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: _sending ? 'Đang gửi...' : 'Gửi tip',
          onPressed: _sending ? null : _send,
        ),
        const SizedBox(height: 10),
        const Text(
          'Tip là tự nguyện, không bắt buộc. Với chuyển khoản, tài xế sẽ xác nhận sau khi nhận được tiền.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: AppTheme.muted, height: 1.4),
        ),
      ],
    );
  }
}

class _AmountChip extends StatelessWidget {
  final int amount;
  final bool active;
  final VoidCallback onTap;

  const _AmountChip({required this.amount, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AppTheme.primary : AppTheme.line),
        ),
        child: Text(money(amount),
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : AppTheme.ink)),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: AppCard(
        onTap: enabled ? onTap : null,
        padding: const EdgeInsets.all(13),
        border: Border.all(color: active ? AppTheme.primary : AppTheme.line, width: active ? 1.5 : 1),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: active ? AppTheme.primarySoft : const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: active ? AppTheme.primary : AppTheme.muted),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 10, color: AppTheme.muted, height: 1.3)),
                ],
              ),
            ),
            if (active)
              const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ExistingTip extends StatelessWidget {
  final CreateTipResult result;
  final bool sending;
  final VoidCallback onSent;
  final VoidCallback onCancel;

  const _ExistingTip({
    required this.result,
    required this.sending,
    required this.onSent,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final tip = result.tip;
    if (tip.confirmed) {
      return AppCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(color: AppTheme.successSoft, shape: BoxShape.circle),
              child: const Icon(Icons.favorite_rounded, color: AppTheme.success, size: 30),
            ),
            const SizedBox(height: 12),
            const Text('Đã ghi nhận tip',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('${money(tip.amount)} · ${tip.methodLabel}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            if (tip.message != null) ...[
              const SizedBox(height: 8),
              Text('“${tip.message}”',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
            ],
            const SizedBox(height: 6),
            const Text('Cảm ơn bạn đã ủng hộ tài xế!',
                style: TextStyle(fontSize: 11, color: AppTheme.muted)),
          ],
        ),
      );
    }

    final account = result.account;
    final qr = result.qrPayload;
    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Quét VietQR để chuyển tip',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('${money(tip.amount)} · ${tip.message ?? 'Cảm ơn tài xế'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
              const SizedBox(height: 12),
              if (qr != null && qr.isNotEmpty)
                QrImageView(data: qr, size: 210, backgroundColor: Colors.white)
              else
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Không tạo được mã QR', style: TextStyle(color: AppTheme.danger)),
                ),
              if (account != null) ...[
                const SizedBox(height: 10),
                Text(account.bankName.isEmpty ? 'Ngân hàng BIN ${account.bankBin}' : account.bankName,
                    style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                const SizedBox(height: 2),
                Text(account.accountNumber,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
                Text(account.accountName,
                    style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: account.accountNumber));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã sao chép số tài khoản')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  label: const Text('Sao chép số tài khoản'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: sending ? 'Đang gửi...' : 'Tôi đã chuyển khoản',
          onPressed: sending ? null : onSent,
        ),
        TextButton(
          onPressed: sending ? null : onCancel,
          child: const Text('Huỷ tip này'),
        ),
      ],
    );
  }
}
