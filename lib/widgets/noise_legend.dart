import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/noise_category.dart';

/// Kompakte Legende der Geräuschklassen (Karten-Overlay).
class NoiseLegend extends StatelessWidget {
  const NoiseLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in NoiseCategory.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.categoryColor(c),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(c.label, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
