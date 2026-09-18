import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/measurement_stats.dart';
import '../models/noise_category.dart';
import '../models/noise_level_class.dart';
import '../repositories/measurement_repository.dart';

/// Einfache Auswertung aller gespeicherten Messungen.
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key, required this.repository});

  final MeasurementRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistik')),
      body: ListenableBuilder(
        listenable: repository,
        builder: (context, _) {
          final s = MeasurementStats.of(repository.all);
          if (s.isEmpty) {
            return const Center(child: Text('Noch keine Messungen vorhanden.'));
          }
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _KpiRow(stats: s),
              const SizedBox(height: 20),
              _Section(
                title: 'Nach Geräuschklasse',
                child: Column(
                  children: [
                    for (final c in NoiseCategory.values)
                      _Bar(
                        label: c.label,
                        value: s.byCategory[c]!,
                        max: s.count,
                        color: AppTheme.categoryColor(c),
                        trailing: '${s.byCategory[c]}',
                      ),
                  ],
                ),
              ),
              _Section(
                title: 'Nach Pegelklasse (indikativ)',
                child: Column(
                  children: [
                    for (final l in NoiseLevelClass.values)
                      _Bar(
                        label: '${l.label} · ${l.rangeLabel}',
                        value: s.byLevelClass[l]!,
                        max: s.count,
                        color: AppTheme.levelColor(l),
                        trailing: '${s.byLevelClass[l]}',
                      ),
                  ],
                ),
              ),
              _Section(
                title: 'Messungen nach Tageszeit',
                subtitle: s.busiestHour == null
                    ? null
                    : 'Meiste Messungen: ${s.busiestHour}–${s.busiestHour! + 1} Uhr',
                child: _HourChart(stats: s),
              ),
              _Section(
                title: 'KI-Klassifikation',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ø Confidence: ${(s.meanConfidence * 100).round()} %'),
                    Text('Anteil „unsicher“: ${(s.uncertainShare * 100).round()} %'),
                    Text('Vom Nutzer korrigiert: ${(s.userCorrectedShare * 100).round()} %'),
                    if (s.mostFrequentCategory != null)
                      Text('Häufigste Klasse: ${s.mostFrequentCategory!.label}'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Alle Pegelwerte sind indikativ (unkalibriertes Smartphone-Mikrofon).',
                style: theme.textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.stats});

  final MeasurementStats stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Row(
      children: [
        _Kpi(label: 'Messungen', value: '${s.count}'),
        _Kpi(label: 'Ø Pegel', value: '${s.meanLevel.toStringAsFixed(1)} dB'),
        _Kpi(label: 'Median', value: '${s.medianLevel.toStringAsFixed(1)} dB'),
        _Kpi(label: 'Maximum', value: '${s.maxLevel.toStringAsFixed(1)} dB'),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            children: [
              FittedBox(
                child: Text(value,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 2),
              Text(label, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          if (subtitle != null)
            Text(subtitle!, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    required this.trailing,
  });

  final String label;
  final int value;
  final int max;
  final Color color;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final frac = max == 0 ? 0.0 : value / max;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 12,
                color: color,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text(trailing,
                textAlign: TextAlign.end, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// 24 Balken (Anzahl je Stunde), Farbe nach mittlerem Pegel der Stunde.
class _HourChart extends StatelessWidget {
  const _HourChart({required this.stats});

  final MeasurementStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCount = stats.byHour.fold<int>(0, (a, b) => a > b ? a : b);
    return Column(
      children: [
        SizedBox(
          height: 90,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var h = 0; h < 24; h++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Tooltip(
                      message: stats.byHour[h] == 0
                          ? '$h Uhr: –'
                          : '$h Uhr: ${stats.byHour[h]} · Ø ${stats.meanLevelByHour[h]!.toStringAsFixed(0)} dB',
                      child: Container(
                        height: maxCount == 0
                            ? 2
                            : 2 + 86 * stats.byHour[h] / maxCount,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3)),
                          color: stats.meanLevelByHour[h] == null
                              ? theme.colorScheme.surfaceContainerHighest
                              : AppTheme.levelColor(NoiseLevelClass.fromLevel(
                                  stats.meanLevelByHour[h]!)),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final t in const ['0', '6', '12', '18', '24'])
              Text(t, style: theme.textTheme.labelSmall),
          ],
        ),
        const SizedBox(height: 4),
        Text('Balkenhöhe = Anzahl, Farbe = mittlere Pegelklasse der Stunde',
            style: theme.textTheme.labelSmall),
      ],
    );
  }
}
