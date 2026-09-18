import 'package:flutter/material.dart';

import '../../models/noise_category.dart';
import '../../models/noise_level_class.dart';

class AppTheme {
  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1E5AA8),
        brightness: Brightness.light,
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1E5AA8),
        brightness: Brightness.dark,
      );

  /// Symbolfarbe je Geräuschklasse (auch später für die Karte).
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

  static Color levelColor(NoiseLevelClass l) => switch (l) {
        NoiseLevelClass.quiet => const Color(0xFF3A9D5D),
        NoiseLevelClass.moderate => const Color(0xFFC9B21E),
        NoiseLevelClass.loud => const Color(0xFFE38A1D),
        NoiseLevelClass.veryLoud => const Color(0xFFD64545),
      };
}
