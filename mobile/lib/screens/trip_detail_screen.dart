import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/ui.dart';
import 'booking_screen.dart';

class TripDetailScreen extends StatefulWidget {
  final SearchResult result;
  final int seats;
  const TripDetailScreen({super.key, required this.result, required this.seats});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late int _seats = widget.seats;
  bool _busy = false;

  Future<void> _book() async {
    setState(() => _busy = true);
    try {
      final booking = await AppScope.of(context).api.createBooking(
            tripId: widget.result.tripId,
            seats: _seats,
            fromStopId: widget.result.pickupStop.id,
            toStopId: widget.result.dropoffStop.id,
          );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => BookingScreen(bookingId: booking.id),
      ));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final total = r.pricePerSeat * _seats;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 190,
            pinned: true,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFDDE9CF), Color(0xFFEDF1E7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CustomPaint(painter: _RoutePainter()),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(hhmm(r.departureTime),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, size: 16, color: AppTheme.muted),
                      ),
                      Text(hhmm(r.arriveEstimate),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      const Spacer(),
                      Text(money(r.pricePerSeat),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      const Text('/ghế', style: TextStyle(fontSize: 10, color: AppTheme.muted)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              AvatarCircle(name: r.driver.fullName, size: 48),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(r.driver.fullName,
                                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.verified, size: 15, color: AppTheme.success),
                                      ],
                                    ),
                                    Text('★ ${r.driver.ratingAvg.toStringAsFixed(1)} · ${r.driver.ratingCount} chuyến',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => showInfo(context, 'Nhắn tin sau khi đặt chỗ'),
                                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                                label: const Text('Chat', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                          const Divider(height: 22),
                          _timeline(Icons.trip_origin, AppTheme.success, '${hhmm(r.departureTime)} · ${r.pickupStop.name}'),
                          const SizedBox(height: 6),
                          _timeline(Icons.place, AppTheme.warning, '${hhmm(r.arriveEstimate)} · ${r.dropoffStop.name}'),
                          const Divider(height: 22),
                          Row(
                            children: [
                              _amenity(Icons.luggage_outlined, 'Hành lý nhỏ'),
                              const SizedBox(width: 8),
                              _amenity(Icons.pets_outlined, 'Thú cưng OK'),
                              const SizedBox(width: 8),
                              _amenity(Icons.smoke_free, 'Không hút thuốc'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SectionTitle('Số ghế'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          const Text('Chọn số ghế', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          IconButton(
                            onPressed: _seats > 1 ? () => setState(() => _seats--) : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('$_seats', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          IconButton(
                            onPressed: _seats < r.seatsAvailable ? () => setState(() => _seats++) : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Tổng cộng', style: TextStyle(fontSize: 13, color: AppTheme.muted)),
                      const Spacer(),
                      Text(money(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.bookingMode == 'instant'
                        ? 'Đặt ngay · ghế được giữ trong 10 phút để thanh toán'
                        : 'Cần tài xế duyệt · ghế được giữ 15 phút',
                    style: const TextStyle(fontSize: 10.5, color: AppTheme.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE7ECF3))),
        ),
        child: SafeArea(
          top: false,
          child: FilledButton(
            onPressed: _busy ? null : _book,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Đặt $_seats ghế · ${money(total)}'),
          ),
        ),
      ),
    );
  }

  Widget _timeline(IconData icon, Color color, String text) => Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      );

  Widget _amenity(IconData icon, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F6FA),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: AppTheme.muted),
              const SizedBox(height: 3),
              Text(label, style: const TextStyle(fontSize: 8.5, color: AppTheme.muted)),
            ],
          ),
        ),
      );
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.82)
      ..cubicTo(size.width * 0.3, size.height * 0.7, size.width * 0.35, size.height * 0.45,
          size.width * 0.55, size.height * 0.4)
      ..cubicTo(size.width * 0.75, size.height * 0.35, size.width * 0.8, size.height * 0.2,
          size.width * 0.92, size.height * 0.15);
    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.82), 7, Paint()..color = AppTheme.success);
    canvas.drawCircle(Offset(size.width * 0.92, size.height * 0.15), 7, Paint()..color = AppTheme.warning);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
