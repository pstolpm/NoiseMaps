import 'package:flutter/material.dart';

import 'app.dart';
import 'repositories/measurement_repository.dart';

void main() {
  // Phase 1: flüchtiges Repository mit Dummy-Daten.
  // Wird in Phase 5 durch eine lokale Datenbank ersetzt.
  final repository = InMemoryMeasurementRepository();
  runApp(NoiseMapsApp(repository: repository));
}
