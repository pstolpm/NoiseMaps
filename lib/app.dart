import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'repositories/measurement_repository.dart';
import 'screens/home_screen.dart';

class NoiseMapsApp extends StatelessWidget {
  const NoiseMapsApp({super.key, required this.repository});

  final MeasurementRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoiseMaps',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: HomeScreen(repository: repository),
    );
  }
}
