import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import 'waste_catalog.dart';

class SolidWasteHomeScreen extends StatefulWidget {
  const SolidWasteHomeScreen({super.key});

  @override
  State<SolidWasteHomeScreen> createState() => _SolidWasteHomeScreenState();
}

class _SolidWasteHomeScreenState extends State<SolidWasteHomeScreen> {
  @override
  void initState() {
    super.initState();
    WasteCatalog.ensureLoaded(cnic: AppStateScope.read(context).session?.cnic);
  }

  void _openTab(int index) {
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
          const PageHeader(title: 'Solid Waste Management', centerTitle: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const ModuleHero(
                  icon: Icons.delete_outline_rounded,
                  title: 'Solid waste field work',
                  subtitle:
                      'Record daily activity with before/after photos, or tag containers with live GPS.',
                  colors: ModulePalette.waste,
                ),
                const SizedBox(height: 16),
                ModuleMenuCard(
                  icon: Icons.show_chart_rounded,
                  accent: const Color(0xFF0284C7),
                  badge: const Color(0xFFE0F2FE),
                  title: 'Activity',
                  subtitle: 'Before / after photos with zone, container and GPS.',
                  onTap: () => context.push(AppRoutes.wasteActivity),
                ),
                const SizedBox(height: 12),
                ModuleMenuCard(
                  icon: Icons.sell_outlined,
                  accent: const Color(0xFF0F766E),
                  badge: const Color(0xFFE5F6F4),
                  title: 'Tagging',
                  subtitle: 'Zone → site → container type → GPS + photo.',
                  onTap: () => context.push(AppRoutes.wasteTagging),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: 0,
        onTap: (index) => _openTab(index),
      ),
    );
  }
}
