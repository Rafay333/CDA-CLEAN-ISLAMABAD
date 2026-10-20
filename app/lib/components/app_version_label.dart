import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme/app_typography.dart';

class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({super.key, this.onDark = false});

  final bool onDark;

  static final Future<String> _label = _read();

  static Future<String> _read() async {
    final info = await PackageInfo.fromPlatform();
    final build = info.buildNumber.trim();
    if (build.isEmpty) return 'Version: ${info.version}';
    return 'Version: ${info.version} ($build)';
  }

  @override
  Widget build(BuildContext context) {
    final style = onDark
        ? AppType.caption.copyWith(color: const Color(0xE6FFFFFF), fontSize: 10, height: 1)
        : AppType.caption.copyWith(fontSize: 12.5);
    return FutureBuilder<String>(
      future: _label,
      builder: (context, snapshot) {
        final text = snapshot.data;
        if (text == null || text.isEmpty) return const SizedBox.shrink();
        return Text(text, textAlign: TextAlign.center, style: style);
      },
    );
  }
}
