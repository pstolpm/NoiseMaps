import 'package:flutter/material.dart';

import 'app.dart';
import 'repositories/measurement_repository.dart';
import 'services/audio_service.dart';
import 'services/location_service.dart';

void main() {
  // Phase 1: flüchtiges Repository mit Dummy-Daten.
  // Wird in Phase 5 durch eine lokale Datenbank ersetzt.
  final repository = InMemoryMeasurementRepository();
  const locationService = GeolocatorLocationService();
  final audioService = RecordAudioService();
  runApp(NoiseMapsApp(
    repository: repository,
    locationService: locationService,
    audioService: audioService,
  ));
}
