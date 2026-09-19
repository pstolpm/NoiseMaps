import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../models/noise_category.dart';
import '../models/noise_measurement.dart';

/// Export der Messungen als GeoJSON / CSV sowie Teilen über den System-Dialog.
/// Die Erzeugung ist reine Dart-Logik (testbar), das Teilen ist davon getrennt.
class ExportService {
  const ExportService();

  /// GeoJSON FeatureCollection (WGS84, RFC 7946). Attribute = Datenmodell.
  String toGeoJson(Iterable<NoiseMeasurement> items) {
    final fc = {
      'type': 'FeatureCollection',
      'features': [
        for (final m in items)
          {
            'type': 'Feature',
            'id': m.id,
            'geometry': {
              'type': 'Point',
              'coordinates': [m.longitude, m.latitude],
            },
            'properties': {
              ...m.toJson()..remove('latitude')..remove('longitude'),
              'effectiveCategory': m.effectiveCategory.key,
              'levelClass': m.levelClass.key,
            },
          },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(fc);
  }

  /// CSV mit Kopfzeile, Komma-getrennt, UTF-8, Dezimalpunkt (QGIS/Excel-Import).
  String toCsv(Iterable<NoiseMeasurement> items) {
    const header = [
      'id', 'latitude', 'longitude', 'timestamp', 'sound_level', 'level_class',
      'ai_category', 'ai_confidence', 'user_category', 'effective_category',
      'is_user_corrected', 'gps_accuracy', 'duration_seconds', 'quality_flag',
    ];
    final sb = StringBuffer()..writeln(header.join(','));
    for (final m in items) {
      sb.writeln([
        m.id,
        m.latitude,
        m.longitude,
        m.timestamp.toIso8601String(),
        m.soundLevel,
        m.levelClass.key,
        m.aiCategory.key,
        m.aiConfidence,
        m.userCategory?.key ?? '',
        m.effectiveCategory.key,
        m.isUserCorrected,
        m.gpsAccuracy ?? '',
        m.durationSeconds ?? '',
        _csvEscape(m.qualityFlag),
      ].join(','));
    }
    return sb.toString();
  }

  /// Parst eine GeoJSON-FeatureCollection (eigenes Export-Format oder
  /// kompatibel: Point-Geometrie + Properties mit den Feldern aus toJson).
  /// Wirft [FormatException] bei ungültigem Inhalt. Fehlerhafte einzelne
  /// Features werden übersprungen, nicht der ganze Import verworfen.
  List<NoiseMeasurement> parseGeoJson(String content, {required String sourceLabel}) {
    final data = json.decode(content);
    if (data is! Map || data['type'] != 'FeatureCollection') {
      throw const FormatException('Keine gültige GeoJSON-FeatureCollection.');
    }
    final features = data['features'];
    if (features is! List) throw const FormatException('Keine "features"-Liste gefunden.');

    final result = <NoiseMeasurement>[];
    for (final f in features) {
      try {
        if (f is! Map) continue;
        final geom = f['geometry'] as Map?;
        if (geom == null || geom['type'] != 'Point') continue;
        final coords = (geom['coordinates'] as List).cast<num>();
        final props = Map<String, dynamic>.from(f['properties'] as Map? ?? {});
        final id = (props['id'] ?? f['id'])?.toString();
        if (id == null || props['timestamp'] == null) continue;

        result.add(NoiseMeasurement(
          id: id,
          longitude: coords[0].toDouble(),
          latitude: coords[1].toDouble(),
          timestamp: DateTime.parse(props['timestamp'] as String),
          soundLevel: (props['soundLevel'] as num?)?.toDouble() ?? 0,
          aiCategory: NoiseCategory.fromKey(props['aiCategory'] as String?),
          aiConfidence: (props['aiConfidence'] as num?)?.toDouble() ?? 0,
          gpsAccuracy: (props['gpsAccuracy'] as num?)?.toDouble(),
          userCategory: props['userCategory'] == null
              ? null
              : NoiseCategory.fromKey(props['userCategory'] as String?),
          isUserCorrected: props['isUserCorrected'] as bool? ?? false,
          durationSeconds: (props['durationSeconds'] as num?)?.toInt(),
          qualityFlag: props['qualityFlag'] as String? ?? 'valid',
          origin: 'Import: $sourceLabel',
        ));
      } catch (_) {
        continue; // einzelnes fehlerhaftes Feature überspringen
      }
    }
    return result;
  }

  static String _csvEscape(String v) =>
      v.contains(RegExp(r'[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;

  static String _stamp() {
    final n = DateTime.now();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}-${two(n.hour)}${two(n.minute)}';
  }

  Future<void> shareGeoJson(Iterable<NoiseMeasurement> items) => _shareText(
        toGeoJson(items),
        'noisemaps-${_stamp()}.geojson',
        'application/geo+json',
        'NoiseMaps GeoJSON',
      );

  Future<void> shareCsv(Iterable<NoiseMeasurement> items) => _shareText(
        toCsv(items),
        'noisemaps-${_stamp()}.csv',
        'text/csv',
        'NoiseMaps CSV',
      );

  Future<void> sharePng(Uint8List png) => SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(png, name: 'noisemaps-karte-${_stamp()}.png', mimeType: 'image/png')],
        subject: 'NoiseMaps Karte',
        text: 'NoiseMaps – indikative Lärmkarte (nicht kalibriert)',
      ));

  Future<void> _shareText(
      String content, String name, String mime, String subject) {
    final bytes = Uint8List.fromList(utf8.encode(content));
    return SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, name: name, mimeType: mime)],
      subject: subject,
      text: 'NoiseMaps-Export – indikative Messwerte, Smartphone-Mikrofon unkalibriert.',
    ));
  }
}
