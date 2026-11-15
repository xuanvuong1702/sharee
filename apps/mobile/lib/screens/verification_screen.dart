import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../widgets/app_ui.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  static const _docTypes = [
    ('id_front', 'CCCD mặt trước', Icons.badge_outlined),
    ('id_back', 'CCCD mặt sau', Icons.badge_rounded),
    ('license_front', 'GPLX mặt trước', Icons.drive_eta_rounded),
    ('license_back', 'GPLX mặt sau', Icons.drive_eta_outlined),
    ('vehicle_registration', 'Đăng ký xe', Icons.description_rounded),
    ('insurance', 'Bảo hiểm xe', Icons.shield_rounded),
    ('selfie', 'Ảnh selfie', Icons.face_rounded),
  ];

  final _legalName = TextEditingController();
  final _dob = TextEditingController();
  final _idNumber = TextEditingController();
  final _idIssued = TextEditingController();
  final _idExpiry = TextEditingController();
  final _licenseNumber = TextEditingController();
  final _licenseClass = TextEditingController();
  final _licenseExpiry = TextEditingController();
  final _registration = TextEditingController();
  final _insuranceExpiry = TextEditingController();

  VerificationInfo? _info;
  bool _loading = true;
  bool _saving = false;
  String? _uploading;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loading || _info != null) return;
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await AppScope.of(context).api.verification();
      if (!mounted) return;
      _fill(info);
      setState(() {
        _info = info;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _fill(VerificationInfo info) {
    _legalName.text = info.legalName ?? '';
    _dob.text = _date(info.dateOfBirth);
    _idNumber.text = info.idNumber ?? '';
    _idIssued.text = _date(info.idIssuedAt);
    _idExpiry.text = _date(info.idExpiry);
    _licenseNumber.text = info.licenseNumber ?? '';
    _licenseClass.text = info.licenseClass ?? '';
    _licenseExpiry.text = _date(info.licenseExpiry);
    _registration.text = info.vehicleRegistration ?? '';
    _insuranceExpiry.text = _date(info.insuranceExpiry);
  }

  static String _date(String? value) {
    if (value == null || value.isEmpty) return '';
    return value.length >= 10 ? value.substring(0, 10) : value;
  }

  String? _dateToIso(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    return parsed == null
        ? null
        : '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }

  Future<bool> _save({bool silent = false}) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final info = await AppScope.of(context).api.saveVerificationProfile(
            legalName: _legalName.text.trim(),
            dateOfBirth: _dateToIso(_dob.text),
            idNumber: _idNumber.text.trim(),
            idIssuedAt: _dateToIso(_idIssued.text),
            idExpiry: _dateToIso(_idExpiry.text),
            licenseNumber: _licenseNumber.text.trim(),
            licenseClass: _licenseClass.text.trim(),
            licenseExpiry: _dateToIso(_licenseExpiry.text),
            vehicleRegistration: _registration.text.trim(),
            insuranceExpiry: _dateToIso(_insuranceExpiry.text),
          );
      if (!mounted) return false;
      setState(() {
        _info = info;
        _saving = false;
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu thông tin xác thực')),
        );
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _saving = false;
        _error = '$e';
      });
      return false;
    }
  }

  Future<void> _upload(String type) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Chụp ảnh'),
              subtitle: Text(type == 'selfie' ? 'Chụp selfie trực tiếp' : 'Chụp giấy tờ'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() {
      _uploading = type;
      _error = null;
    });
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 2200,
      );
      if (picked == null) {
        if (mounted) setState(() => _uploading = null);
        return;
      }
      final bytes = await picked.readAsBytes();
      await AppScope.of(context).api.uploadVerificationDocument(type, bytes, picked.name);
      final info = await AppScope.of(context).api.verification();
      if (!mounted) return;
      setState(() {
        _info = info;
        _uploading = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = null;
        _error = '$e';
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _save(silent: true);
      if (!saved) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      final info = await AppScope.of(context).api.submitVerification();
      if (!mounted) return;
      setState(() {
        _info = info;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi hồ sơ, vui lòng chờ duyệt')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  void dispose() {
    for (final c in [
      _legalName, _dob, _idNumber, _idIssued, _idExpiry, _licenseNumber,
      _licenseClass, _licenseExpiry, _registration, _insuranceExpiry
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final editable = info?.canEdit ?? true;
    return Scaffold(
      appBar: AppBar(title: const Text('Xác thực tài xế')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _statusCard(info),
                const SizedBox(height: 13),
                if (editable) ...[
                  AppCard(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Thông tin pháp lý',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        const Text(
                          'Thông tin phải khớp chính xác với CCCD, GPLX và đăng ký xe.',
                          style: TextStyle(fontSize: 10.5, color: AppTheme.muted, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        _field(_legalName, 'Họ tên pháp lý'),
                        _field(_dob, 'Ngày sinh', hint: 'YYYY-MM-DD'),
                        _field(_idNumber, 'Số CCCD/CMND', keyboard: TextInputType.number),
                        _field(_idIssued, 'Ngày cấp CCCD', hint: 'YYYY-MM-DD'),
                        _field(_idExpiry, 'Ngày hết hạn CCCD', hint: 'YYYY-MM-DD'),
                        _field(_licenseNumber, 'Số GPLX'),
                        _field(_licenseClass, 'Hạng GPLX', hint: 'B2, C, D...'),
                        _field(_licenseExpiry, 'GPLX hết hạn', hint: 'YYYY-MM-DD'),
                        _field(_registration, 'Biển số / đăng ký xe'),
                        _field(_insuranceExpiry, 'Bảo hiểm xe hết hạn', hint: 'YYYY-MM-DD'),
                        const SizedBox(height: 10),
                        PrimaryButton(
                          label: _saving ? 'Đang lưu...' : 'Lưu thông tin',
                          onPressed: _saving ? null : _save,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 13),
                  AppCard(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Giấy tờ bắt buộc',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        const Text('Ảnh rõ nét, không bị mờ, không che thông tin.',
                            style: TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                        const SizedBox(height: 10),
                        for (final (type, label, icon) in _docTypes)
                          _docTile(type, label, icon, info),
                      ],
                    ),
                  ),
                  const SizedBox(height: 13),
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 11)),
                    const SizedBox(height: 8),
                  ],
                  PrimaryButton(
                    label: _saving ? 'Đang gửi...' : 'Gửi hồ sơ xác thực',
                    onPressed: _saving ? null : _submit,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hồ sơ sẽ được quản trị viên kiểm tra thủ công. Không chia sẻ giấy tờ qua kênh khác.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: AppTheme.muted, height: 1.4),
                  ),
                ],
                if (!editable && _error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 11)),
                ],
              ],
            ),
    );
  }

  Widget _statusCard(VerificationInfo? info) {
    final status = info?.status ?? 'unverified';
    final approved = status == 'approved';
    final pending = status == 'pending';
    final rejected = status == 'rejected';
    final suspended = status == 'suspended';
    final title = approved
        ? 'Đã xác thực tài xế'
        : pending
            ? 'Hồ sơ đang chờ duyệt'
            : rejected
                ? 'Hồ sơ bị từ chối'
                : suspended
                    ? 'Tài khoản tài xế bị tạm dừng'
                    : 'Chưa xác thực tài xế';
    final color = approved
        ? AppTheme.success
        : rejected || suspended
            ? AppTheme.danger
            : AppTheme.warning;
    final bg = approved
        ? AppTheme.successSoft
        : rejected || suspended
            ? const Color(0xFFFDECEC)
            : const Color(0xFFFFF3E0);
    return AppCard(
      padding: const EdgeInsets.all(16),
      color: bg,
      border: Border.all(color: color.withValues(alpha: 0.2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(approved ? Icons.verified_rounded : Icons.verified_user_outlined,
                  color: color, size: 24),
              const SizedBox(width: 9),
              Expanded(
                child: Text(title,
                    style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900)),
              ),
              Pill(status == 'approved' ? 'Cấp 3' : 'Cấp ${info?.level ?? 1}',
                  color: color, background: Colors.white.withValues(alpha: 0.55)),
            ],
          ),
          if (approved && info?.expiresAt != null) ...[
            const SizedBox(height: 7),
            Text('Hiệu lực đến ${_shortDate(info!.expiresAt!)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
          ],
          if (pending) ...[
            const SizedBox(height: 7),
            const Text('Quản trị viên đang kiểm tra giấy tờ. Bạn không thể sửa hồ sơ lúc này.',
                style: TextStyle(fontSize: 11, color: AppTheme.muted, height: 1.4)),
          ],
          if (rejected || suspended) ...[
            const SizedBox(height: 7),
            Text(info?.rejectionReason ?? 'Vui lòng liên hệ hỗ trợ.',
                style: const TextStyle(fontSize: 11.5, color: AppTheme.ink, height: 1.4)),
          ],
          if (info == null || status == 'unverified' || status == 'draft') ...[
            const SizedBox(height: 7),
            const Text('Cần CCCD, GPLX, đăng ký xe, bảo hiểm và ảnh selfie.',
                style: TextStyle(fontSize: 11, color: AppTheme.muted)),
          ],
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {String? hint, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }

  Widget _docTile(String type, String label, IconData icon, VerificationInfo? info) {
    final doc = info?.documentOf(type);
    final busy = _uploading == type;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: doc == null ? const Color(0xFFF8FAFD) : AppTheme.successSoft,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: doc == null ? AppTheme.line : const Color(0xFFBBE8D6)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: doc == null ? AppTheme.muted : AppTheme.success),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  Text(doc == null ? 'Chưa tải lên' : doc.originalName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9.5, color: AppTheme.muted)),
                ],
              ),
            ),
            TextButton(
              onPressed: busy ? null : () => _upload(type),
              child: busy
                  ? const SizedBox(
                      width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(doc == null ? 'Tải ảnh' : 'Thay ảnh',
                      style: const TextStyle(fontSize: 10.5)),
            ),
          ],
        ),
      ),
    );
  }

  String _shortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
