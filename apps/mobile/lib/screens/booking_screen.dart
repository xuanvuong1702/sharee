import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/app_ui.dart';
import '../widgets/payos_sheet.dart';
import '../widgets/ui.dart';
import 'chat_screen.dart';
import 'tracking_screen.dart';

class BookingScreen extends StatefulWidget {
  final String bookingId;
  const BookingScreen({super.key, required this.bookingId});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late Future<Booking> _future;
  bool _started = false;
  bool _busy = false;
  String _paymentProvider = 'mock';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
    _loadPaymentConfig();
  }

  Future<void> _loadPaymentConfig() async {
    try {
      final config = await AppScope.of(context).api.paymentConfig();
      if (mounted) setState(() => _paymentProvider = config.provider);
    } catch (_) {}
  }

  void _load() {
    _future = AppScope.of(context).api.booking(widget.bookingId);
  }

  Future<void> _pay() async {
    if (_paymentProvider == 'payos') {
      await _payWithPayOs();
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.of(context).api.pay(widget.bookingId);
      setState(_load);
      if (mounted) showInfo(context, 'Thanh toán thành công');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payWithPayOs() async {
    setState(() => _busy = true);
    try {
      final api = AppScope.of(context).api;
      final checkout = await api.createPayOsPayment(widget.bookingId);
      if (!mounted) return;
      final paid = await showAppSheet<bool>(
        context,
        PayOsSheet(api: api, bookingId: widget.bookingId, checkout: checkout),
      );
      if (!mounted) return;
      setState(_load);
      if (paid == true) showInfo(context, 'Thanh toán PayOS thành công');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Huỷ chuyến?'),
        content: const Text('Huỷ trước 24 giờ được hoàn 100%, 6–24 giờ hoàn 70%, dưới 6 giờ không hoàn.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Giữ chuyến')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Xác nhận huỷ'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context).api.cancelBooking(widget.bookingId);
      setState(_load);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _driverAction(String action) async {
    setState(() => _busy = true);
    try {
      final api = AppScope.of(context).api;
      if (action == 'accept') {
        await api.acceptBooking(widget.bookingId);
      } else if (action == 'reject') {
        await api.rejectBooking(widget.bookingId);
      } else if (action == 'complete') {
        await api.completeBooking(widget.bookingId);
      }
      setState(_load);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review() async {
    var rating = 5;
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Đánh giá chuyến đi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    onPressed: () => setDialogState(() => rating = i + 1),
                    icon: Icon(i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                        color: AppTheme.accent, size: 30),
                  );
                }),
              ),
              TextField(
                controller: controller,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'Nhận xét (tuỳ chọn)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Để sau')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Gửi')),
          ],
        ),
      ),
    );
    if (result != true) return;
    try {
      await AppScope.of(context).api.review(widget.bookingId, rating, controller.text.trim());
      if (mounted) showInfo(context, 'Cảm ơn đánh giá của bạn');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết đặt chỗ')),
      body: FutureBuilder<Booking>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Skeleton(height: 110, radius: 20),
                  SizedBox(height: 12),
                  Skeleton(height: 220, radius: 20),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
                child: Padding(padding: const EdgeInsets.all(24), child: Text('${snapshot.error}')));
          }
          final booking = snapshot.data!;
          final isDriver = booking.driver.id == AppScope.of(context).user?.id;
          final confirmed = booking.confirmed || booking.status == 'completed';
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              AppCard(
                gradient: confirmed
                    ? const LinearGradient(colors: [Color(0xFF067647), Color(0xFF0FA968)])
                    : const LinearGradient(colors: [Color(0xFFB45309), Color(0xFFFF9F1C)]),
                border: null,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            confirmed ? Icons.check_rounded : Icons.schedule_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(statusLabel(booking.status),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 2),
                              Text(
                                booking.status == 'pending_payment'
                                    ? 'Hoàn tất thanh toán để giữ ghế'
                                    : booking.status == 'pending_driver'
                                        ? 'Đang chờ tài xế chấp nhận yêu cầu'
                                        : booking.status == 'confirmed'
                                            ? 'Mã đặt chỗ ${booking.id.substring(0, 8).toUpperCase()}'
                                            : booking.status == 'completed'
                                                ? 'Chuyến đi đã hoàn thành'
                                                : statusLabel(booking.status),
                                style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                        Pill(booking.seats > 1 ? '${booking.seats} ghế' : '1 ghế',
                            color: Colors.white, background: Colors.white.withValues(alpha: 0.18)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('${booking.originLabel.split(',').first} → ${booking.destinationLabel.split(',').first}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text('${dayLabel(booking.departureTime)} · ${hhmm(booking.departureTime)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              if (booking.confirmed || booking.status == 'completed') ...[
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Theo dõi trực tiếp',
                  icon: Icons.near_me_rounded,
                  onPressed: () => Navigator.of(context).push(
                    appRoute(TrackingScreen(tripId: booking.tripId)),
                  ),
                ),
              ],
              const SectionHeader('Hành trình'),
              AppCard(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    _StopRow(
                      time: hhmm(booking.departureTime),
                      label: 'Đón khách',
                      address: booking.fromStop.name,
                      color: AppTheme.success,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 7),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          height: 24,
                          child: VerticalDivider(width: 2, thickness: 2, color: AppTheme.line),
                        ),
                      ),
                    ),
                    _StopRow(
                      time: '—',
                      label: 'Trả khách (dự kiến)',
                      address: booking.toStop.name,
                      color: AppTheme.accent,
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.primarySoft,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(Icons.directions_car_rounded,
                              size: 18, color: AppTheme.primary),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(booking.driver.fullName,
                                  style: const TextStyle(
                                      fontSize: 12.5, fontWeight: FontWeight.w800)),
                              Text(
                                  '${booking.vehicle.label} · ★ ${booking.driver.ratingAvg.toStringAsFixed(1)}',
                                  style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
                            ],
                          ),
                        ),
                        const Icon(Icons.verified_rounded, size: 17, color: AppTheme.success),
                      ],
                    ),
                  ],
                ),
              ),
              const SectionHeader('Thanh toán'),
              AppCard(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    _MoneyRow(label: 'Giá ${booking.seats} ghế', value: money(booking.priceTotal)),
                    const SizedBox(height: 8),
                    const _MoneyRow(label: 'Phí nền tảng', value: '0đ', success: true),
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Text('Tổng cộng',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        Text(money(booking.priceTotal),
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SectionHeader('Trạng thái'),
              AppCard(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    _Step(
                      label: 'Đặt chỗ',
                      sub: 'Ghế được giữ tạm thời',
                      done: true,
                    ),
                    _Step(
                      label: 'Thanh toán',
                      sub: booking.needsPayment ? 'Đang chờ thanh toán' : 'Đã thanh toán',
                      done: !booking.needsPayment,
                      active: booking.needsPayment,
                    ),
                    _Step(
                      label: 'Tài xế xác nhận',
                      sub: confirmed ? 'Đã xác nhận' : 'Chờ tài xế duyệt',
                      done: confirmed,
                      active: !confirmed && !booking.needsPayment,
                    ),
                    _Step(
                      label: 'Hoàn thành chuyến',
                      sub: 'Đánh giá sau chuyến đi',
                      done: booking.status == 'completed',
                      last: true,
                    ),
                  ],
                ),
              ),
              if (booking.confirmed || booking.status == 'completed') ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).push(appRoute(const ChatThreadsScreen())),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Nhắn tin với tài xế'),
                ),
              ],
              if (booking.status == 'completed') ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _review,
                  icon: const Icon(Icons.star_outline_rounded, size: 18),
                  label: const Text('Đánh giá chuyến đi'),
                ),
              ],
              if (isDriver && booking.status == 'pending_driver') ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _driverAction('reject'),
                        child: const Text('Từ chối'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : () => _driverAction('accept'),
                        child: const Text('Chấp nhận'),
                      ),
                    ),
                  ],
                ),
              ],
              if (isDriver && booking.status == 'confirmed') ...[
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Hoàn thành chuyến',
                  loading: _busy,
                  onPressed: () => _driverAction('complete'),
                ),
              ],
              if (booking.status == 'pending_payment' ||
                  booking.status == 'pending_driver' ||
                  booking.status == 'confirmed') ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : _cancel,
                  child: const Text('Huỷ chuyến', style: TextStyle(color: AppTheme.danger)),
                ),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<Booking>(
        future: _future,
        builder: (context, snapshot) {
          final booking = snapshot.data;
          if (booking == null || !booking.needsPayment) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: PrimaryButton(
                label: _paymentProvider == 'payos'
                    ? 'Thanh toán PayOS · ${money(booking.priceTotal)}'
                    : 'Thanh toán ${money(booking.priceTotal)}',
                icon: Icons.lock_rounded,
                loading: _busy,
                onPressed: _pay,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  final String time;
  final String label;
  final String address;
  final Color color;

  const _StopRow({
    required this.time,
    required this.label,
    required this.address,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(time,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 7),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 9.5, color: AppTheme.muted, fontWeight: FontWeight.w600)),
                ],
              ),
              Text(address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoneyRow extends StatelessWidget {
  final String label;
  final String value;
  final bool success;

  const _MoneyRow({required this.label, required this.value, this.success = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppTheme.muted)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: success ? AppTheme.success : AppTheme.ink)),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final String label;
  final String sub;
  final bool done;
  final bool active;
  final bool last;

  const _Step({
    required this.label,
    required this.sub,
    required this.done,
    this.active = false,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = done ? AppTheme.success : (active ? AppTheme.primary : AppTheme.mutedLight);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppTheme.success : (active ? AppTheme.primary : Colors.white),
                border: Border.all(color: color, width: 1.5),
              ),
              child: done
                  ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                  : active
                      ? const Icon(Icons.circle, size: 6, color: Colors.white)
                      : null,
            ),
            if (!last) Container(width: 2, height: 26, color: AppTheme.line),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: done || active ? AppTheme.ink : AppTheme.muted)),
                Text(sub, style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
