import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'repositories/measurement_repository.dart';
import 'services/ai_classification_service.dart';
import 'services/audio_service.dart';
import 'services/location_service.dart';
import 'screens/home_screen.dart';

class NoiseMapsApp extends StatelessWidget {
  const NoiseMapsApp({
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
    return MaterialApp(
      title: 'NoiseMaps',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: HomeScreen(
        repository: repository,
        locationService: locationService,
        audioService: audioService,
        aiService: aiService,
      ),
    );
  }
}
