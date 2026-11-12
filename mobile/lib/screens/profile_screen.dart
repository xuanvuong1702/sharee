import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../widgets/ui.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      ),
      body: user == null
          ? const Center(child: Text('Chưa đăng nhập'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        AvatarCircle(name: user.fullName, size: 72),
                        const SizedBox(height: 10),
                        Text(user.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(user.phone, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _stat('★ ${user.ratingAvg.toStringAsFixed(1)}', 'Đánh giá'),
                            const SizedBox(width: 28),
                            _stat('${user.ratingCount}', 'Chuyến'),
                            const SizedBox(width: 28),
                            _stat(user.verifiedLevel >= 3 ? 'Cao' : 'Cơ bản', 'Xác thực'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.verified_user_outlined),
                        title: const Text('Xác minh danh tính', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: Text('Cấp ${user.verifiedLevel}/3 · CCCD, GPLX',
                            style: const TextStyle(fontSize: 10.5)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showInfo(context, 'Chức năng xác minh sẽ mở trong bản cập nhật'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.directions_car_outlined),
                        title: const Text('Xe của tôi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: const Text('Quản lý xe và biển số', style: TextStyle(fontSize: 10.5)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showInfo(context, 'Xem xe trong tab Đăng chuyến'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.notifications_none),
                        title: const Text('Thông báo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showInfo(context, 'Bạn sẽ nhận push khi có chuyến mới'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.support_agent),
                        title: const Text('Trợ giúp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showInfo(context, 'Hỗ trợ: support@sharee.vn'),
                      ),
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
                        const Text('Kết nối API', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(Api.baseUrl, style: const TextStyle(fontSize: 10.5, color: AppTheme.muted)),
                        const SizedBox(height: 2),
                        const Text('Đổi bằng --dart-define=API_BASE_URL=…',
                            style: TextStyle(fontSize: 9.5, color: AppTheme.muted)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: state.signOut,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Đăng xuất'),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text('Sharee 1.0.0 · made for learning',
                      style: TextStyle(fontSize: 9.5, color: AppTheme.muted)),
                ),
              ],
            ),
    );
  }

  Widget _stat(String value, String label) => Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(fontSize: 9.5, color: AppTheme.muted)),
        ],
      );
}
