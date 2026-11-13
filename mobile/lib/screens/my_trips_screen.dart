import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/app_ui.dart';
import '../widgets/ui.dart';
import 'booking_screen.dart';
import 'chat_screen.dart';
import 'tracking_screen.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  late Future<List<Booking>> _future;
  bool _started = false;
  int _filter = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  void _load() {
    _future = AppScope.of(context).api.myBookings();
  }

  bool _matches(Booking b) {
    if (_filter == 0) return true;
    if (_filter == 1) {
      return b.status == 'confirmed' || b.status == 'pending_payment' || b.status == 'pending_driver';
    }
    return b.status == 'completed' || b.status.startsWith('cancelled') || b.status == 'refunded';
  }

  bool _isUpcoming(Booking b) =>
      b.status == 'confirmed' || b.status == 'pending_payment' || b.status == 'pending_driver';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chuyến của tôi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text('Quản lý vé và lịch trình', style: TextStyle(fontSize: 11, color: AppTheme.muted)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(appRoute(const ChatThreadsScreen())),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 21),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: FutureBuilder<List<Booking>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                Skeleton(height: 130, radius: 20),
                SizedBox(height: 12),
                TripSkeleton(),
                SizedBox(height: 10),
                TripSkeleton(),
              ],
            );
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Không tải được chuyến',
              message: '${snapshot.error}',
              actionLabel: 'Thử lại',
              onAction: () => setState(_load),
            );
          }
          final all = snapshot.data ?? [];
          final items = all.where(_matches).toList();
          final upcoming = all.where(_isUpcoming).toList()
            ..sort((a, b) => a.departureTime.compareTo(b.departureTime));
          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async => setState(_load),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                if (_filter == 0 && upcoming.isNotEmpty) ...[
                  _NextTripCard(booking: upcoming.first),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    _FilterChip(
                        label: 'Tất cả',
                        count: all.length,
                        active: _filter == 0,
                        onTap: () => setState(() => _filter = 0)),
                    const SizedBox(width: 7),
                    _FilterChip(
                        label: 'Sắp tới',
                        count: all.where(_isUpcoming).length,
                        active: _filter == 1,
                        onTap: () => setState(() => _filter = 1)),
                    const SizedBox(width: 7),
                    _FilterChip(
                        label: 'Đã xong',
                        count: all.where((b) => !_isUpcoming(b)).length,
                        active: _filter == 2,
                        onTap: () => setState(() => _filter = 2)),
                  ],
                ),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: Icons.luggage_rounded,
                      title: 'Chưa có chuyến nào',
                      message: 'Đặt chuyến đầu tiên để bắt đầu hành trình của bạn.',
                    ),
                  )
                else
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _BookingCard(booking: items[i]),
                  ],
                if (items.length < 3) ...[
                  const SizedBox(height: 14),
                  AppCard(
                    padding: const EdgeInsets.all(13),
                    shadow: false,
                    color: AppTheme.primarySoft,
                    border: Border.all(color: const Color(0xFFD5E1FF)),
                    child: const Row(
                      children: [
                        Icon(Icons.lightbulb_outline_rounded, size: 18, color: AppTheme.primary),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Mẹo: đặt chuyến trước 1–2 ngày để có nhiều lựa chọn và giá tốt hơn.',
                            style: TextStyle(fontSize: 10.5, color: AppTheme.primary, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NextTripCard extends StatelessWidget {
  final Booking booking;
  const _NextTripCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      gradient: AppTheme.gradient,
      border: null,
      padding: const EdgeInsets.all(17),
      onTap: () => Navigator.of(context).push(appRoute(BookingScreen(bookingId: booking.id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Text('CHUYẾN TIẾP THEO',
                    style: TextStyle(
                        color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
              ),
              const Spacer(),
              Text(dayLabel(booking.departureTime),
                  style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
            ],
          ),
          const SizedBox(height: 14),
          Text('${booking.originLabel.split(',').first} → ${booking.destinationLabel.split(',').first}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 13, color: Colors.white70),
              const SizedBox(width: 4),
              Text('${hhmm(booking.departureTime)} · ${booking.seats} ghế',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              const Spacer(),
              Text(money(booking.priceTotal),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              AvatarCircle(name: booking.driver.fullName, size: 26),
              const SizedBox(width: 7),
              Text(booking.driver.fullName,
                  style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600)),
              const Spacer(),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  const _BookingCard({required this.booking});

  Color get _stripe {
    if (booking.status == 'confirmed') return AppTheme.success;
    if (booking.status == 'pending_payment' || booking.status == 'pending_driver') return AppTheme.accent;
    if (booking.status == 'completed') return AppTheme.primary;
    return AppTheme.mutedLight;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.of(context).push(appRoute(BookingScreen(bookingId: booking.id))),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 74,
            decoration: BoxDecoration(color: _stripe, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusPill(status: booking.status),
                    const Spacer(),
                    Text(dayLabel(booking.departureTime),
                        style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
                  ],
                ),
                const SizedBox(height: 7),
                Text('${booking.originLabel.split(',').first} → ${booking.destinationLabel.split(',').first}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('${hhmm(booking.departureTime)} · ${booking.seats} ghế · ${money(booking.priceTotal)}',
                    style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    AvatarCircle(name: booking.driver.fullName, size: 22),
                    const SizedBox(width: 6),
                    Text(booking.driver.fullName,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (booking.status == 'confirmed')
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                            appRoute(TrackingScreen(tripId: booking.tripId))),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.near_me_rounded, size: 12, color: AppTheme.primary),
                              SizedBox(width: 3),
                              Text('Theo dõi',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primary)),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.mutedLight),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppTheme.ink : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppTheme.ink : AppTheme.line),
        ),
        child: Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppTheme.muted)),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: active ? Colors.white.withValues(alpha: 0.18) : const Color(0xFFF1F4F9),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: active ? Colors.white : AppTheme.muted)),
            ),
          ],
        ),
      ),
    );
  }
}
