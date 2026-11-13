import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/app_ui.dart';
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
      Navigator.of(context).pushReplacement(appRoute(
        BookingScreen(bookingId: booking.id),
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
            expandedHeight: 228,
            pinned: true,
            backgroundColor: const Color(0xFF0B2A6B),
            foregroundColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: _RoundIcon(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _RoundIcon(
                  icon: Icons.ios_share_rounded,
                  onTap: () => showInfo(context, 'Chia sẻ chuyến đi'),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroMap(result: r),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              transform: Matrix4.translationValues(0, -22, 0),
              decoration: const BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${hhmm(r.departureTime)} → ${hhmm(r.arriveEstimate)}',
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.6)),
                            const SizedBox(height: 2),
                            Text(dayLabel(r.departureTime),
                                style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(money(r.pricePerSeat),
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                          const Text('/ ghế',
                              style: TextStyle(fontSize: 10, color: AppTheme.muted)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        _StopRow(
                          time: hhmm(r.departureTime),
                          label: 'Đón khách',
                          address: r.pickupStop.name,
                          color: AppTheme.success,
                          first: true,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 20),
                          child: Row(
                            children: [
                              Container(width: 2, height: 26, color: AppTheme.line),
                              const SizedBox(width: 14),
                              const Pill('2 giờ 30 · 105 km', icon: Icons.schedule_rounded),
                            ],
                          ),
                        ),
                        _StopRow(
                          time: hhmm(r.arriveEstimate),
                          label: 'Trả khách',
                          address: r.dropoffStop.name,
                          color: AppTheme.accent,
                          first: false,
                        ),
                      ],
                    ),
                  ),
                  const SectionHeader('Tài xế'),
                  AppCard(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [
                              AppTheme.primary.withValues(alpha: 0.9),
                              AppTheme.primaryDark,
                            ]),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            r.driver.fullName.isNotEmpty ? r.driver.fullName[0] : '?',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(r.driver.fullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 15, fontWeight: FontWeight.w900)),
                                  ),
                                  const SizedBox(width: 5),
                                  const Icon(Icons.verified_rounded,
                                      size: 15, color: AppTheme.success),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, size: 13, color: AppTheme.accent),
                                  Text(' ${r.driver.ratingAvg.toStringAsFixed(1)} · ${r.driver.ratingCount} đánh giá',
                                      style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(r.vehicle.label,
                                  style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => showInfo(context, 'Nhắn tin sau khi đặt chỗ'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                          label: const Text('Chat', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                  const SectionHeader('Tiện nghi'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _Amenity(icon: Icons.luggage_rounded, label: 'Hành lý nhỏ'),
                      _Amenity(icon: Icons.pets_rounded, label: 'Thú cưng'),
                      _Amenity(icon: Icons.smoke_free_rounded, label: 'Không hút thuốc'),
                      _Amenity(icon: Icons.ac_unit_rounded, label: 'Điều hoà'),
                    ],
                  ),
                  const SectionHeader('Chỗ ngồi'),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(15, 12, 15, 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Số ghế bạn cần',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                                Text('Còn ${r.seatsAvailable} chỗ trống',
                                    style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                              ],
                            ),
                            const Spacer(),
                            _SeatStepper(
                              value: _seats,
                              max: r.seatsAvailable,
                              onChanged: (value) => setState(() => _seats = value),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          children: [
                            const Text('Tổng cộng',
                                style: TextStyle(fontSize: 12.5, color: AppTheme.muted)),
                            const Spacer(),
                            Text(money(total),
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            r.bookingMode == 'instant'
                                ? 'Đặt ngay · giữ ghế 10 phút'
                                : 'Cần tài xế duyệt · giữ ghế 15 phút',
                            style: const TextStyle(fontSize: 10, color: AppTheme.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_rounded, size: 18, color: AppTheme.primary),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Thanh toán an toàn. Hoàn tiền theo chính sách nếu huỷ trước 24 giờ.',
                            style: TextStyle(fontSize: 10.5, color: AppTheme.primary, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
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
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tổng cộng',
                      style: TextStyle(fontSize: 9.5, color: AppTheme.muted, fontWeight: FontWeight.w600)),
                  Text(money(total),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.ink)),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: PrimaryButton(
                  label: _busy ? 'Đang giữ ghế…' : 'Đặt $_seats ghế',
                  icon: Icons.arrow_forward_rounded,
                  loading: _busy,
                  onPressed: _book,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroMap extends StatelessWidget {
  final SearchResult result;
  const _HeroMap({required this.result});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF071B45), Color(0xFF0B2A6B), Color(0xFF1657E8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        CustomPaint(painter: _RoutePainter()),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF071B45).withValues(alpha: 0.1),
                  const Color(0xFF071B45).withValues(alpha: 0.78),
                ],
                stops: const [0, 0.5, 1],
              ),
            ),
          ),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 34,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${result.pickupStop.name.split(',').first} → ${result.dropoffStop.name.split(',').first}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text('${result.driver.fullName} · ${result.vehicle.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Text('${result.seatsAvailable} chỗ',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  final String time;
  final String label;
  final String address;
  final Color color;
  final bool first;

  const _StopRow({
    required this.time,
    required this.label,
    required this.address,
    required this.color,
    required this.first,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: first ? 0 : 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(time,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
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
        ),
      ],
    );
  }
}

class _Amenity extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Amenity({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SeatStepper extends StatelessWidget {
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  const _SeatStepper({required this.value, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepperButton(
          icon: Icons.remove_rounded,
          enabled: value > 1,
          onTap: () => onChanged(value - 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ),
        _StepperButton(
          icon: Icons.add_rounded,
          enabled: value < max,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepperButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.primarySoft : const Color(0xFFF3F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 17, color: enabled ? AppTheme.primary : AppTheme.mutedLight),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.22),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.95)
      ..cubicTo(size.width * 0.26, size.height * 0.82, size.width * 0.34,
          size.height * 0.5, size.width * 0.54, size.height * 0.42)
      ..cubicTo(size.width * 0.72, size.height * 0.36, size.width * 0.78,
          size.height * 0.22, size.width * 0.93, size.height * 0.17);

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.95), 9,
        Paint()..color = AppTheme.success);
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.95), 4,
        Paint()..color = Colors.white);
    canvas.drawCircle(Offset(size.width * 0.93, size.height * 0.17), 9,
        Paint()..color = AppTheme.accent);
    canvas.drawCircle(Offset(size.width * 0.93, size.height * 0.17), 4,
        Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
