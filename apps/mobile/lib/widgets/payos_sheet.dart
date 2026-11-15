import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/app_ui.dart';
import '../widgets/ui.dart';

class PayOsSheet extends StatefulWidget {
  final Api api;
  final String bookingId;
  final PayOsCheckout checkout;

  const PayOsSheet({
    super.key,
    required this.api,
    required this.bookingId,
    required this.checkout,
  });

  @override
  State<PayOsSheet> createState() => _PayOsSheetState();
}

class _PayOsSheetState extends State<PayOsSheet> {
  Timer? _poll;
  bool _checking = false;
  bool _paid = false;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_checking || _paid) return;
    _checking = true;
    _seconds += 3;
    try {
      final booking = await widget.api.booking(widget.bookingId);
      if (booking.confirmed && mounted) {
        _paid = true;
        _poll?.cancel();
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context, true);
      }
    } catch (_) {
      // Ignore transient errors; polling continues.
    } finally {
      _checking = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _open() async {
    final uri = Uri.tryParse(widget.checkout.checkoutUrl);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) showInfo(context, 'Không mở được trang PayOS');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.qr_code_2_rounded, color: AppTheme.primary, size: 21),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Thanh toán PayOS',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    Text('Quét QR hoặc mở trang thanh toán',
                        style: TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(money(widget.checkout.amount),
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.checkout.qrCode.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.line),
              ),
              child: QrImageView(
                data: widget.checkout.qrCode,
                size: 190,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppTheme.ink,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppTheme.ink,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text('Nội dung: ${widget.checkout.description}',
              style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Mở trang thanh toán',
            icon: Icons.open_in_new_rounded,
            onPressed: _open,
          ),
          const SizedBox(height: 8),
          if (_paid)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
                  SizedBox(width: 6),
                  Text('Đã thanh toán',
                      style: TextStyle(
                          color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 1.8, color: AppTheme.muted),
                ),
                const SizedBox(width: 7),
                Text('Đang chờ xác nhận thanh toán · $_seconds s',
                    style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
              ],
            ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Để sau'),
          ),
        ],
      ),
      ),
    );
  }
}
