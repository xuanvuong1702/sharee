import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../widgets/app_ui.dart';

class TipAccountScreen extends StatefulWidget {
  const TipAccountScreen({super.key});

  @override
  State<TipAccountScreen> createState() => _TipAccountScreenState();
}

class _TipAccountScreenState extends State<TipAccountScreen> {
  static const _banks = [
    ('Vietcombank', '970436'),
    ('BIDV', '970418'),
    ('VietinBank', '970415'),
    ('Agribank', '970405'),
    ('Techcombank', '970407'),
    ('MB Bank', '970422'),
    ('ACB', '970416'),
    ('VPBank', '970432'),
    ('TPBank', '970423'),
    ('Sacombank', '970403'),
  ];

  final _form = GlobalKey<FormState>();
  final _bin = TextEditingController();
  final _bankName = TextEditingController();
  final _accountNumber = TextEditingController();
  final _accountName = TextEditingController();
  TipAccount? _account;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loading) return;
    _load();
  }

  Future<void> _load() async {
    try {
      final account = await AppScope.of(context).api.tipAccount();
      if (!mounted) return;
      setState(() {
        _account = account;
        if (account != null) {
          _bin.text = account.bankBin;
          _bankName.text = account.bankName;
          _accountNumber.text = account.accountNumber;
          _accountName.text = account.accountName;
        }
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

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final account = await AppScope.of(context).api.saveTipAccount(
        bankBin: _bin.text.trim(),
        bankName: _bankName.text.trim(),
        accountNumber: _accountNumber.text.trim(),
        accountName: _accountName.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _account = account;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu tài khoản nhận tip')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  void dispose() {
    _bin.dispose();
    _bankName.dispose();
    _accountNumber.dispose();
    _accountName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nhận tip')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                AppCard(
                  gradient: AppTheme.gradient,
                  border: null,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(Icons.qr_code_2_rounded,
                                color: Colors.white, size: 23),
                          ),
                          const SizedBox(width: 11),
                          const Expanded(
                            child: Text('Tài khoản nhận tip',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Khách quét QR để chuyển tip trực tiếp vào tài khoản của bạn. Sharee không giữ khoản tiền này.',
                        style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_account?.qrPayload.isNotEmpty == true) ...[
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        QrImageView(
                          data: _account!.qrPayload,
                          size: 190,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 10),
                        Text(_account!.bankName.isEmpty
                            ? 'Ngân hàng BIN ${_account!.bankBin}'
                            : _account!.bankName,
                            style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
                        Text('${_account!.accountNumber} · ${_account!.accountName}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Form(
                  key: _form,
                  child: AppCard(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Thông tin nhận tiền',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _bin,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            labelText: 'Mã BIN ngân hàng',
                            hintText: 'Ví dụ: Vietcombank 970436',
                            counterText: '',
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (!RegExp(r'^\d{6}$').hasMatch(text)) {
                              return 'BIN phải gồm đúng 6 chữ số';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final bank in _banks)
                              ActionChip(
                                label: Text(bank.$1, style: const TextStyle(fontSize: 10)),
                                onPressed: () => setState(() {
                                  _bin.text = bank.$2;
                                  if (_bankName.text.trim().isEmpty) {
                                    _bankName.text = bank.$1;
                                  }
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        TextFormField(
                          controller: _bankName,
                          maxLength: 80,
                          decoration: const InputDecoration(
                            labelText: 'Tên ngân hàng (không bắt buộc)',
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 9),
                        TextFormField(
                          controller: _accountNumber,
                          keyboardType: TextInputType.number,
                          maxLength: 19,
                          decoration: const InputDecoration(
                            labelText: 'Số tài khoản',
                            counterText: '',
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (!RegExp(r'^\d{6,19}$').hasMatch(text)) {
                              return 'Số tài khoản phải gồm 6–19 chữ số';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 9),
                        TextFormField(
                          controller: _accountName,
                          maxLength: 80,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Tên chủ tài khoản',
                            hintText: 'NGUYEN VAN A',
                            counterText: '',
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.length < 2) return 'Nhập tên chủ tài khoản';
                            return null;
                          },
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!,
                              style: const TextStyle(color: AppTheme.danger, fontSize: 11)),
                        ],
                        const SizedBox(height: 13),
                        PrimaryButton(
                          label: _saving ? 'Đang lưu...' : 'Lưu tài khoản',
                          onPressed: _saving ? null : _save,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Mã QR được tạo theo chuẩn VietQR/NAPAS 247. Kiểm tra kỹ số tài khoản trước khi lưu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: AppTheme.muted, height: 1.4),
                ),
              ],
            ),
    );
  }
}
