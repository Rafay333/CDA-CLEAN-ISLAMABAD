import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../core/staff_access.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../hr_face/face_hr_ui.dart';

class Hr1HomeScreenManual extends StatelessWidget {
  const Hr1HomeScreenManual({super.key});

  void _openTab(BuildContext context, int index) {
    switch (index) {
      case 1:
        context.go(AppRoutes.reports);
      case 2:
        context.go(AppRoutes.profile);
      default:
        context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppStateScope.of(context).session;
    final roster = session?.can(StaffCapability.manageHr) == true;
    final attendance = session?.can(StaffCapability.markAttendance) == true;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const PageHeader(
            title: 'HR Management',
            centerTitle: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const FaceHrHero(
                  icon: Icons.photo_camera_front_rounded,
                  title: 'Manual GPS attendance',
                  subtitle:
                      'Register one photo per worker, then mark check-in and check-out with a GPS stamp.',
                ),
                const SizedBox(height: 16),
                if (roster)
                  _Card(
                    icon: Icons.photo_camera_front_outlined,
                    accent: const Color(0xFF0F766E),
                    badge: const Color(0xFFE5F6F4),
                    title: 'Register photo',
                    subtitle: 'Choose a worker, a shift, and one clear face photo.',
                    onTap: () => context.push(AppRoutes.hr1Register),
                  ),
                if (roster && attendance) const SizedBox(height: 12),
                if (attendance) ...[
                  _Card(
                    icon: Icons.location_on_outlined,
                    accent: const Color(0xFF1688D4),
                    badge: const Color(0xFFE7F4FC),
                    title: 'Attendance',
                    subtitle: 'Select a worker and take the attendance photo.',
                    onTap: () => context.push(AppRoutes.hr1Attendance),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    icon: Icons.assignment_turned_in_outlined,
                    accent: const Color(0xFF3B82F6),
                    badge: const Color(0xFFE8F1FF),
                    title: 'Attendance log',
                    subtitle: 'Check-in and check-out saved with the same GPS photo.',
                    onTap: () => context.push(AppRoutes.hr1AttendanceLog),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: 0,
        onTap: (index) => _openTab(context, index),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.accent,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final Color badge;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

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
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
