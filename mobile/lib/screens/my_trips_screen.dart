import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/ui.dart';
import 'booking_screen.dart';
import 'chat_screen.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  late Future<List<Booking>> _future;
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = AppScope.of(context).api.myBookings();
  }

  bool _matches(Booking b) {
    if (_filter == 0) return true;
    if (_filter == 1) return b.status == 'confirmed' || b.status == 'pending_payment' || b.status == 'pending_driver';
    return b.status == 'completed' || b.status.startsWith('cancelled') || b.status == 'refunded';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chuyến của tôi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatThreadsScreen())),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<Booking>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final all = snapshot.data ?? [];
          final items = all.where(_matches).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Tất cả')),
                    ButtonSegment(value: 1, label: Text('Sắp tới')),
                    ButtonSegment(value: 2, label: Text('Đã xong')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (value) => setState(() => _filter = value.first),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => setState(_load),
                  child: items.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Icon(Icons.luggage_outlined, size: 54, color: AppTheme.muted),
                            SizedBox(height: 12),
                            Center(child: Text('Chưa có chuyến nào')),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) => _BookingCard(booking: items[index]),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => BookingScreen(bookingId: booking.id),
          ));
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusPill(status: booking.status),
                  const Spacer(),
                  Text(dayLabel(booking.departureTime),
                      style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                ],
              ),
              const SizedBox(height: 8),
              Text('${booking.originLabel} → ${booking.destinationLabel}',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text('${hhmm(booking.departureTime)} · ${booking.seats} ghế · ${money(booking.priceTotal)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
              const SizedBox(height: 9),
              Row(
                children: [
                  AvatarCircle(name: booking.driver.fullName, size: 26),
                  const SizedBox(width: 7),
                  Text(booking.driver.fullName,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 18, color: AppTheme.muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
