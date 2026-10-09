import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'identity.dart';

const _homeHeaderGradient = LinearGradient(
  colors: [Color(0xFF00695C), Color(0xFF0A4A62), Color(0xFF12304A)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class AppHeader extends StatelessWidget {
  const AppHeader({super.key, this.onNotifications, this.onProfile});

  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        decoration: const BoxDecoration(gradient: _homeHeaderGradient),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const _LogoChip(),
                  const Spacer(),
                  IconActionButton(
                    icon: Icons.notifications_none_rounded,
                    tooltip: 'Notifications',
                    onPressed: onNotifications,
                    light: true,
                  ),
                  const SizedBox(width: 8),
                  AppAvatar(size: 36, onTap: onProfile),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.actions,
    this.showBack = true,
    this.centerTitle = false,
  });

  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    final canPop = showBack && context.canPop();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        decoration: const BoxDecoration(gradient: AppGradients.header),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (centerTitle)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 52),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppType.section.copyWith(
                          color: AppColors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      if (canPop)
                        IconActionButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          tooltip: 'Back',
                          light: true,
                          onPressed: () => context.pop(),
                        )
                      else
                        const SizedBox(width: 8),
                      if (!centerTitle)
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.section.copyWith(
                              color: AppColors.white,
                              fontSize: 18,
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      ...?actions,
                      const SizedBox(width: 8),
                    ],
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

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.body,
    this.bottom,
    this.actions,
    this.showBack = true,
  });

  final String title;
  final Widget body;
  final Widget? bottom;
  final List<Widget>? actions;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(title: title, actions: actions, showBack: showBack),
          Expanded(child: body),
          if (bottom != null)
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: bottom!,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LogoChip extends StatelessWidget {
  const _LogoChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(AppAssets.logo, height: 22, fit: BoxFit.contain),
          const SizedBox(height: 2),
          Text(
            'Clean Islamabad',
            style: AppType.caption.copyWith(
              color: AppColors.emerald,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class IconActionButton extends StatelessWidget {
  const IconActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.light = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final color = light ? AppColors.white : AppColors.navy;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: light
            ? Colors.white.withValues(alpha: 0.14)
            : AppColors.background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}
