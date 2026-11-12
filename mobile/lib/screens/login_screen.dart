import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../widgets/ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController(text: '+84912345678');
  final _otp = TextEditingController();
  bool _otpSent = false;
  bool _busy = false;
  String? _devCode;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final state = AppScope.of(context);
      final data = await state.api.requestOtp(_phone.text.trim());
      setState(() {
        _otpSent = true;
        _devCode = data['devCode'] as String?;
        if (_devCode != null) _otp.text = _devCode!;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final state = AppScope.of(context);
      final auth = await state.api.verifyOtp(_phone.text.trim(), _otp.text.trim());
      await state.signIn(auth.token, auth.user);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 62)),
              const SizedBox(height: 24),
              Text(
                _otpSent ? 'Nhập mã xác thực' : 'Đi chung xe,\nđơn giản hơn.',
                style: const TextStyle(
                  fontSize: 30,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _otpSent
                    ? 'Mã đã gửi đến ${_phone.text}. Nhập mã 6 số để tiếp tục.'
                    : 'Tìm người đi cùng đường, chia sẻ chi phí, đi cùng người đã xác thực.',
                style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppTheme.muted),
              ),
              const SizedBox(height: 28),
              if (!_otpSent) ...[
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    prefixIcon: Icon(Icons.phone_iphone_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _busy ? null : _requestOtp,
                  child: _busy
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Gửi mã OTP'),
                ),
                const SizedBox(height: 18),
                const Row(children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('hoặc', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
                  ),
                  Expanded(child: Divider()),
                ]),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _requestOtp,
                  icon: const Icon(Icons.verified_user_outlined, size: 18),
                  label: const Text('Dùng số demo +84912345678'),
                ),
              ] else ...[
                TextField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 8),
                  decoration: const InputDecoration(
                    labelText: 'Mã OTP',
                    counterText: '',
                    prefixIcon: Icon(Icons.password_rounded),
                  ),
                ),
                if (_devCode != null)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF0FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mã demo: $_devCode (tự điền)',
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _busy ? null : _verify,
                  child: _busy
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Xác thực và vào ứng dụng'),
                ),
                TextButton(
                  onPressed: () => setState(() => _otpSent = false),
                  child: const Text('Đổi số điện thoại'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
                ),
              ],
              const SizedBox(height: 26),
              const Text(
                'Bằng cách tiếp tục, bạn đồng ý với Điều khoản và Chính sách quyền riêng tư.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: AppTheme.muted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
