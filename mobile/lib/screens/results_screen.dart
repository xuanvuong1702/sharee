import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/ui.dart';
import 'trip_detail_screen.dart';

class ResultsScreen extends StatefulWidget {
  final String fromLabel;
  final String toLabel;
  final double fromLat;
  final double fromLng;
  final double toLat;
  final double toLng;
  final DateTime date;
  final int seats;

  const ResultsScreen({
    super.key,
    required this.fromLabel,
    required this.toLabel,
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
    required this.date,
    required this.seats,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late Future<List<SearchResult>> _future;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  void _load() {
    final api = AppScope.of(context).api;
    _future = api.search(
      fromLat: widget.fromLat,
      fromLng: widget.fromLng,
      toLat: widget.toLat,
      toLng: widget.toLng,
      date: DateFormat('yyyy-MM-dd').format(widget.date),
      seats: widget.seats,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.fromLabel.split(',').first} → ${widget.toLabel.split(',').first}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            Text('${dayLabel(widget.date)} · ${widget.seats} ghế',
                style: const TextStyle(fontSize: 10.5, color: AppTheme.muted, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      body: FutureBuilder<List<SearchResult>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(snapshot.error.toString(), textAlign: TextAlign.center),
              ),
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Chưa có chuyến phù hợp. Thử ngày khác hoặc đổi tuyến.'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(_load),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _TripCard(result: items[index], seats: widget.seats),
            ),
          );
        },
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final SearchResult result;
  final int seats;
  const _TripCard({required this.result, required this.seats});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TripDetailScreen(result: result, seats: seats),
        )),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(hhmm(result.departureTime),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7),
                    child: Icon(Icons.arrow_forward, size: 14, color: AppTheme.muted),
                  ),
                  Text(hhmm(result.arriveEstimate),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(money(result.pricePerSeat),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      const Text('/ ghế', style: TextStyle(fontSize: 10, color: AppTheme.muted)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('${result.pickupStop.name} → ${result.dropoffStop.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.muted)),
              const SizedBox(height: 10),
              Row(
                children: [
                  AvatarCircle(name: result.driver.fullName, size: 30),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(result.driver.fullName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        Text('★ ${result.driver.ratingAvg.toStringAsFixed(1)} · ${result.vehicle.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
                      ],
                    ),
                  ),
                  StatusPill(status: result.bookingMode == 'instant' ? 'confirmed' : 'pending_driver'),
                  const SizedBox(width: 4),
                  Text('${result.seatsAvailable} chỗ',
                      style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
