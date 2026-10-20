import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_assets.dart';
import '../../constants/app_routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_typography.dart';
import '../profile/profile_screen.dart';
import 'sync_sheet.dart';
import 'today_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _todayKey = GlobalKey<TodayCardState>();
  var _refreshing = false;

  Future<void> _refreshPage() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await Future.wait([
        _todayKey.currentState?.reload() ?? Future.value(),
        AppStateScope.read(context).refreshAccount(),
      ]);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final pendingSync = state.pendingSyncCount;
    return Scaffold(
      backgroundColor: _HomePalette.background,
      body: Column(
        children: [
          AppHeader(
            pendingSync: pendingSync,
            unreadNotices: state.unreadNotices,
            refreshing: _refreshing,
            onSync: () => showSyncSheet(context),
            onRefresh: _refreshPage,
            onNotifications: () => context.push(AppRoutes.notifications),
            onLogout: () => confirmSignOut(context),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = constraints.maxWidth - 32;
                final bannerHeight = (contentWidth * 9 / 16).clamp(168.0, 214.0);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    _HeroBanner(height: bannerHeight),
                    const SizedBox(height: 14),
                    TodayCard(key: _todayKey),
                    const SizedBox(height: 20),
                    Text(
                      'Modules',
                      style: AppType.section.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _HomePalette.navy,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ModuleCard(
                      icon: Icons.groups_outlined,
                      accent: _HomePalette.hr,
                      tint: const Color(0xFFDDF3EC),
                      iconBackground: const Color(0xFFE6F6F1),
                      title: 'HR Management',
                      subtitle: 'Manage workers, attendance and daily logs.',
                      onTap: () => context.push(AppRoutes.hr1),
                    ),
                    const SizedBox(height: 12),
                    _ModuleCard(
                      icon: Icons.delete_outline_rounded,
                      accent: _HomePalette.waste,
                      tint: const Color(0xFFD9EFFB),
                      iconBackground: const Color(0xFFE7F4FC),
                      title: 'Solid Waste Management',
                      subtitle: 'Daily PED pictorial evidence.',
                      onTap: () => context.push(AppRoutes.waste),
                    ),
                    const SizedBox(height: 12),
                    _ModuleCard(
                      icon: Icons.assignment_outlined,
                      accent: _HomePalette.complaints,
                      tint: const Color(0xFFFFE8C4),
                      iconBackground: const Color(0xFFFFF4E3),
                      title: 'Complaints Management',
                      subtitle: 'Review and update cleanliness complaints.',
                      onTap: () => context.push(AppRoutes.complaints),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HomePalette {
  const _HomePalette._();

  static const navy = Color(0xFF12304A);
  static const background = Color(0xFFF5F8FB);
  static const card = Color(0xFFFFFFFF);
  static const hr = Color(0xFF008A70);
  static const waste = Color(0xFF1688D4);
  static const complaints = Color(0xFFF59E0B);
  static const secondary = Color(0xFF60758F);
  static const border = Color(0xFFDCE7F0);
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2412304A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                AppAssets.rawalSunset,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                semanticLabel: 'Rawal Dam at sunset, Islamabad',
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0x59101828),
                      Color(0xCC0C1C2C),
                    ],
                    stops: [0, 0.46, 0.72, 1],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Islamabad, Pakistan',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.body.copyWith(
                              color: Colors.white.withValues(alpha: 0.94),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.icon,
    required this.accent,
    required this.tint,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final Color tint;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1012304A),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: _HomePalette.card,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _HomePalette.border),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.bottomRight,
                colors: [_HomePalette.card, _HomePalette.card, tint],
                stops: const [0, 0.58, 1],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: iconBackground,
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.section.copyWith(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: _HomePalette.navy,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: AppType.caption.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: _HomePalette.secondary,
                            height: 1.35,
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
