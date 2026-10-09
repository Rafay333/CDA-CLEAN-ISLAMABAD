import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class HrHomeScreen extends StatelessWidget {
  const HrHomeScreen({super.key});

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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const PageHeader(title: 'HR Management', centerTitle: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _HrCard(
                  icon: Icons.groups_outlined,
                  accent: const Color(0xFF2F9E6B),
                  badge: const Color(0xFFE5F6EE),
                  wash: const Color(0xFFD7F3E6),
                  title: 'Worker Management',
                  subtitle: 'Choose an employee and register their face.',
                  onTap: () => context.push(AppRoutes.workerRegistration),
                ),
                const SizedBox(height: 14),
                _HrCard(
                  icon: Icons.center_focus_strong_outlined,
                  accent: const Color(0xFF12C3CE),
                  badge: const Color(0xFFE4F8FA),
                  wash: const Color(0xFFD2F4F7),
                  title: 'Attendance',
                  subtitle: 'Match a face and record check-in or check-out.',
                  onTap: () => context.push(AppRoutes.attendance),
                ),
                const SizedBox(height: 14),
                _HrCard(
                  icon: Icons.assignment_turned_in_outlined,
                  accent: const Color(0xFF3B82F6),
                  badge: const Color(0xFFE8F1FF),
                  wash: const Color(0xFFD9E8FF),
                  title: 'Attendance Log',
                  subtitle: 'Search attendance saved for each day.',
                  onTap: () => context.push(AppRoutes.attendanceLog),
                ),
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

class _HrCard extends StatelessWidget {
  const _HrCard({
    required this.icon,
    required this.accent,
    required this.badge,
    required this.wash,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final Color badge;
  final Color wash;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1012304A),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE3EDF3)),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.white, AppColors.white, wash],
                stops: const [0, 0.55, 1],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: badge,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: accent, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppType.section.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF12304A),
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: AppType.caption.copyWith(
                            fontSize: 13,
                            height: 1.35,
                            color: const Color(0xFF60758F),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
