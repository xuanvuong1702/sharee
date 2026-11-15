import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/app_ui.dart';
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
  late DateTime _date;
  String _sort = 'time';
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _date = widget.date;
  }

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
      date: DateFormat('yyyy-MM-dd').format(_date),
      seats: widget.seats,
    );
  }

  void _changeDate(DateTime date) {
    setState(() {
      _date = date;
      _load();
    });
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (value != null) _changeDate(value);
  }

  List<SearchResult> _sorted(List<SearchResult> items) {
    final list = [...items];
    if (_sort == 'price') {
      list.sort((a, b) => a.pricePerSeat.compareTo(b.pricePerSeat));
    } else {
      list.sort((a, b) => a.departureTime.compareTo(b.departureTime));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final route = '${widget.fromLabel.split(',').first} → ${widget.toLabel.split(',').first}';
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(route,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            Text('${dayLabel(_date)} · ${widget.seats} ghế',
                style: const TextStyle(fontSize: 10.5, color: AppTheme.muted, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month_rounded, size: 21),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 62,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              scrollDirection: Axis.horizontal,
              itemCount: 9,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final date = DateTime.now().add(Duration(days: index));
                final active = date.year == _date.year &&
                    date.month == _date.month &&
                    date.day == _date.day;
                return _DateChip(date: date, active: active, onTap: () => _changeDate(date));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                const Text('Sắp xếp:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.muted)),
                const SizedBox(width: 8),
                _SortChip(
                    label: 'Sớm nhất',
                    active: _sort == 'time',
                    onTap: () => setState(() => _sort = 'time')),
                const SizedBox(width: 6),
                _SortChip(
                    label: 'Rẻ nhất',
                    active: _sort == 'price',
                    onTap: () => setState(() => _sort = 'price')),
                const Spacer(),
                const Icon(Icons.tune_rounded, size: 17, color: AppTheme.muted),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<SearchResult>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: 3,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, __) => const TripSkeleton(),
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
                final items = _sorted(snapshot.data ?? []);
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.route_rounded,
                    title: 'Chưa có chuyến phù hợp',
                    message: 'Thử một ngày khác hoặc đổi tuyến đường. Tài xế thường đăng chuyến trước 1–2 ngày.',
                    actionLabel: 'Chọn ngày khác',
                    onAction: _pickDate,
                  );
                }
                return RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: () async => setState(_load),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    itemCount: items.length + 2,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              Text('${items.length} chuyến phù hợp',
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 6),
                              const Pill('Giá đã gồm phí', color: AppTheme.success, background: AppTheme.successSoft),
                            ],
                          ),
                        );
                      }
                      if (index == items.length + 1) {
                        return AppCard(
                          padding: const EdgeInsets.all(14),
                          shadow: false,
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.primarySoft,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: const Icon(Icons.event_available_rounded,
                                    size: 18, color: AppTheme.primary),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Không thấy chuyến phù hợp?',
                                        style: TextStyle(
                                            fontSize: 11.5, fontWeight: FontWeight.w800)),
                                    Text('Thử một ngày khác để có thêm lựa chọn.',
                                        style: TextStyle(fontSize: 10, color: AppTheme.muted)),
                                  ],
                                ),
                              ),
                              TextButton(onPressed: _pickDate, child: const Text('Đổi ngày')),
                            ],
                          ),
                        );
                      }
                      return _TripCard(result: items[index - 1], seats: widget.seats);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final DateTime date;
  final bool active;
  final VoidCallback onTap;

  const _DateChip({required this.date, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const names = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final weekday = names[date.weekday - 1];
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 54,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: active ? AppTheme.primary : AppTheme.line),
          boxShadow: active ? AppTheme.liftedShadow : null,
        ),
        child: Column(
          children: [
            Text(weekday,
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white70 : AppTheme.muted)),
            const SizedBox(height: 2),
            Text('${date.day}',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: active ? Colors.white : AppTheme.ink)),
          ],
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SortChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.ink : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: active ? AppTheme.ink : AppTheme.line),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppTheme.muted)),
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
    return AppCard(
      onTap: () => Navigator.of(context).push(appRoute(
        TripDetailScreen(result: result, seats: seats),
      )),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hhmm(result.departureTime),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  const Text('khởi hành',
                      style: TextStyle(fontSize: 9.5, color: AppTheme.muted, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(color: AppTheme.mutedLight, shape: BoxShape.circle),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: AppTheme.line,
                        ),
                      ),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(color: AppTheme.mutedLight, shape: BoxShape.circle),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hhmm(result.arriveEstimate),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  const Text('đến nơi',
                      style: TextStyle(fontSize: 9.5, color: AppTheme.muted, fontWeight: FontWeight.w600)),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(money(result.pricePerSeat),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                  const Text('/ ghế',
                      style: TextStyle(fontSize: 9.5, color: AppTheme.muted, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.trip_origin_rounded, size: 12, color: AppTheme.success),
              const SizedBox(width: 5),
              Expanded(
                child: Text(result.pickupStop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 12, color: AppTheme.mutedLight),
              const SizedBox(width: 5),
              Expanded(
                child: Text(result.dropoffStop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 11),
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [
                    AppTheme.primary.withValues(alpha: 0.85),
                    AppTheme.primaryDark,
                  ]),
                ),
                alignment: Alignment.center,
                child: Text(
                  result.driver.fullName.isNotEmpty ? result.driver.fullName[0] : '?',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(result.driver.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, size: 13, color: AppTheme.success),
                      ],
                    ),
                    Text('★ ${result.driver.ratingAvg.toStringAsFixed(1)} · ${result.vehicle.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
                  ],
                ),
              ),
              Pill(
                result.bookingMode == 'instant' ? 'Đặt ngay' : 'Duyệt tay',
                color: result.bookingMode == 'instant' ? const Color(0xFF067647) : const Color(0xFFB45309),
                background: result.bookingMode == 'instant'
                    ? const Color(0xFFE6F8F0)
                    : const Color(0xFFFFF3E0),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: result.seatsAvailable <= 1 ? AppTheme.dangerSoft : AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${result.seatsAvailable} chỗ',
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: result.seatsAvailable <= 1 ? AppTheme.danger : AppTheme.primary)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
