import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/noise_category.dart';
import '../models/noise_measurement.dart';

/// Zugriff auf gespeicherte Messungen. Die Implementierung ist austauschbar
/// (In-Memory für Tests, SQLite lokal, optional Firebase später).
abstract class MeasurementRepository extends ChangeNotifier {
  List<NoiseMeasurement> get all;

  Future<void> add(NoiseMeasurement measurement);

  Future<void> remove(String id);

  Future<void> clear();

  /// Fügt importierte Messungen hinzu, ohne vorhandene (auch eigene) zu
  /// überschreiben. Gibt die Anzahl tatsächlich hinzugefügter Messungen zurück.
  Future<int> importMeasurements(Iterable<NoiseMeasurement> items) async {
    final existing = all.map((m) => m.id).toSet();
    var added = 0;
    for (final m in items) {
      if (existing.contains(m.id)) continue;
      await add(m);
      existing.add(m.id);
      added++;
    }
    return added;
  }

  NoiseMeasurement? get latest => all.isEmpty
      ? null
      : all.reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);

  /// Fügt Beispielmessungen rund um Berlin hinzu (Demo/Debug).
  Future<void> addSampleData() async {
    for (final m in sampleMeasurements()) {
      await add(m);
    }
  }

  static List<NoiseMeasurement> sampleMeasurements() {
    final now = DateTime.now();
    final stamp = now.millisecondsSinceEpoch;
    NoiseMeasurement m(int i, double lat, double lon, double dB,
        NoiseCategory cat, double conf, int minutesAgo) {
      return NoiseMeasurement(
        id: 'sample-$stamp-$i',
        latitude: lat,
        longitude: lon,
        timestamp: now.subtract(Duration(minutes: minutesAgo)),
        soundLevel: dB,
        aiCategory: cat,
        aiConfidence: conf,
        gpsAccuracy: 8.0,
        durationSeconds: 4,
        qualityFlag: 'sample',
      );
    }

    return [
      m(1, 52.5163, 13.3777, 74.2, NoiseCategory.traffic, 0.86, 5), // Brandenburger Tor
      m(2, 52.5200, 13.4050, 68.9, NoiseCategory.people, 0.71, 40), // Alexanderplatz
      m(3, 52.5145, 13.3501, 46.3, NoiseCategory.nature, 0.64, 90), // Tiergarten
      m(4, 52.5250, 13.3690, 82.7, NoiseCategory.construction, 0.79, 150), // Hbf
      m(5, 52.5075, 13.3904, 61.0, NoiseCategory.uncertain, 0.32, 300), // Potsdamer Platz
    ];
  }
}

/// Flüchtiger Speicher für Tests und Widget-Tests.
class InMemoryMeasurementRepository extends MeasurementRepository {
  InMemoryMeasurementRepository({bool seed = true}) {
    if (seed) _items.addAll(MeasurementRepository.sampleMeasurements());
  }

  final List<NoiseMeasurement> _items = [];

  @override
  List<NoiseMeasurement> get all => List.unmodifiable(_items);

  @override
  Future<void> add(NoiseMeasurement measurement) async {
    _items.removeWhere((m) => m.id == measurement.id);
    _items.add(measurement);
    notifyListeners();
  }

  @override
  Future<void> remove(String id) async {
    _items.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  @override
  Future<void> clear() async {
    _items.clear();
    notifyListeners();
  }
}

/// Lokale SQLite-Datenbank (Phase 5). Hält zusätzlich einen In-Memory-Cache,
/// damit `all` synchron bleibt und die Screens unverändert funktionieren.
class SqliteMeasurementRepository extends MeasurementRepository {
  SqliteMeasurementRepository._(this._db, List<NoiseMeasurement> initial)
      : _cache = initial;

  static const _dbName = 'noise_maps.db';
  static const _table = 'measurements';
  static const _schemaVersion = 1;

  final Database _db;
  final List<NoiseMeasurement> _cache;

  static Future<SqliteMeasurementRepository> open() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    final db = await openDatabase(
      path,
      version: _schemaVersion,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE $_table (
          id TEXT PRIMARY KEY,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          timestamp TEXT NOT NULL,
          sound_level REAL NOT NULL,
          ai_category TEXT NOT NULL,
          ai_confidence REAL NOT NULL,
          gps_accuracy REAL,
          user_category TEXT,
          is_user_corrected INTEGER NOT NULL DEFAULT 0,
          device_model TEXT,
          osm_road_class TEXT,
          duration_seconds INTEGER,
          quality_flag TEXT NOT NULL DEFAULT 'valid',
          origin TEXT
        )
      '''),
    );
    final rows = await db.query(_table, orderBy: 'timestamp ASC');
    final items = rows.map(_fromRow).toList();
    debugPrint('SQLite geöffnet: $path (${items.length} Messungen)');
    return SqliteMeasurementRepository._(db, items);
  }

  @override
  List<NoiseMeasurement> get all => List.unmodifiable(_cache);

  @override
  Future<void> add(NoiseMeasurement m) async {
    await _db.insert(_table, _toRow(m),
        conflictAlgorithm: ConflictAlgorithm.replace);
    _cache.removeWhere((x) => x.id == m.id);
    _cache.add(m);
    notifyListeners();
  }

  @override
  Future<void> remove(String id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
    _cache.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  @override
  Future<void> clear() async {
    await _db.delete(_table);
    _cache.clear();
    notifyListeners();
  }

  Future<void> close() => _db.close();

  static Map<String, Object?> _toRow(NoiseMeasurement m) => {
        'id': m.id,
        'latitude': m.latitude,
        'longitude': m.longitude,
        'timestamp': m.timestamp.toIso8601String(),
        'sound_level': m.soundLevel,
        'ai_category': m.aiCategory.key,
        'ai_confidence': m.aiConfidence,
        'gps_accuracy': m.gpsAccuracy,
        'user_category': m.userCategory?.key,
        'is_user_corrected': m.isUserCorrected ? 1 : 0,
        'device_model': m.deviceModel,
        'osm_road_class': m.osmRoadClass,
        'duration_seconds': m.durationSeconds,
        'quality_flag': m.qualityFlag,
        'origin': m.origin,
      };

  static NoiseMeasurement _fromRow(Map<String, Object?> r) => NoiseMeasurement(
        id: r['id'] as String,
        latitude: r['latitude'] as double,
        longitude: r['longitude'] as double,
        timestamp: DateTime.parse(r['timestamp'] as String),
        soundLevel: r['sound_level'] as double,
        aiCategory: NoiseCategory.fromKey(r['ai_category'] as String?),
        aiConfidence: r['ai_confidence'] as double,
        gpsAccuracy: r['gps_accuracy'] as double?,
        userCategory: r['user_category'] == null
            ? null
            : NoiseCategory.fromKey(r['user_category'] as String?),
        isUserCorrected: (r['is_user_corrected'] as int? ?? 0) == 1,
        deviceModel: r['device_model'] as String?,
        osmRoadClass: r['osm_road_class'] as String?,
        durationSeconds: r['duration_seconds'] as int?,
        qualityFlag: r['quality_flag'] as String? ?? 'valid',
        origin: r['origin'] as String?,
      );
}
