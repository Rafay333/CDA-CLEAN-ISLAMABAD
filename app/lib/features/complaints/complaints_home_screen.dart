import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../theme/app_colors.dart';

class ComplaintsHomeScreen extends StatelessWidget {
  const ComplaintsHomeScreen({super.key});

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
          const PageHeader(title: 'Complaints', centerTitle: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const ModuleHero(
                  icon: Icons.report_gmailerrorred_rounded,
                  title: 'Cleanliness complaints',
                  subtitle:
                      'View the map, work open cases, or submit a new SupervisorApp complaint.',
                  colors: ModulePalette.complaints,
                ),
                const SizedBox(height: 16),
                ModuleMenuCard(
                  icon: Icons.map_rounded,
                  accent: const Color(0xFF2563EB),
                  badge: const Color(0xFFE8F1FF),
                  title: 'View Complaints',
                  subtitle: 'Map of union councils and complaint pins.',
                  onTap: () => context.push(AppRoutes.complaintMap),
                ),
                const SizedBox(height: 12),
                ModuleMenuCard(
                  icon: Icons.pending_actions_outlined,
                  accent: const Color(0xFF0F766E),
                  badge: const Color(0xFFE5F6F4),
                  title: 'Open complaints',
                  subtitle: 'Pending and in-processing cases to action.',
                  onTap: () => context.push(AppRoutes.openComplaints),
                ),
                const SizedBox(height: 12),
                ModuleMenuCard(
                  icon: Icons.add_comment_outlined,
                  accent: const Color(0xFFD97706),
                  badge: const Color(0xFFFFF4E5),
                  title: 'Submit complaint',
                  subtitle: 'Create a new complaint with photos and GPS.',
                  onTap: () => context.push(AppRoutes.submitComplaint),
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
