import 'dart:typed_data';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:noise_maps/app.dart';
import 'package:noise_maps/models/measurement_filter.dart';
import 'package:noise_maps/models/measurement_stats.dart';
import 'package:noise_maps/models/noise_category.dart';
import 'package:noise_maps/models/noise_level_class.dart';
import 'package:noise_maps/models/noise_measurement.dart';
import 'package:noise_maps/repositories/measurement_repository.dart';
import 'package:noise_maps/services/ai_classification_service.dart';
import 'package:noise_maps/services/audio_service.dart';
import 'package:noise_maps/services/export_service.dart';
import 'package:noise_maps/services/location_service.dart';
import 'package:noise_maps/services/sound_level_service.dart';

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

  group('LocationService (Fake)', () {
    test('liefert Fix', () async {
      final fix = await const FakeLocationService().getCurrentFix();
      expect(fix.latitude, closeTo(52.52, 0.001));
      expect(fix.accuracy, 8.0);
    });

    test('wirft LocationException mit deutscher Meldung', () async {
      const svc = FakeLocationService(failure: LocationFailure.permissionDenied);
      expect(
        () => svc.getCurrentFix(),
        throwsA(isA<LocationException>()
            .having((e) => e.message, 'message', contains('verweigert'))),
      );
    });
  });

  group('Audio + Pegel (Fake)', () {
    test('FakeAudioService liefert 4 s bei 16 kHz', () async {
      final sample = await const FakeAudioService()
          .recordSample(duration: const Duration(seconds: 4));
      expect(sample.sampleRate, 16000);
      expect(sample.samples.length, 64000);
      expect(sample.duration.inSeconds, 4);
    });

    test('Pegel: Vollaussteuerung ≈ 0 dBFS, Stille = Floor', () {
      const svc = SoundLevelService(calibrationOffsetDb: 90);
      final full = AudioSample(
        samples: Float32List.fromList(List.filled(1600, 1.0)),
        sampleRate: 16000,
      );
      final r = svc.analyze(full);
      expect(r.rmsDbfs, closeTo(0, 0.01));
      expect(r.isClipping, isTrue);
      expect(r.indicativeDb, closeTo(90, 0.01));

      final silence = AudioSample(
        samples: Float32List(1600),
        sampleRate: 16000,
      );
      expect(svc.analyze(silence).rmsDbfs, -100);
      expect(svc.analyze(silence).indicativeDb, 0);
    });

    test('Pegel: Sinus mit Amplitude 0.1 ≈ -23 dBFS', () async {
      final sample = await const FakeAudioService(amplitude: 0.1)
          .recordSample(duration: const Duration(seconds: 1));
      final r = const SoundLevelService().analyze(sample);
      // 0.8*0.1 Sinus → RMS ≈ 0.0566 → ≈ -25 dBFS, plus Rauschanteil
      expect(r.rmsDbfs, closeTo(-24.5, 1.5));
      expect(r.isClipping, isFalse);
    });

    test('AudioException hat deutsche Meldung', () {
      const svc = FakeAudioService(failure: AudioFailure.permissionDenied);
      expect(
        () => svc.recordSample(duration: const Duration(seconds: 1)),
        throwsA(isA<AudioException>()
            .having((e) => e.message, 'message', contains('Mikrofon'))),
      );
    });
  });

  group('AI (Mock)', () {
    test('Mock liefert Klasse mit Confidence', () async {
      final sample = await const FakeAudioService(amplitude: 0.3)
          .recordSample(duration: const Duration(seconds: 1));
      final r = await const MockAiClassificationService().classifyAudio(sample);
      expect(r.confidence, inInclusiveRange(0, 1));
      expect(r.category, isNot(NoiseCategory.uncertain));
    });
  });

  group('MeasurementFilter', () {
    final items = MeasurementRepository.sampleMeasurements();

    test('leerer Filter lässt alles durch', () {
      expect(MeasurementFilter.none.apply(items).length, items.length);
      expect(MeasurementFilter.none.isActive, isFalse);
    });

    test('Kategorie-Filter', () {
      final f = const MeasurementFilter(categories: {NoiseCategory.traffic});
      final r = f.apply(items);
      expect(r.map((m) => m.effectiveCategory).toSet(), {NoiseCategory.traffic});
      expect(f.activeCount, 1);
    });

    test('Pegelklassen-Filter', () {
      final f = const MeasurementFilter(levelClasses: {NoiseLevelClass.veryLoud});
      expect(f.apply(items).every((m) => m.soundLevel >= 80), isTrue);
      expect(f.apply(items), isNotEmpty);
    });

    test('Heute-Filter mit festem Bezugsdatum', () {
      final f = const MeasurementFilter(timeRange: TimeRangeFilter.today);
      final now = DateTime.now();
      expect(f.apply(items, now: now), isNotEmpty); // die 5-Minuten-Messung
      expect(f.apply(items, now: now.add(const Duration(days: 2))), isEmpty);
    });
  });

  group('GeoJSON-Import', () {
    test('Roundtrip: Export -> Parse liefert gleiche Kernwerte, origin gesetzt', () {
      const svc = ExportService();
      final items = MeasurementRepository.sampleMeasurements();
      final geojson = svc.toGeoJson(items);
      final parsed = svc.parseGeoJson(geojson, sourceLabel: 'test.geojson');
      expect(parsed.length, items.length);
      expect(parsed.every((m) => m.isImported), isTrue);
      expect(parsed.first.origin, 'Import: test.geojson');
      final orig = items.firstWhere((m) => m.id == parsed.first.id);
      expect(parsed.first.latitude, orig.latitude);
      expect(parsed.first.longitude, orig.longitude);
      expect(parsed.first.soundLevel, orig.soundLevel);
    });

    test('ungültiges JSON wirft FormatException', () {
      const svc = ExportService();
      expect(() => svc.parseGeoJson('{"type":"Nope"}', sourceLabel: 'x'),
          throwsFormatException);
    });

    test('importMeasurements überschreibt vorhandene ids nicht', () async {
      final repo = InMemoryMeasurementRepository(seed: false);
      final own = NoiseMeasurement(
        id: 'shared-id',
        latitude: 1,
        longitude: 1,
        timestamp: DateTime.now(),
        soundLevel: 99,
        aiCategory: NoiseCategory.traffic,
        aiConfidence: 0.9,
      );
      await repo.add(own);
      final imported = NoiseMeasurement(
        id: 'shared-id', // Kollision -> darf nicht überschreiben
        latitude: 2,
        longitude: 2,
        timestamp: DateTime.now(),
        soundLevel: 1,
        aiCategory: NoiseCategory.nature,
        aiConfidence: 0.1,
        origin: 'Import: x.geojson',
      );
      final other = NoiseMeasurement(
        id: 'new-id',
        latitude: 3,
        longitude: 3,
        timestamp: DateTime.now(),
        soundLevel: 50,
        aiCategory: NoiseCategory.people,
        aiConfidence: 0.5,
        origin: 'Import: x.geojson',
      );
      final added = await repo.importMeasurements([imported, other]);
      expect(added, 1);
      expect(repo.all.firstWhere((m) => m.id == 'shared-id').soundLevel, 99);
      expect(repo.all.any((m) => m.id == 'new-id'), isTrue);
    });
  });

  group('ExportService', () {
    final items = MeasurementRepository.sampleMeasurements();
    const svc = ExportService();

    test('GeoJSON ist gültige FeatureCollection mit lon/lat-Reihenfolge', () {
      final fc = json.decode(svc.toGeoJson(items)) as Map<String, dynamic>;
      expect(fc['type'], 'FeatureCollection');
      final features = fc['features'] as List;
      expect(features.length, items.length);
      final first = features.first as Map<String, dynamic>;
      final coords = (first['geometry'] as Map)['coordinates'] as List;
      expect(coords[0], items.first.longitude);
      expect(coords[1], items.first.latitude);
      expect((first['properties'] as Map)['aiCategory'], items.first.aiCategory.key);
    });

    test('CSV hat Kopfzeile + eine Zeile je Messung', () {
      final lines = const LineSplitter().convert(svc.toCsv(items));
      expect(lines.length, items.length + 1);
      expect(lines.first.split(',').length, lines[1].split(',').length);
      expect(lines.first, startsWith('id,latitude,longitude'));
    });
  });

  group('MeasurementStats', () {
    test('leer', () {
      final s = MeasurementStats.of(const []);
      expect(s.isEmpty, isTrue);
      expect(s.mostFrequentCategory, isNull);
    });

    test('Kennzahlen der Beispieldaten', () {
      final items = MeasurementRepository.sampleMeasurements();
      final s = MeasurementStats.of(items);
      expect(s.count, 5);
      expect(s.maxLevel, 82.7);
      expect(s.minLevel, 46.3);
      expect(s.meanLevel, closeTo((74.2 + 68.9 + 46.3 + 82.7 + 61.0) / 5, 0.001));
      expect(s.medianLevel, 68.9);
      expect(s.byCategory.values.fold<int>(0, (a, b) => a + b), 5);
      expect(s.byHour.fold<int>(0, (a, b) => a + b), 5);
      expect(s.uncertainShare, closeTo(0.2, 0.001));
    });
  });

  testWidgets('Home zeigt Titel und Messbutton', (tester) async {
    await tester.pumpWidget(
      NoiseMapsApp(
        repository: InMemoryMeasurementRepository(),
        locationService: const FakeLocationService(),
        audioService: const FakeAudioService(),
        aiService: const MockAiClassificationService(),
      ),
    );
    expect(find.text('NoiseMaps'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Messung starten'), findsOneWidget);
    expect(find.textContaining('Letzte Messung'), findsOneWidget);
  });
}
