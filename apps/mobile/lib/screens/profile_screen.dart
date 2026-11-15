import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../widgets/app_ui.dart';
import '../widgets/ui.dart';
import 'chat_screen.dart';
import 'earnings_screen.dart';
import 'notifications_screen.dart';
import 'recurring_trips_screen.dart';
import 'tip_account_screen.dart';
import 'tips_received_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('ChÆ°a Ä‘Äƒng nháº­p')));
    }
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, top + 14, 20, 46),
            decoration: const BoxDecoration(
              gradient: AppTheme.gradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('TÃ i khoáº£n',
                        style: TextStyle(
                            color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user_rounded, color: Colors.white, size: 13),
                          const SizedBox(width: 4),
                          Text(user.verifiedLevel >= 2 ? 'ÄÃ£ xÃ¡c thá»±c' : 'CÆ¡ báº£n',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
                        gradient: const LinearGradient(colors: [Color(0xFF7C9BFF), Color(0xFF2F5BE0)]),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.fullName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3)),
                          const SizedBox(height: 3),
                          Text(user.phone,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7), fontSize: 11.5)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFFFC46B), size: 14),
                              const SizedBox(width: 3),
                              Text(
                                '${user.ratingAvg.toStringAsFixed(1)} Â· ${user.ratingCount} Ä‘Ã¡nh giÃ¡',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8), fontSize: 10),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          showInfo(context, 'Chá»©c nÄƒng chá»‰nh sá»­a há»“ sÆ¡ sáº½ má»Ÿ trong báº£n cáº­p nháº­t'),
                      icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -30),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppCard(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    _Stat(value: 'â˜… ${user.ratingAvg.toStringAsFixed(1)}', label: 'ÄÃ¡nh giÃ¡'),
                    const _StatDivider(),
                    _Stat(value: '${user.ratingCount}', label: 'Chuyáº¿n Ä‘i'),
                    const _StatDivider(),
                    _Stat(
                        value: 'Cáº¥p ${user.verifiedLevel}',
                        label: 'XÃ¡c thá»±c'),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Group(
                  title: 'Hoáº¡t Ä‘á»™ng',
                  children: [
                    _MenuTile(
                      icon: Icons.account_balance_wallet_rounded,
                      color: AppTheme.success,
                      background: AppTheme.successSoft,
                      title: 'Thu nháº­p',
                      subtitle: 'Chuyáº¿n Ä‘i vÃ  Daily',
                      onTap: () => Navigator.of(context).push(appRoute(const EarningsScreen())),
                    ),
                    _MenuTile(
                      icon: Icons.qr_code_2_rounded,
                      color: const Color(0xFFB42318),
                      background: const Color(0xFFFFE4E0),
                      title: 'Nháº­n tip',
                      subtitle: 'CÃ i tÃ i khoáº£n vÃ  QR nháº­n tip',
                      onTap: () =>
                          Navigator.of(context).push(appRoute(const TipAccountScreen())),
                    ),
                    _MenuTile(
                      icon: Icons.favorite_rounded,
                      color: const Color(0xFFE04B3A),
                      background: const Color(0xFFFFF0EC),
                      title: 'Tip Ä‘Ã£ nháº­n',
                      subtitle: 'XÃ¡c nháº­n tip chuyá»ƒn khoáº£n',
                      onTap: () =>
                          Navigator.of(context).push(appRoute(const TipsReceivedScreen())),
                    ),
                    _MenuTile(
                      icon: Icons.chat_bubble_rounded,
                      color: const Color(0xFF0B7A75),
                      background: const Color(0xFFE6F7F5),
                      title: 'Tin nháº¯n',
                      subtitle: 'Trao Ä‘á»•i vá»›i tÃ i xáº¿ hoáº·c khÃ¡ch',
                      onTap: () =>
                          Navigator.of(context).push(appRoute(const ChatThreadsScreen())),
                    ),
                    _MenuTile(
                      icon: Icons.event_repeat_rounded,
                      color: AppTheme.primary,
                      background: AppTheme.primarySoft,
                      title: 'Chuyáº¿n Ä‘á»‹nh ká»³',
                      subtitle: 'Lá»‹ch cháº¡y tá»± Ä‘á»™ng háº±ng tuáº§n',
                      onTap: () =>
                          Navigator.of(context).push(appRoute(const RecurringTripsScreen())),
                    ),
                    _MenuTile(
                      icon: Icons.directions_car_rounded,
                      color: const Color(0xFFB45309),
                      background: const Color(0xFFFFF3E0),
                      title: 'Xe cá»§a tÃ´i',
                      subtitle: 'Quáº£n lÃ½ xe vÃ  biá»ƒn sá»‘',
                      onTap: () => showInfo(context, 'Xem xe trong tab ÄÄƒng chuyáº¿n'),
                    ),
                  ],
                ),
                _Group(
                  title: 'TÃ i khoáº£n',
                  children: [
                    _MenuTile(
                      icon: Icons.verified_user_rounded,
                      color: const Color(0xFF7C3AED),
                      background: const Color(0xFFF3E8FF),
                      title: 'XÃ¡c minh danh tÃ­nh',
                      subtitle: 'Cáº¥p ${user.verifiedLevel}/3 Â· CCCD, GPLX',
                      onTap: () =>
                          showInfo(context, 'Chá»©c nÄƒng xÃ¡c minh sáº½ má»Ÿ trong báº£n cáº­p nháº­t'),
                    ),
                    _MenuTile(
                      icon: Icons.notifications_rounded,
                      color: AppTheme.primary,
                      background: AppTheme.primarySoft,
                      title: 'ThÃ´ng bÃ¡o',
                      subtitle: 'Cáº­p nháº­t chuyáº¿n Ä‘i vÃ  Æ°u Ä‘Ã£i',
                      onTap: () =>
                          Navigator.of(context).push(appRoute(const NotificationsScreen())),
                    ),
                    _MenuTile(
                      icon: Icons.support_agent_rounded,
                      color: AppTheme.success,
                      background: AppTheme.successSoft,
                      title: 'Trá»£ giÃºp',
                      subtitle: 'support@sharee.vn',
                      onTap: () => showInfo(context, 'Há»— trá»£: support@sharee.vn'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppCard(
                  padding: const EdgeInsets.all(13),
                  shadow: false,
                  child: Row(
                    children: [
                      const Icon(Icons.dns_rounded, size: 16, color: AppTheme.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Káº¿t ná»‘i API',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                            Text(Api.baseUrl,
                                style: const TextStyle(fontSize: 9.5, color: AppTheme.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: state.signOut,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('ÄÄƒng xuáº¥t'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: const BorderSide(color: Color(0xFFF6C9CB)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text('Sharee 1.0.0 Â· made for learning',
                      style: TextStyle(fontSize: 9.5, color: AppTheme.mutedLight)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 1),
          Text(label, style: const TextStyle(fontSize: 9.5, color: AppTheme.muted)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 26, color: AppTheme.line);
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Group({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.muted)),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Padding(
                  padding: EdgeInsets.only(left: 62),
                  child: Divider(height: 1),
                ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 1),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.mutedLight),
          ],
        ),
      ),
    );
  }
}
