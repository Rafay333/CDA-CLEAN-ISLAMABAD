import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Shared professional chrome for Solid Waste, Complaints, and similar modules.
class ModulePalette {
  const ModulePalette._();

  static const waste = [Color(0xFF0284C7), Color(0xFF0F766E), Color(0xFF123B5D)];
  static const wasteAccent = Color(0xFF0284C7);
  static const complaints = [Color(0xFFD97706), Color(0xFFB45309), Color(0xFF123B5D)];
  static const complaintsAccent = Color(0xFFD97706);
  static const reports = [Color(0xFF4F46E5), Color(0xFF2563EB), Color(0xFF123B5D)];
  static const reportsAccent = Color(0xFF4F46E5);
  static const profile = [Color(0xFF0F766E), Color(0xFF115E59), Color(0xFF123B5D)];
  static const profileAccent = Color(0xFF0F766E);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const panel = Color(0xFFF8FAFC);
  static const line = Color(0xFFE2E8F0);
}

class ModuleHero extends StatelessWidget {
  const ModuleHero({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.colors = ModulePalette.waste,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x33123B5D), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppType.section.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: AppType.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.45,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ModuleMenuCard extends StatelessWidget {
  const ModuleMenuCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.accent,
    required this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color accent;
  final Color badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ModulePalette.line),
            boxShadow: AppShadows.soft,
            color: AppColors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badge,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppType.section.copyWith(fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: AppType.caption.copyWith(height: 1.35)),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: badge,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.chevron_right_rounded, color: accent, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ModulePanel extends StatelessWidget {
  const ModulePanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.accent = ModulePalette.wasteAccent,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ModulePalette.line),
        boxShadow: AppShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 4,
            color: accent.withValues(alpha: 0.85),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppType.section.copyWith(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: ModulePalette.ink,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: AppType.caption.copyWith(color: ModulePalette.muted, height: 1.4),
                  ),
                ],
                const SizedBox(height: 14),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ModuleStatusChip extends StatelessWidget {
  const ModuleStatusChip({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: AppType.caption.copyWith(color: color, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class ModuleMetaCard extends StatelessWidget {
  const ModuleMetaCard({
    super.key,
    required this.rows,
    this.accent = ModulePalette.wasteAccent,
  });

  final List<(IconData, String, String)> rows;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: ModulePalette.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ModulePalette.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(rows[i].$1, size: 17, color: accent),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  child: Text(
                    rows[i].$2,
                    style: AppType.caption.copyWith(color: const Color(0xFF94A3B8)),
                  ),
                ),
                Expanded(
                  child: Text(
                    rows[i].$3,
                    style: AppType.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: ModulePalette.ink,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
