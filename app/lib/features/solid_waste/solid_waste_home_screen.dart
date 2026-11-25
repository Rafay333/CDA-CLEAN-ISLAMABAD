import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../core/staff_access.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final message = AppStateScope.read(context).takeFlashNotice();
      if (message == null || message.isEmpty) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
    });
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
    final session = AppStateScope.of(context).session;
    final containers = session?.can(StaffCapability.serveContainers) == true;
    final otherRecords = session?.canUseOtherFieldRecords == true;
    final cards = <Widget>[
      if (containers || otherRecords)
        ModuleMenuCard(
          icon: Icons.show_chart_rounded,
          accent: const Color(0xFF0284C7),
          badge: const Color(0xFFE0F2FE),
          title: 'Activity',
          subtitle: otherRecords
              ? 'Before / after photos with zone, container and GPS.'
              : 'Container clearance with before / after photos and GPS.',
          onTap: () => context.push(AppRoutes.wasteActivity),
        ),
      if (otherRecords)
        ModuleMenuCard(
          icon: Icons.sell_outlined,
          accent: const Color(0xFF0F766E),
          badge: const Color(0xFFE5F6F4),
          title: 'Tagging',
          subtitle: 'Zone → site → container type → GPS + photo.',
          onTap: () => context.push(AppRoutes.wasteTagging),
        ),
    ];
    final subtitle = otherRecords
        ? 'Record daily activity with before/after photos, or tag containers with live GPS.'
        : 'Record container clearance with before and after photos.';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const PageHeader(title: 'Solid Waste Management', centerTitle: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                ModuleHero(
                  icon: Icons.delete_outline_rounded,
                  title: 'Solid waste field work',
                  subtitle: subtitle,
                  colors: ModulePalette.waste,
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  cards[i],
                ],
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
