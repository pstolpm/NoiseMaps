import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/noise_category.dart';
import '../models/noise_measurement.dart';
import '../repositories/measurement_repository.dart';

/// Ergebnisansicht: Pegel prominent, AI-Klasse + Confidence, Position,
/// optionale Nutzerkorrektur, Speichern / Verwerfen.
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.measurement,
    required this.repository,
  });

  final NoiseMeasurement measurement;
  final MeasurementRepository repository;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late NoiseCategory _selected = widget.measurement.aiCategory;

  Future<void> _save() async {
    final corrected = _selected != widget.measurement.aiCategory;
    final m = widget.measurement.copyWith(
      userCategory: corrected ? _selected : null,
      isUserCorrected: corrected,
    );
    await widget.repository.add(m);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Messung gespeichert')),
    );
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _discard() {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = widget.measurement;
    final levelColor = AppTheme.levelColor(m.levelClass);
    final lowConfidence = m.aiConfidence < 0.4;

    return Scaffold(
      appBar: AppBar(title: const Text('Ergebnis')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  '${m.soundLevel.toStringAsFixed(1)} dB',
                  style: theme.textTheme.displayMedium
                      ?.copyWith(color: levelColor, fontWeight: FontWeight.bold),
                ),
                Text('${m.levelClass.label} · indikativ',
                    style: theme.textTheme.titleMedium),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _InfoTile(
            icon: AppTheme.categoryIcon(m.aiCategory),
            color: AppTheme.categoryColor(m.aiCategory),
            title: 'KI-Klasse: ${m.aiCategory.label}',
            subtitle: 'Confidence ${(m.aiConfidence * 100).round()} %'
                '${lowConfidence ? ' – niedrig, Ergebnis unsicher' : ''}',
          ),
          _InfoTile(
            icon: Icons.location_on,
            title:
                '${m.latitude.toStringAsFixed(5)}, ${m.longitude.toStringAsFixed(5)}',
            subtitle: m.gpsAccuracy == null
                ? 'Genauigkeit unbekannt'
                : 'Genauigkeit ± ${m.gpsAccuracy!.toStringAsFixed(0)} m',
          ),
          _InfoTile(
            icon: Icons.schedule,
            title: m.timestamp.toLocal().toString().substring(0, 16),
            subtitle: 'Dauer ${m.durationSeconds ?? '–'} s',
          ),
          const SizedBox(height: 16),
          Text('Geräuschklasse korrigieren (optional)',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final c in NoiseCategory.values)
                ChoiceChip(
                  label: Text(c.label),
                  avatar: Icon(AppTheme.categoryIcon(c), size: 18),
                  selected: _selected == c,
                  onSelected: (_) => setState(() => _selected = c),
                ),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Speichern'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _discard,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Verwerfen'),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(subtitle),
      contentPadding: EdgeInsets.zero,
    );
  }
}
