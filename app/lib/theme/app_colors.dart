import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const emerald = Color(0xFF087F5B);
  static const forest = Color(0xFF075E54);
  static const teal = Color(0xFF0F766E);
  static const navy = Color(0xFF123B5D);
  static const lime = Color(0xFF84CC16);
  static const sky = Color(0xFF38BDF8);

  static const background = Color(0xFFF5F7F8);
  static const white = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF17324D);
  static const textSecondary = Color(0xFF64748B);
  static const border = Color(0xFFD9E2E7);

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFDC2626);
  static const info = Color(0xFF0284C7);

  static const disabled = Color(0xFFE7EEF1);
  static const disabledText = Color(0xFF94A3B8);
  static const canvas = Color(0xFF0E2433);
}

class AppGradients {
  const AppGradients._();

  static const primary = LinearGradient(
    colors: [AppColors.emerald, AppColors.teal],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const header = LinearGradient(
    colors: [AppColors.forest, Color(0xFF0A4C55), AppColors.navy],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const photoScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x140E2433), Color(0xCC123B5D)],
  );

  static const loginScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x40123B5D), Color(0x80123B5D), Color(0xE6075E54)],
    stops: [0, 0.42, 1],
  );
}

class AppShadows {
  const AppShadows._();

  static const card = [
    BoxShadow(color: Color(0x1217324D), blurRadius: 18, offset: Offset(0, 8)),
  ];

  static const soft = [
    BoxShadow(color: Color(0x0F17324D), blurRadius: 10, offset: Offset(0, 4)),
  ];
}

class AppRadius {
  const AppRadius._();

  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 18.0;
}

class AppSpacing {
  const AppSpacing._();

  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}
