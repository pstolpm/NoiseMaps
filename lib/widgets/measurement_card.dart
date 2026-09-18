import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/noise_measurement.dart';

/// Kompakte Darstellung einer Messung für Listen (Home, Karte-Platzhalter).
class MeasurementCard extends StatelessWidget {
  const MeasurementCard({super.key, required this.measurement, this.onTap});

  final NoiseMeasurement measurement;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final m = measurement;
    final cat = m.effectiveCategory;
    final t = m.timestamp;
    final time =
        '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}. '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppTheme.categoryColor(cat),
          foregroundColor: Colors.white,
          child: Icon(AppTheme.categoryIcon(cat)),
        ),
        title: Text('${m.soundLevel.toStringAsFixed(1)} dB · ${m.levelClass.label}'),
        subtitle: Text(
          '${cat.label} · ${(m.aiConfidence * 100).round()} %'
          '${m.isUserCorrected ? ' (korrigiert)' : ''}\n'
          '$time · ${m.latitude.toStringAsFixed(4)}, ${m.longitude.toStringAsFixed(4)}',
        ),
        isThreeLine: true,
      ),
    );
  }
}
