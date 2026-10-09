import 'package:flutter/material.dart';

import '../constants/app_copy.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/display_format.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, this.name, this.size = 44, this.onTap});

  final String? name;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    final child = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.sky.withValues(alpha: 0.7),
          width: 1.4,
        ),
      ),
      child: initials.isEmpty
          ? Icon(
              Icons.person_outline_rounded,
              color: AppColors.navy,
              size: size * 0.5,
            )
          : Text(
              initials,
              style: AppType.button.copyWith(
                color: AppColors.navy,
                fontSize: size * 0.32,
              ),
            ),
    );
    if (onTap == null) return child;
    return Semantics(
      button: true,
      label: 'Profile details',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: child,
        ),
      ),
    );
  }

  String _initials(String? value) {
    final parts = (value ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
}

class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.name,
    this.subtitle,
    this.onAvatarTap,
  });

  final String name;
  final String? subtitle;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          AppAvatar(name: name, size: 64, onTap: onAvatarTap),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayOr(name, AppCopy.roleLabel),
                  style: AppType.section.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(subtitle ?? AppCopy.roleLabel, style: AppType.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MapContainer extends StatelessWidget {
  const MapContainer({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 280,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD7E6EA), Color(0xFFC9D7C8), Color(0xFFE7EEF2)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _MapGridPainter()),
            ),
            Center(child: child ?? const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x33203A4A)
      ..strokeWidth = 1;
    const gap = 28.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Timeline extends StatelessWidget {
  const Timeline({
    super.key,
    required this.events,
    this.emptyLabel = 'No activity yet',
  });

  final List<TimelineEvent> events;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Text(emptyLabel, style: AppType.caption);
    }
    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          _Row(event: events[i], last: i == events.length - 1),
      ],
    );
  }
}

class TimelineEvent {
  const TimelineEvent({
    required this.title,
    required this.timeLabel,
    required this.color,
  });

  final String title;
  final String timeLabel;
  final Color color;
}

class _Row extends StatelessWidget {
  const _Row({required this.event, required this.last});

  final TimelineEvent event;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: event.color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 1.4, color: AppColors.border),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: AppType.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(event.timeLabel, style: AppType.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScanFrame extends StatelessWidget {
  const ScanFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      decoration: BoxDecoration(
        color: const Color(0xFF102433),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: CustomPaint(
          painter: _CornersPainter(),
          child: Padding(padding: const EdgeInsets.all(28), child: child),
        ),
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.lime
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const length = 28.0;
    const inset = 16.0;
    final path = Path()
      ..moveTo(inset, inset + length)
      ..lineTo(inset, inset)
      ..lineTo(inset + length, inset)
      ..moveTo(size.width - inset - length, inset)
      ..lineTo(size.width - inset, inset)
      ..lineTo(size.width - inset, inset + length)
      ..moveTo(inset, size.height - inset - length)
      ..lineTo(inset, size.height - inset)
      ..lineTo(inset + length, size.height - inset)
      ..moveTo(size.width - inset - length, size.height - inset)
      ..lineTo(size.width - inset, size.height - inset)
      ..lineTo(size.width - inset, size.height - inset - length);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
