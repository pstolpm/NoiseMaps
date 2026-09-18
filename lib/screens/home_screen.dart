import 'package:flutter/material.dart';

import '../repositories/measurement_repository.dart';
import '../services/ai_classification_service.dart';
import '../services/audio_service.dart';
import '../services/location_service.dart';
import '../widgets/measurement_card.dart';
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
      appBar: AppBar(title: const Text('NoiseMaps')),
      body: ListenableBuilder(
        listenable: repository,
        builder: (context, _) {
          final latest = repository.latest;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Urbanen Lärm indikativ erfassen und kartieren.',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Die App misst wenige Sekunden Audio, schätzt den Pegel, '
                'klassifiziert die Geräuschquelle lokal per KI und verortet '
                'die Messung per GPS.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
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
              OutlinedButton.icon(
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
              const SizedBox(height: 12),
              OutlinedButton.icon(
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
              const SizedBox(height: 24),
              Text('Letzte Messung', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (latest == null)
                const Text('Noch keine Messungen vorhanden.')
              else
                MeasurementCard(measurement: latest),
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
                          'Hinweis: Alle Pegelwerte sind indikativ. '
                          'Smartphone-Mikrofone sind nicht kalibriert; dies ist '
                          'keine amtliche Lärmmessung. Roh-Audio wird nicht gespeichert.',
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
