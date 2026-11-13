import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/format.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? color;
  final Border? border;
  final double radius;
  final bool shadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.gradient,
    this.color,
    this.border,
    this.radius = 20,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? Colors.white) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: border ?? (gradient == null ? Border.all(color: AppTheme.line) : null),
        boxShadow: shadow ? AppTheme.softShadow : null,
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const SectionHeader(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.only(top: 22, bottom: 10),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary)),
            ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Gradient? gradient;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: gradient ?? const LinearGradient(colors: [Color(0xFF1F63F0), Color(0xFF1149D6)]),
        boxShadow: AppTheme.liftedShadow,
      ),
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(54),
        ),
        child: loading
            ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? background;
  final IconData? icon;

  const Pill(this.text, {super.key, this.color, this.background, this.icon});

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppTheme.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? const Color(0xFFF1F4F9),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(text, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: fg)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(color: AppTheme.primarySoft, shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppTheme.muted, height: 1.5)),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: 220,
                child: OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RouteLine extends StatelessWidget {
  final String from;
  final String to;
  final String? fromTime;
  final String? toTime;

  const RouteLine({super.key, required this.from, required this.to, this.fromTime, this.toTime});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.success, width: 2.5),
                color: Colors.white,
              ),
            ),
            Container(
              width: 2,
              height: 26,
              margin: const EdgeInsets.symmetric(vertical: 3),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0FA968), Color(0xFFFF9F1C)],
                ),
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.accent, width: 2.5),
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(from,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                  if (fromTime != null)
                    Text(fromTime!,
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.muted, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(to,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                  if (toTime != null)
                    Text(toTime!,
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.muted, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class Skeleton extends StatefulWidget {
  final double height;
  final double width;
  final double radius;

  const Skeleton({super.key, this.height = 16, this.width = double.infinity, this.radius = 10});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          color: Color.lerp(const Color(0xFFEDF1F7), const Color(0xFFF7F9FC), _controller.value),
        ),
      ),
    );
  }
}

class TripSkeleton extends StatelessWidget {
  const TripSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Skeleton(width: 74, height: 22),
              SizedBox(width: 10),
              Skeleton(width: 22, height: 14),
              SizedBox(width: 10),
              Skeleton(width: 74, height: 22),
              Spacer(),
              Skeleton(width: 70, height: 22),
            ],
          ),
          SizedBox(height: 14),
          Skeleton(width: 220, height: 12),
          SizedBox(height: 14),
          Row(
            children: [
              Skeleton(width: 30, height: 30, radius: 15),
              SizedBox(width: 8),
              Expanded(child: Skeleton(height: 12)),
              SizedBox(width: 30),
            ],
          ),
        ],
      ),
    );
  }
}

Route<void> appRoute(Widget page) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondary) => page,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

Future<T?> showAppSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: child,
      ),
    ),
  );
}

String priceText(int value) => money(value);
