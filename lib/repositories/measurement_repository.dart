import 'package:flutter/foundation.dart';

import '../models/noise_category.dart';
import '../models/noise_measurement.dart';

/// Zugriff auf gespeicherte Messungen. Die Implementierung ist austauschbar
/// (In-Memory jetzt, lokale Datenbank in Phase 5, optional Firebase später).
abstract class MeasurementRepository extends ChangeNotifier {
  List<NoiseMeasurement> get all;

  Future<void> add(NoiseMeasurement measurement);

  Future<void> remove(String id);

  NoiseMeasurement? get latest =>
      all.isEmpty ? null : all.reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);
}

/// Flüchtiger Speicher für das App-Skelett. Startet mit Dummy-Daten
/// rund um Berlin, damit Listen und später die Karte sofort etwas zeigen.
class InMemoryMeasurementRepository extends MeasurementRepository {
  InMemoryMeasurementRepository({bool seed = true}) {
    if (seed) _items.addAll(_dummyData());
  }

  final List<NoiseMeasurement> _items = [];

  @override
  List<NoiseMeasurement> get all => List.unmodifiable(_items);

  @override
  Future<void> add(NoiseMeasurement measurement) async {
    _items.add(measurement);
    notifyListeners();
  }

  @override
  Future<void> remove(String id) async {
    _items.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  static List<NoiseMeasurement> _dummyData() {
    final now = DateTime.now();
    NoiseMeasurement m(int i, double lat, double lon, double dB,
        NoiseCategory cat, double conf, int minutesAgo) {
      return NoiseMeasurement(
        id: 'dummy-$i',
        latitude: lat,
        longitude: lon,
        timestamp: now.subtract(Duration(minutes: minutesAgo)),
        soundLevel: dB,
        aiCategory: cat,
        aiConfidence: conf,
        gpsAccuracy: 8.0,
        durationSeconds: 4,
      );
    }

    return [
      m(1, 52.5163, 13.3777, 74.2, NoiseCategory.traffic, 0.86, 5),      // Brandenburger Tor
      m(2, 52.5200, 13.4050, 68.9, NoiseCategory.people, 0.71, 40),      // Alexanderplatz
      m(3, 52.5145, 13.3501, 46.3, NoiseCategory.nature, 0.64, 90),      // Tiergarten
      m(4, 52.5250, 13.3690, 82.7, NoiseCategory.construction, 0.79, 150), // Hauptbahnhof-Nähe
      m(5, 52.5075, 13.3904, 61.0, NoiseCategory.uncertain, 0.32, 300),  // Potsdamer Platz
    ];
  }
}
