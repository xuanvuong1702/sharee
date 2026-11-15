import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/app_ui.dart';

class AppealScreen extends StatefulWidget {
  final String bookingId;
  const AppealScreen({super.key, required this.bookingId});

  @override
  State<AppealScreen> createState() => _AppealScreenState();
}

class _AppealScreenState extends State<AppealScreen> {
  final _reason = TextEditingController();
  final _description = TextEditingController();
  List<AppealInfo>? _appeals;
  EscrowInfo? _escrow;
  bool _busy = false;
  String? _error;
  String? _uploading;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appeals == null) _load();
  }

  Future<void> _load() async {
    final api = AppScope.of(context).api;
    try {
      final appeals = await api.bookingAppeals(widget.bookingId);
      EscrowInfo? escrow;
      try { escrow = await api.escrow(widget.bookingId); } catch (_) {}
      if (!mounted) return;
      setState(() {
        _appeals = appeals;
        _escrow = escrow;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() { _appeals = []; _error = '$e'; });
    }
  }

  Future<void> _create() async {
    if (_reason.text.trim().length < 3 || _description.text.trim().length < 10) {
      setState(() => _error = 'Nhập lý do (≥3 ký tự) và mô tả (≥10 ký tự)');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await AppScope.of(context).api.createAppeal(widget.bookingId,
          reason: _reason.text.trim(), description: _description.text.trim());
      _reason.clear();
      _description.clear();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadEvidence(String appealId) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 2200,
    );
    if (picked == null) return;
    setState(() { _uploading = appealId; _error = null; });
    try {
      final bytes = await picked.readAsBytes();
      await AppScope.of(context).api.uploadAppealEvidence(appealId, bytes, picked.name);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appeals = _appeals;
    final open = appeals?.where((a) => a.status == 'open' || a.status == 'investigating').isNotEmpty ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Khiếu nại & escrow')),
      body: appeals == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                if (_escrow != null)
                  AppCard(
                    padding: const EdgeInsets.all(15),
                    color: _escrow!.status == 'disputed'
                        ? const Color(0xFFFFF3E0)
                        : AppTheme.primarySoft,
                    child: Row(
                      children: [
                        Icon(
                          _escrow!.status == 'disputed'
                              ? Icons.lock_clock_rounded
                              : Icons.lock_rounded,
                          color: _escrow!.status == 'disputed'
                              ? const Color(0xFFB45309)
                              : AppTheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _escrow!.method == 'cash' && _escrow!.status == 'cash_pending'
                                    ? 'Thanh toán tiền mặt khi hoàn tất'
                                    : _escrow!.status == 'disputed'
                                        ? 'Tiền đang bị khóa do khiếu nại'
                                        : 'Tiền đang được giữ trong escrow',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 2),
                              Text('${money(_escrow!.amount)} · ${_methodLabel(_escrow!.method)}',
                                  style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                if (!open) ...[
                  const Text('Mở khiếu nại',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  const Text(
                    'Khi có tranh chấp, tiền escrow bị khóa và admin xem bằng chứng của cả hai bên trước khi quyết định.',
                    style: TextStyle(fontSize: 11, color: AppTheme.muted, height: 1.45),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _reason,
                    decoration: const InputDecoration(labelText: 'Lý do', hintText: 'Ví dụ: Tài xế không đến đúng giờ'),
                  ),
                  const SizedBox(height: 9),
                  TextField(
                    controller: _description,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: 'Mô tả chi tiết', hintText: 'Thời gian, địa điểm, sự việc...'),
                  ),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: _busy ? 'Đang gửi...' : 'Mở khiếu nại',
                    onPressed: _busy ? null : _create,
                  ),
                ],
                if (appeals.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...appeals.map(_appealCard),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 11)),
                ],
                if (open) ...[
                  const SizedBox(height: 10),
                  const Text('Bạn có thể tải thêm bằng chứng cho khiếu nại đang mở.',
                      style: TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                ],
              ],
            ),
    );
  }

  Widget _appealCard(AppealInfo appeal) {
    final active = appeal.status == 'open' || appeal.status == 'investigating';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(appeal.reason,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900))),
                Pill(_statusLabel(appeal.status),
                    color: active ? const Color(0xFFB45309) : AppTheme.success,
                    background: active ? const Color(0xFFFFF3E0) : AppTheme.successSoft),
              ],
            ),
            const SizedBox(height: 5),
            Text(appeal.description, style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
            const SizedBox(height: 4),
            Text('Mở bởi ${appeal.openedByName} · ${_date(appeal.createdAt)}',
                style: const TextStyle(fontSize: 9.5, color: AppTheme.muted)),
            if (appeal.resolutionNote != null) ...[
              const SizedBox(height: 6),
              Text('Xử lý: ${appeal.resolutionNote}',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
            ],
            if (appeal.evidence.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text('Bằng chứng (${appeal.evidence.length})',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
              for (final e in appeal.evidence)
                Text('• ${e.originalName} · ${e.uploaderName}',
                    style: const TextStyle(fontSize: 9.5, color: AppTheme.muted)),
            ],
            if (active) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: _uploading == appeal.id ? null : () => _uploadEvidence(appeal.id),
                icon: _uploading == appeal.id
                    ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.attach_file_rounded, size: 16),
                label: const Text('Tải bằng chứng', style: TextStyle(fontSize: 10.5)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _methodLabel(String method) => switch (method) {
        'cash' => 'Tiền mặt',
        'wallet' => 'Ví điện tử',
        'bank' => 'Ngân hàng',
        _ => method,
      };

  String _statusLabel(String status) => switch (status) {
        'open' => 'Đang mở',
        'investigating' => 'Đang điều tra',
        'resolved' => 'Đã xử lý',
        'rejected' => 'Bị từ chối',
        'cancelled' => 'Đã hủy',
        _ => status,
      };

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
