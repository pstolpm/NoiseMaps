import 'package:flutter/material.dart';

import 'app.dart';
import 'repositories/measurement_repository.dart';
import 'services/ai_classification_service.dart';
import 'services/audio_service.dart';
import 'services/location_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lokale SQLite-Datenbank; Messungen überleben App-Neustarts.
  final repository = await SqliteMeasurementRepository.open();
  const locationService = GeolocatorLocationService();
  final audioService = RecordAudioService();

  // AI: YAMNet (TFLite), Fallback auf Mock, falls Modell/Assets fehlen.
  AiClassificationService aiService;
  try {
    aiService = await YamnetAiClassificationService.load();
  } catch (e, st) {
    debugPrint('YAMNet konnte nicht geladen werden, nutze Mock: $e');
    debugPrintStack(stackTrace: st, maxFrames: 5);
    aiService = const MockAiClassificationService();
  }

  runApp(NoiseMapsApp(
    repository: repository,
    locationService: locationService,
    audioService: audioService,
    aiService: aiService,
  ));
}
