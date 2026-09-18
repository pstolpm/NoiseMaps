import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Kurzer Audio-Ausschnitt als normalisierte Samples (-1.0 … 1.0).
///
/// Bleibt nur im Arbeitsspeicher; nach Pegelberechnung und Inferenz
/// wird das Objekt verworfen (Project Brain: kein Roh-Audio speichern).
class AudioSample {
  const AudioSample({
    required this.samples,
    required this.sampleRate,
  });

  final Float32List samples;
  final int sampleRate;

  Duration get duration =>
      Duration(microseconds: samples.length * 1000000 ~/ sampleRate);
}

enum AudioFailure { permissionDenied, deviceUnavailable, tooShort, unknown }

class AudioException implements Exception {
  const AudioException(this.failure, [this.detail]);

  final AudioFailure failure;
  final String? detail;

  String get message => switch (failure) {
        AudioFailure.permissionDenied =>
          'Mikrofonberechtigung wurde verweigert. Bitte in den App-Einstellungen erlauben.',
        AudioFailure.deviceUnavailable =>
          'Mikrofon nicht verfügbar. Wird es von einer anderen App genutzt?',
        AudioFailure.tooShort =>
          'Aufnahme zu kurz oder leer. Bitte erneut versuchen.',
        AudioFailure.unknown =>
          'Aufnahme fehlgeschlagen${detail == null ? '' : ' ($detail)'}.',
      };

  @override
  String toString() => 'AudioException(${failure.name}): $message';
}

/// Abstraktion über die Mikrofonaufnahme.
abstract class AudioService {
  /// Zielformat: 16 kHz mono – das Eingangsformat von YAMNet.
  static const int sampleRate = 16000;

  /// Nimmt [duration] lang auf und liefert die Samples. Wirft [AudioException].
  /// [onProgress] wird mit 0.0 … 1.0 aufgerufen, [onLiveLevel] pro
  /// empfangenem Block mit dem aktuellen RMS-Pegel in dBFS.
  Future<AudioSample> recordSample({
    required Duration duration,
    void Function(double progress)? onProgress,
    void Function(double rmsDbfs)? onLiveLevel,
  });

  /// RMS eines PCM-16-Blocks in dBFS (für Live-Anzeige).
  static double chunkRmsDbfs(Uint8List chunk) {
    final n = chunk.length ~/ 2;
    if (n == 0) return -100;
    final data = ByteData.sublistView(chunk);
    var sumSq = 0.0;
    for (var i = 0; i < n; i++) {
      final v = data.getInt16(i * 2, Endian.little) / 32768.0;
      sumSq += v * v;
    }
    final rms = sqrt(sumSq / n);
    return rms <= 0 ? -100 : max(-100, 20 * log(rms) / ln10);
  }

  Future<void> dispose();
}

/// Produktive Implementierung über das record-Paket (PCM-Stream, keine Datei).
class RecordAudioService implements AudioService {
  RecordAudioService();

  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<AudioSample> recordSample({
    required Duration duration,
    void Function(double progress)? onProgress,
    void Function(double rmsDbfs)? onLiveLevel,
  }) async {
    if (!await _recorder.hasPermission()) {
      throw const AudioException(AudioFailure.permissionDenied);
    }

    final chunks = <Uint8List>[];
    var totalBytes = 0;
    final targetBytes = AudioService.sampleRate * 2 * duration.inMilliseconds ~/ 1000;

    Stream<Uint8List> stream;
    try {
      stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: AudioService.sampleRate,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ));
    } catch (e) {
      throw AudioException(AudioFailure.deviceUnavailable, e.toString());
    }

    final done = Completer<void>();
    late final StreamSubscription<Uint8List> sub;
    sub = stream.listen(
      (chunk) {
        chunks.add(chunk);
        totalBytes += chunk.length;
        onProgress?.call(min(1.0, totalBytes / targetBytes));
        onLiveLevel?.call(AudioService.chunkRmsDbfs(chunk));
        if (totalBytes >= targetBytes && !done.isCompleted) done.complete();
      },
      onError: (Object e) {
        if (!done.isCompleted) done.completeError(e);
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
    );

    try {
      // Sicherheitsnetz: falls der Stream weniger liefert als erwartet.
      await done.future.timeout(duration + const Duration(seconds: 3));
    } on TimeoutException {
      // weiter mit dem, was da ist
    } catch (e) {
      await sub.cancel();
      await _recorder.stop();
      throw AudioException(AudioFailure.unknown, e.toString());
    }
    await sub.cancel();
    await _recorder.stop();

    final samples = _pcm16ToFloat(chunks, totalBytes);
    if (samples.length < AudioService.sampleRate ~/ 2) {
      throw const AudioException(AudioFailure.tooShort);
    }
    return AudioSample(samples: samples, sampleRate: AudioService.sampleRate);
  }

  static Float32List _pcm16ToFloat(List<Uint8List> chunks, int totalBytes) {
    final bytes = Uint8List(totalBytes);
    var offset = 0;
    for (final c in chunks) {
      bytes.setRange(offset, offset + c.length, c);
      offset += c.length;
    }
    final n = totalBytes ~/ 2;
    final data = ByteData.sublistView(bytes);
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      out[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}

/// Synthetisches Signal für Tests und Emulator ohne Mikrofon.
class FakeAudioService implements AudioService {
  const FakeAudioService({
    this.amplitude = 0.05,
    this.failure,
    this.simulateDelay = false,
  });

  /// Spitzenamplitude 0…1 (0.05 ≈ -26 dBFS).
  final double amplitude;
  final AudioFailure? failure;
  final bool simulateDelay;

  @override
  Future<AudioSample> recordSample({
    required Duration duration,
    void Function(double progress)? onProgress,
    void Function(double rmsDbfs)? onLiveLevel,
  }) async {
    if (failure != null) throw AudioException(failure!);
    final n = AudioService.sampleRate * duration.inMilliseconds ~/ 1000;
    final out = Float32List(n);
    final rnd = Random(42);
    for (var i = 0; i < n; i++) {
      // 440-Hz-Ton plus etwas Rauschen
      out[i] = amplitude *
          (0.8 * sin(2 * pi * 440 * i / AudioService.sampleRate) +
              0.2 * (rnd.nextDouble() * 2 - 1));
    }
    if (simulateDelay) {
      const steps = 20;
      for (var s = 1; s <= steps; s++) {
        await Future<void>.delayed(duration ~/ steps);
        onProgress?.call(s / steps);
        onLiveLevel?.call(20 * log(amplitude * 0.6) / ln10);
      }
    } else {
      onProgress?.call(1);
    }
    return AudioSample(samples: out, sampleRate: AudioService.sampleRate);
  }

  @override
  Future<void> dispose() async {}
}
