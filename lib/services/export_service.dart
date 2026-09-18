import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

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
