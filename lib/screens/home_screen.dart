import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/noise_measurement.dart';
import '../repositories/measurement_repository.dart';
import '../services/ai_classification_service.dart';
import '../services/audio_service.dart';
import '../services/location_service.dart';
import 'info_screen.dart';
import 'map_screen.dart';
import 'measurement_screen.dart';
import 'statistics_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.locationService,
    required this.audioService,
    required this.aiService,
  });

  final MeasurementRepository repository;
  final LocationService locationService;
  final AudioService audioService;
  final AiClassificationService aiService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('NoiseMaps'),
        actions: [
          IconButton(
            tooltip: 'Info & FAQ',
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => InfoScreen(aiService: aiService)),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: repository,
        builder: (context, _) {
          final all = repository.all.toList()
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
          final latest = all.isEmpty ? null : all.last;
          final recent = all.length > 10 ? all.sublist(all.length - 10) : all;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'Urbanen Lärm indikativ erfassen und kartieren.',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              _LatestHero(latest: latest, recent: recent),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MeasurementScreen(
                      repository: repository,
                      locationService: locationService,
                      audioService: audioService,
                      aiService: aiService,
                    ),
                  ),
                ),
                icon: const Icon(Icons.mic),
                label: const Text('Messung starten'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MapScreen(
                            repository: repository,
                            locationService: locationService,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.map),
                      label: const Text('Karte'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StatisticsScreen(repository: repository),
                        ),
                      ),
                      icon: const Icon(Icons.bar_chart),
                      label: const Text('Statistik'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Alle Pegelwerte sind indikativ. Smartphone-Mikrofone sind '
                          'nicht kalibriert; dies ist keine amtliche Lärmmessung. '
                          'Roh-Audio wird nicht gespeichert.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Große Kachel: letzter Pegel in Pegelfarbe, Klasse, Zeit, Mini-Historie.
class _LatestHero extends StatelessWidget {
  const _LatestHero({required this.latest, required this.recent});

  final NoiseMeasurement? latest;
  final List<NoiseMeasurement> recent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = latest;
    if (m == null) {
      return Card(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Noch keine Messungen. Starte die erste Messung.'),
        ),
      );
    }
    final color = AppTheme.levelColor(m.levelClass);
    final cat = m.effectiveCategory;
    final t = m.timestamp.toLocal();
    String two(int x) => x.toString().padLeft(2, '0');
    final time = '${two(t.day)}.${two(t.month)}. ${two(t.hour)}:${two(t.minute)}';

    return Card(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Letzte Messung · $time', style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  m.soundLevel.toStringAsFixed(1),
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('dB · ${m.levelClass.label}',
                      style: theme.textTheme.titleMedium?.copyWith(color: color)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(AppTheme.categoryIcon(cat),
                    size: 18, color: AppTheme.categoryColor(cat)),
                const SizedBox(width: 6),
                Text(
                  '${cat.label} · ${(m.aiConfidence * 100).round()} %'
                  '${m.isUserCorrected ? ' (korrigiert)' : ''}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            if (recent.length > 1) ...[
              const SizedBox(height: 14),
              _MiniHistory(items: recent),
              const SizedBox(height: 2),
              Text('Letzte ${recent.length} Messungen',
                  style: theme.textTheme.labelSmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniHistory extends StatelessWidget {
  const _MiniHistory({required this.items});

  final List<NoiseMeasurement> items;

  @override
  Widget build(BuildContext context) {
    const minDb = 30.0, maxDb = 100.0;
    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final m in items)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  height: 4 +
                      32 * ((m.soundLevel - minDb) / (maxDb - minDb)).clamp(0, 1),
                  decoration: BoxDecoration(
                    color: AppTheme.levelColor(m.levelClass),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
