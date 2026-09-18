import 'dart:math';

import 'audio_service.dart';

/// Ergebnis der Pegelberechnung.
class SoundLevelResult {
  const SoundLevelResult({
    required this.rmsDbfs,
    required this.peakDbfs,
    required this.indicativeDb,
  });

  /// Effektivwert relativ zu Vollaussteuerung (≤ 0).
  final double rmsDbfs;

  /// Spitzenwert relativ zu Vollaussteuerung (≤ 0).
  final double peakDbfs;

  /// Grob auf eine dB-Skala verschobener Wert. NICHT kalibriert.
  final double indicativeDb;

  /// Übersteuerung – Pegel dann nach oben unsicher.
  bool get isClipping => peakDbfs > -0.5;
}

/// Berechnet aus einem [AudioSample] einen indikativen Pegel.
///
/// Smartphone-Mikrofone sind nicht kalibriert; [calibrationOffsetDb] ist ein
/// pauschaler Offset, der dBFS grob in die Größenordnung realer Umgebungs-
/// pegel verschiebt (typisch 85–95 dB je nach Gerät). Er kann später pro
/// Gerät angepasst werden, bleibt aber eine Schätzung.
class SoundLevelService {
  const SoundLevelService({this.calibrationOffsetDb = 90.0});

  final double calibrationOffsetDb;

  static const double _floorDbfs = -100.0;

  SoundLevelResult analyze(AudioSample sample) {
    final s = sample.samples;
    if (s.isEmpty) {
      return SoundLevelResult(
        rmsDbfs: _floorDbfs,
        peakDbfs: _floorDbfs,
        indicativeDb: max(0, _floorDbfs + calibrationOffsetDb),
      );
    }
    var sumSq = 0.0;
    var peak = 0.0;
    for (final v in s) {
      sumSq += v * v;
      final a = v.abs();
      if (a > peak) peak = a;
    }
    final rms = sqrt(sumSq / s.length);
    final rmsDbfs = _toDbfs(rms);
    final peakDbfs = _toDbfs(peak);
    return SoundLevelResult(
      rmsDbfs: rmsDbfs,
      peakDbfs: peakDbfs,
      indicativeDb: max(0, rmsDbfs + calibrationOffsetDb),
    );
  }

  static double _toDbfs(double linear) =>
      linear <= 0 ? _floorDbfs : max(_floorDbfs, 20 * log(linear) / ln10);
}
