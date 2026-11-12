import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/ui.dart';
import 'chat_screen.dart';

class BookingScreen extends StatefulWidget {
  final String bookingId;
  const BookingScreen({super.key, required this.bookingId});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late Future<Booking> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = AppScope.of(context).api.booking(widget.bookingId);
  }

  Future<void> _pay() async {
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

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Huỷ chuyến?'),
        content: const Text('Huỷ trước 24 giờ được hoàn 100%, 6–24 giờ hoàn 70%, dưới 6 giờ không hoàn.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Giữ chuyến')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xác nhận huỷ')),
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
                    icon: Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber),
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
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('${snapshot.error}')));
          }
          final booking = snapshot.data!;
          final isDriver = booking.driver.id == AppScope.of(context).user?.id;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: booking.confirmed ? const Color(0xFFE6F8F0) : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      booking.confirmed ? Icons.check_circle : Icons.schedule,
                      color: booking.confirmed ? AppTheme.success : AppTheme.warning,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(statusLabel(booking.status),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: booking.confirmed ? const Color(0xFF067647) : const Color(0xFFB45309),
                              )),
                          Text(
                            booking.confirmed
                                ? 'Mã đặt chỗ ${booking.id.substring(0, 8).toUpperCase()}'
                                : 'Hoàn tất thanh toán để giữ ghế',
                            style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                          ),
                        ],
                      ),
                    ),
                    StatusPill(status: booking.status),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${booking.originLabel} → ${booking.destinationLabel}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('${dayLabel(booking.departureTime)} · ${hhmm(booking.departureTime)}',
                          style: const TextStyle(fontSize: 11.5, color: AppTheme.muted)),
                      const Divider(height: 22),
                      Row(
                        children: [
                          AvatarCircle(name: booking.driver.fullName, size: 34),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(booking.driver.fullName,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                                Text('${booking.vehicle.label} · ★ ${booking.driver.ratingAvg.toStringAsFixed(1)}',
                                    style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 22),
                      InfoRow(icon: Icons.trip_origin, label: 'Đón', value: booking.fromStop.name),
                      InfoRow(icon: Icons.place_outlined, label: 'Trả', value: booking.toStop.name),
                      InfoRow(icon: Icons.event_seat_outlined, label: 'Số ghế', value: '${booking.seats}'),
                      InfoRow(icon: Icons.payments_outlined, label: 'Tổng tiền', value: money(booking.priceTotal)),
                    ],
                  ),
                ),
              ),
              if (booking.needsPayment) ...[
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _busy ? null : _pay,
                  child: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('Thanh toán ${money(booking.priceTotal)}'),
                ),
              ],
              if (booking.confirmed || booking.status == 'completed') ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ChatThreadsScreen())),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Nhắn tin với tài xế'),
                ),
              ],
              if (booking.status == 'completed') ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _review,
                  icon: const Icon(Icons.star_outline, size: 18),
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
                FilledButton(
                  onPressed: _busy ? null : () => _driverAction('complete'),
                  child: const Text('Hoàn thành chuyến'),
                ),
              ],
              if (booking.status == 'pending_payment' ||
                  booking.status == 'pending_driver' ||
                  booking.status == 'confirmed') ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _busy ? null : _cancel,
                  child: const Text('Huỷ chuyến', style: TextStyle(color: AppTheme.danger)),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
