import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CdaColors {
  static const green = Color(0xFF0B6E4F);
  static const greenDark = Color(0xFF084C37);
  static const bg = Color(0xFFF4F7F5);
  static const danger = Color(0xFFB42318);
  static const warning = Color(0xFFB54708);
  static const ink = Color(0xFF1B2421);
}

Color statusColor(String status) {
  return switch (status) {
    'submitted' => const Color(0xFF475569),
    'accepted' => const Color(0xFF1D4ED8),
    'assigned' => const Color(0xFF4338CA),
    'in_progress' => CdaColors.warning,
    'resolved' => CdaColors.green,
    'reopened' => CdaColors.warning,
    'rejected' || 'duplicate' => CdaColors.danger,
    _ => const Color(0xFF667085),
  };
}

String statusLabel(String status) {
  return switch (status) {
    'submitted' => 'Submitted',
    'accepted' => 'Accepted',
    'assigned' => 'Assigned',
    'in_progress' => 'In progress',
    'resolved' => 'Resolved',
    'closed' => 'Closed',
    'rejected' => 'Rejected',
    'duplicate' => 'Duplicate',
    'reopened' => 'Reopened',
    _ => status,
  };
}

ThemeData cdaTheme(String lang) {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: CdaColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: CdaColors.green,
      primary: CdaColors.green,
      surface: CdaColors.bg,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: CdaColors.green,
      foregroundColor: Colors.white,
      centerTitle: false,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: CdaColors.green.withValues(alpha: 0.16),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CdaColors.green,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
  final family =
      (lang == 'ur' ? GoogleFonts.notoNaskhArabic() : GoogleFonts.outfit())
          .fontFamily;
  return base.copyWith(textTheme: base.textTheme.apply(fontFamily: family));
}
