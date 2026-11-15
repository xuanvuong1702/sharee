import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../widgets/app_ui.dart';

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
      await state.signIn(auth.token, auth.refreshToken, auth.user);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: AppTheme.gradient)),
          Positioned(
            right: -80,
            top: -40,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            left: -70,
            top: 200,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        alignment: Alignment.center,
                        child: const Text('R',
                            style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 22,
                                fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 10),
                      const Text('Sharee',
                          style: TextStyle(
                              color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Bản demo',
                            style: TextStyle(
                                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Đi cùng nhau,\nđi xa hơn.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Chia sẻ chuyến đi, tiết kiệm chi phí,\ngặp gỡ những người đã xác thực.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF04122B).withValues(alpha: 0.25),
                          blurRadius: 40,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          switchInCurve: Curves.easeOutCubic,
                          child: _otpSent ? _otpForm() : _phoneForm(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: AppTheme.dangerSoft,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, size: 15, color: AppTheme.danger),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(_error!,
                                      style: const TextStyle(
                                          color: AppTheme.danger, fontSize: 11)),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Icon(Icons.lock_outline_rounded,
                                size: 12, color: AppTheme.mutedLight),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'Bảo mật thông tin. Chỉ cần số điện thoại để bắt đầu.',
                                style: TextStyle(
                                    fontSize: 9.5,
                                    color: AppTheme.mutedLight.withValues(alpha: 0.9),
                                    height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Text('Sharee 1.1.6 · made for learning',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45), fontSize: 9.5)),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: const [
                      Expanded(child: _HeroStat(value: '12k+', label: 'chuyến đi')),
                      _HeroDivider(),
                      Expanded(child: _HeroStat(value: '4.9', label: 'đánh giá')),
                      _HeroDivider(),
                      Expanded(child: _HeroStat(value: '24/7', label: 'hỗ trợ')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Tiếp tục nghĩa là bạn đồng ý với Điều khoản & Chính sách bảo mật.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35), fontSize: 8.5),
                    ),
                  ),
                ],
              ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _phoneForm() {
    return Column(
      key: const ValueKey('phone'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Đăng nhập',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const SizedBox(height: 3),
        const Text('Nhập số điện thoại để nhận mã xác thực',
            style: TextStyle(fontSize: 11.5, color: AppTheme.muted)),
        const SizedBox(height: 18),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Số điện thoại',
            prefixIcon: Icon(Icons.phone_iphone_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 13),
        PrimaryButton(label: 'Gửi mã OTP', loading: _busy, onPressed: _requestOtp),
        const SizedBox(height: 17),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Text('Đăng nhập nhanh',
                  style: TextStyle(
                      fontSize: 9.5, color: AppTheme.muted, fontWeight: FontWeight.w600)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            Expanded(
              child: _DemoAccount(
                label: 'Hành khách',
                name: 'Minh',
                icon: Icons.person_outline_rounded,
                onTap: () {
                  _phone.text = '+84912345678';
                  _requestOtp();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DemoAccount(
                label: 'Tài xế',
                name: 'Trung Kiên',
                icon: Icons.directions_car_outlined,
                onTap: () {
                  _phone.text = '+84912000001';
                  _requestOtp();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(child: _TrustItem(icon: Icons.verified_user_rounded, label: 'Xác thực CCCD')),
            Expanded(child: _TrustItem(icon: Icons.lock_rounded, label: 'Thanh toán an toàn')),
            Expanded(child: _TrustItem(icon: Icons.event_available_rounded, label: 'Huỷ linh hoạt')),
          ],
        ),
      ],
    );
  }

  Widget _otpForm() {
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _otpSent = false),
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF3F6FA),
                minimumSize: const Size(38, 38),
              ),
            ),
            const SizedBox(width: 9),
            const Expanded(
              child: Text('Nhập mã xác thực',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Mã 6 số đã gửi đến ${_phone.text}',
            style: const TextStyle(fontSize: 11.5, color: AppTheme.muted)),
        const SizedBox(height: 16),
        TextField(
          controller: _otp,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 12),
          decoration: const InputDecoration(counterText: '', hintText: '••••••'),
        ),
        if (_devCode != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Mã demo: $_devCode (đã tự điền)',
                      style: const TextStyle(
                          fontSize: 10.5, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        PrimaryButton(label: 'Xác thực và tiếp tục', loading: _busy, onPressed: _verify),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _busy ? null : _requestOtp,
          child: const Text('Không nhận được mã? Gửi lại'),
        ),
      ],
    );
  }
}

class _DemoAccount extends StatelessWidget {
  final String label;
  final String name;
  final IconData icon;
  final VoidCallback onTap;

  const _DemoAccount({
    required this.label,
    required this.name,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFD),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: [
              Container(
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: AppTheme.primary),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 8, color: AppTheme.muted, fontWeight: FontWeight.w600)),
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TrustItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppTheme.mutedLight),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 8.5, color: AppTheme.muted, height: 1.25)),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;

  const _HeroStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55), fontSize: 9)),
      ],
    );
  }
}

class _HeroDivider extends StatelessWidget {
  const _HeroDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: Colors.white.withValues(alpha: 0.15),
    );
  }
}
