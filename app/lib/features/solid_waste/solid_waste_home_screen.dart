import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class SolidWasteHomeScreen extends StatelessWidget {
  const SolidWasteHomeScreen({super.key});

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
      backgroundColor: const Color(0xFFF3F7FB),
      body: Column(
        children: [
          const PageHeader(title: 'Solid Waste Management', centerTitle: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _WasteCard(
                  icon: Icons.map_outlined,
                  accent: const Color(0xFF3B82F6),
                  badge: const Color(0xFFE8F1FF),
                  wash: const Color(0xFFD9E8FF),
                  title: 'Primary Sites',
                  subtitle: 'Manage primary waste sites',
                  onTap: () => context.push(AppRoutes.primarySite),
                ),
                const SizedBox(height: 14),
                _WasteCard(
                  icon: Icons.local_shipping_outlined,
                  accent: const Color(0xFF14B8A6),
                  badge: const Color(0xFFE6F7F4),
                  wash: const Color(0xFFD4F3EC),
                  title: 'Transfer Stations',
                  subtitle: 'Manage transfer stations',
                  onTap: () => context.push(AppRoutes.transferStation),
                ),
                const SizedBox(height: 14),
                _WasteCard(
                  icon: Icons.show_chart_rounded,
                  accent: const Color(0xFF12C3CE),
                  badge: const Color(0xFFE4F8FA),
                  wash: const Color(0xFFD2F4F7),
                  title: 'Activity',
                  subtitle: 'Collection, sweeping and mechanical work.',
                  onTap: () => context.push(AppRoutes.wasteActivity),
                ),
                const SizedBox(height: 14),
                _WasteCard(
                  icon: Icons.sell_outlined,
                  accent: const Color(0xFF2F9E6B),
                  badge: const Color(0xFFE5F6EE),
                  wash: const Color(0xFFD7F3E6),
                  title: 'Tagging',
                  subtitle: 'Tag a container once.',
                  onTap: () => context.push(AppRoutes.wasteTagging),
                ),
                const SizedBox(height: 14),
                _WasteCard(
                  icon: Icons.delete_outline_rounded,
                  accent: const Color(0xFFF59E0B),
                  badge: const Color(0xFFFFF4E3),
                  wash: const Color(0xFFFFE8C4),
                  title: 'Bulk Waste',
                  subtitle: 'General pictorial evidence.',
                  onTap: () => context.push(AppRoutes.bulkWaste),
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

class _WasteCard extends StatelessWidget {
  const _WasteCard({
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
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF8AA0B5),
                    size: 22,
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
