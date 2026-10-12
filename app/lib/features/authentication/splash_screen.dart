import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_assets.dart';
import '../../constants/app_routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _progress;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: const Duration(seconds: 5));
    _progress.addStatusListener((status) async {
      if (status != AnimationStatus.completed || !mounted) return;
      await AppStateScope.read(context).ready;
      if (!mounted) return;
      final signedIn = AppStateScope.read(context).session != null;
      context.go(signedIn ? AppRoutes.home : AppRoutes.login);
    });
    _progress.forward();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.forest,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              AppAssets.splash,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              semanticLabel: 'Clean Islamabad',
              errorBuilder: (context, error, stackTrace) => const ColoredBox(color: AppColors.forest),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Center(
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width * 0.38,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedBuilder(
                          animation: _progress,
                          builder: (context, _) {
                            return LinearProgressIndicator(
                              value: _progress.value,
                              minHeight: 4,
                              backgroundColor: Colors.white.withValues(alpha: 0.28),
                              color: AppColors.lime,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
