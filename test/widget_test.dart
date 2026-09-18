import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:noise_maps/app.dart';
import 'package:noise_maps/models/noise_category.dart';
import 'package:noise_maps/models/noise_level_class.dart';
import 'package:noise_maps/models/noise_measurement.dart';
import 'package:noise_maps/repositories/measurement_repository.dart';

void main() {
  group('Modelle', () {
    test('Pegelklassen-Grenzen', () {
      expect(NoiseLevelClass.fromLevel(30), NoiseLevelClass.quiet);
      expect(NoiseLevelClass.fromLevel(50), NoiseLevelClass.moderate);
      expect(NoiseLevelClass.fromLevel(65), NoiseLevelClass.loud);
      expect(NoiseLevelClass.fromLevel(85), NoiseLevelClass.veryLoud);
    });

    test('unbekannter Kategorie-Key wird zu uncertain', () {
      expect(NoiseCategory.fromKey('foo'), NoiseCategory.uncertain);
      expect(NoiseCategory.fromKey(null), NoiseCategory.uncertain);
    });

    test('JSON-Roundtrip', () {
      final m = NoiseMeasurement(
        id: 'x',
        latitude: 52.52,
        longitude: 13.405,
        timestamp: DateTime.parse('2026-09-18T14:00:00+02:00'),
        soundLevel: 71.4,
        aiCategory: NoiseCategory.traffic,
        aiConfidence: 0.82,
        gpsAccuracy: 9.5,
        durationSeconds: 5,
      );
      final back = NoiseMeasurement.fromJson(m.toJson());
      expect(back.id, m.id);
      expect(back.soundLevel, m.soundLevel);
      expect(back.aiCategory, NoiseCategory.traffic);
      expect(back.timestamp, m.timestamp);
      expect(back.effectiveCategory, NoiseCategory.traffic);
    });
  });

  group('Repository', () {
    test('Dummy-Daten vorhanden, add/remove funktionieren', () async {
      final repo = InMemoryMeasurementRepository();
      final n = repo.all.length;
      expect(n, greaterThan(0));
      await repo.add(NoiseMeasurement(
        id: 'new',
        latitude: 0,
        longitude: 0,
        timestamp: DateTime.now(),
        soundLevel: 55,
        aiCategory: NoiseCategory.people,
        aiConfidence: 0.5,
      ));
      expect(repo.all.length, n + 1);
      expect(repo.latest?.id, 'new');
      await repo.remove('new');
      expect(repo.all.length, n);
    });
  });

  testWidgets('Home zeigt Titel und Messbutton', (tester) async {
    await tester.pumpWidget(
      NoiseMapsApp(repository: InMemoryMeasurementRepository()),
    );
    expect(find.text('NoiseMaps'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Messung starten'), findsOneWidget);
    expect(find.text('Letzte Messung'), findsOneWidget);
  });
}
