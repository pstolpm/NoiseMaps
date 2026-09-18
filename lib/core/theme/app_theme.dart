import 'package:flutter/material.dart';

import '../../models/noise_category.dart';
import '../../models/noise_level_class.dart';

class AppTheme {
  AppTheme._();

  /// Petrol / Blaugrün – Markenfarbe (auch Icon-Hintergrund und Splash).
  static const seed = Color(0xFF0F6E74);
  static const fontFamily = 'Inter';

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      chipTheme: const ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }

  /// Symbolfarbe je Geräuschklasse (Listen, Karte, Statistik).
  static Color categoryColor(NoiseCategory c) => switch (c) {
        NoiseCategory.traffic => const Color(0xFFD64545),
        NoiseCategory.construction => const Color(0xFFE38A1D),
        NoiseCategory.people => const Color(0xFF7B4FBF),
        NoiseCategory.nature => const Color(0xFF3A9D5D),
        NoiseCategory.uncertain => const Color(0xFF8A8A8A),
      };

  static IconData categoryIcon(NoiseCategory c) => switch (c) {
        NoiseCategory.traffic => Icons.directions_car,
        NoiseCategory.construction => Icons.construction,
        NoiseCategory.people => Icons.groups,
        NoiseCategory.nature => Icons.park,
        NoiseCategory.uncertain => Icons.help_outline,
      };

  /// "#rrggbb" für MapLibre-Style-Ausdrücke.
  static String toHex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static Color levelColor(NoiseLevelClass l) => switch (l) {
        NoiseLevelClass.quiet => const Color(0xFF3A9D5D),
        NoiseLevelClass.moderate => const Color(0xFFC9B21E),
        NoiseLevelClass.loud => const Color(0xFFE38A1D),
        NoiseLevelClass.veryLoud => const Color(0xFFD64545),
      };
}
