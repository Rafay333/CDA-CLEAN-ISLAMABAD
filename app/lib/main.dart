import 'package:flutter/material.dart';

import 'navigation/app_router.dart';
import 'state/app_state.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CdaApp());
}

class CdaApp extends StatefulWidget {
  const CdaApp({super.key});

  @override
  State<CdaApp> createState() => _CdaAppState();
}

class _CdaAppState extends State<CdaApp> {
  final _state = AppState();
  late final _router = createAppRouter();

  @override
  void dispose() {
    _state.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: _state,
      child: MaterialApp.router(
        title: 'CDA Clean Islamabad',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        routerConfig: _router,
        builder: (context, child) {
          return ColoredBox(
            color: AppColors.canvas,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ColoredBox(
                  color: AppColors.background,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
