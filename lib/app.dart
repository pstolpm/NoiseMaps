import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'repositories/measurement_repository.dart';
import 'services/audio_service.dart';
import 'services/location_service.dart';
import 'screens/home_screen.dart';

class NoiseMapsApp extends StatelessWidget {
  const NoiseMapsApp({
    super.key,
    required this.repository,
    required this.locationService,
    required this.audioService,
  });

  final MeasurementRepository repository;
  final LocationService locationService;
  final AudioService audioService;

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
      ),
    );
  }
}
