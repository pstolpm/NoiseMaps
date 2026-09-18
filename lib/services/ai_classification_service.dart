import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/noise_category.dart';
import 'audio_service.dart';

/// Ergebnis einer Klassifikation.
class AiClassification {
  const AiClassification({
    required this.category,
    required this.confidence,
    this.rawTopLabel,
    this.rawTopScore,
    this.categoryScores = const {},
    this.topRaw = const [],
  });

  final NoiseCategory category;

  /// 0.0 – 1.0
  final double confidence;

  /// Beste Originalklasse des Modells (z. B. "Car passing by") – nur zur Anzeige.
  final String? rawTopLabel;
  final double? rawTopScore;

  /// Score je Zielklasse (ohne "uncertain").
  final Map<NoiseCategory, double> categoryScores;

  /// Die besten Originalklassen des Modells (Label, Score) – für Transparenz.
  final List<(String, double)> topRaw;
}

/// Austauschbare AI-Schnittstelle (Project Brain, Abschnitt 16.9).
abstract class AiClassificationService {
  /// Confidence unterhalb dieses Werts -> [NoiseCategory.uncertain]
  /// (Project Brain, Abschnitt 9).
  static const double uncertainThreshold = 0.40;

  /// Kurzbeschreibung für UI/Log (z. B. "YAMNet (TFLite)" oder "Mock").
  String get name;

  Future<AiClassification> classifyAudio(AudioSample sample);

  Future<void> dispose();
}

/// Mock ohne Modell: leitet aus dem Pegel eine plausible Klasse ab.
/// Dient als Fallback, wenn das Modell fehlt, und für Tests.
class MockAiClassificationService implements AiClassificationService {
  const MockAiClassificationService();

  @override
  String get name => 'Mock (ohne Modell)';

  @override
  Future<AiClassification> classifyAudio(AudioSample sample) async {
    var sumSq = 0.0;
    for (final v in sample.samples) {
      sumSq += v * v;
    }
    final rms = sample.samples.isEmpty ? 0.0 : sqrt(sumSq / sample.samples.length);
    final dbfs = rms <= 0 ? -100.0 : 20 * log(rms) / ln10;
    // Sehr leise -> Natur, mittel -> Menschen, laut -> Verkehr; alles wenig sicher.
    final (cat, conf) = dbfs < -45
        ? (NoiseCategory.nature, 0.45)
        : dbfs < -25
            ? (NoiseCategory.people, 0.5)
            : (NoiseCategory.traffic, 0.55);
    return AiClassification(
      category: cat,
      confidence: conf,
      rawTopLabel: 'mock',
      rawTopScore: conf,
      categoryScores: {cat: conf},
    );
  }

  @override
  Future<void> dispose() async {}
}

/// YAMNet über TensorFlow Lite. Erwartet 16-kHz-Mono-Float-Samples.
///
/// Das Modell verarbeitet Fenster von 15600 Samples (0,975 s). Längere
/// Aufnahmen werden in überlappende Fenster zerlegt, die 521 Klassen-Scores
/// werden gemittelt und dann über `class_map.json` auf die Zielklassen
/// abgebildet.
class YamnetAiClassificationService implements AiClassificationService {
  YamnetAiClassificationService._(
    this._interpreter,
    this._labels,
    this._indexToCategory,
    this._inputShape,
  );

  static const modelAsset = 'assets/models/yamnet.tflite';
  static const labelsAsset = 'assets/labels/yamnet_class_map.csv';
  static const classMapAsset = 'assets/labels/class_map.json';

  static const int windowSamples = 15600;
  static const int hopSamples = 7800;

  final Interpreter _interpreter;
  final List<String> _labels;
  final Map<int, NoiseCategory> _indexToCategory;
  final List<int> _inputShape;

  @override
  String get name => 'YAMNet (TFLite)';

  /// Lädt Modell, Labels und Mapping. Wirft, wenn ein Asset fehlt.
  static Future<YamnetAiClassificationService> load() async {
    final interpreter = await Interpreter.fromAsset(
      modelAsset,
      options: InterpreterOptions()..threads = 2,
    );
    final inputShape = interpreter.getInputTensor(0).shape;
    final outputShape = interpreter.getOutputTensor(0).shape;
    debugPrint('YAMNet geladen – input $inputShape, output $outputShape');

    final csv = await rootBundle.loadString(labelsAsset);
    final labels = <String>[];
    for (final line in const LineSplitter().convert(csv).skip(1)) {
      if (line.trim().isEmpty) continue;
      // index,mid,"display name" – Name kann Kommas enthalten
      final parts = line.split(',');
      var name = parts.sublist(2).join(',').trim();
      if (name.startsWith('"') && name.endsWith('"')) {
        name = name.substring(1, name.length - 1);
      }
      labels.add(name);
    }

    final mapJson =
        json.decode(await rootBundle.loadString(classMapAsset)) as Map<String, dynamic>;
    final indexToCategory = <int, NoiseCategory>{};
    for (final entry in mapJson.entries) {
      if (entry.key.startsWith('_')) continue;
      final cat = NoiseCategory.fromKey(entry.key);
      for (final idx in (entry.value as List).cast<int>()) {
        indexToCategory[idx] = cat;
      }
    }

    return YamnetAiClassificationService._(
        interpreter, labels, indexToCategory, inputShape);
  }

  @override
  Future<AiClassification> classifyAudio(AudioSample sample) async {
    final samples = sample.samples;
    final numClasses = _labels.length;
    final avg = List<double>.filled(numClasses, 0);

    // Fensterpositionen; zu kurze Aufnahme wird mit Nullen aufgefüllt.
    final starts = <int>[];
    for (var s = 0; s + windowSamples <= samples.length; s += hopSamples) {
      starts.add(s);
    }
    if (starts.isEmpty) starts.add(0);

    for (final start in starts) {
      final window = List<double>.generate(
        windowSamples,
        (i) => start + i < samples.length ? samples[start + i] : 0.0,
        growable: false,
      );
      final scores = _runWindow(window, numClasses);
      for (var i = 0; i < numClasses; i++) {
        avg[i] += scores[i] / starts.length;
      }
    }

    // Beste Originalklasse (Anzeige)
    var topIdx = 0;
    for (var i = 1; i < numClasses; i++) {
      if (avg[i] > avg[topIdx]) topIdx = i;
    }

    // Zielklassen-Score = höchster Score ihrer Mitgliedsklassen
    final catScores = <NoiseCategory, double>{};
    _indexToCategory.forEach((idx, cat) {
      if (idx < numClasses) {
        catScores[cat] = max(catScores[cat] ?? 0, avg[idx]);
      }
    });

    NoiseCategory best = NoiseCategory.uncertain;
    var bestScore = 0.0;
    catScores.forEach((cat, score) {
      if (score > bestScore) {
        best = cat;
        bestScore = score;
      }
    });

    final confidence = bestScore.clamp(0.0, 1.0);

    final order = List<int>.generate(numClasses, (i) => i)
      ..sort((a, b) => avg[b].compareTo(avg[a]));
    final topRaw = [for (final i in order.take(5)) (_labels[i], avg[i])];

    if (kDebugMode) {
      final top = topRaw
          .map((e) => '${e.$1}=${e.$2.toStringAsFixed(2)}')
          .join(', ');
      final cats = catScores.entries
          .map((e) => '${e.key.key}=${e.value.toStringAsFixed(2)}')
          .join(', ');
      debugPrint('YAMNet top5: $top');
      debugPrint('YAMNet Zielklassen: $cats -> ${best.key} ($confidence)');
    }

    return AiClassification(
      category: confidence < AiClassificationService.uncertainThreshold
          ? NoiseCategory.uncertain
          : best,
      confidence: confidence,
      rawTopLabel: _labels[topIdx],
      rawTopScore: avg[topIdx],
      categoryScores: catScores,
      topRaw: topRaw,
    );
  }

  List<double> _runWindow(List<double> window, int numClasses) {
    // Eingabe an die Tensorform anpassen: [15600] oder [1, 15600].
    final Object input = _inputShape.length == 1 ? window : [window];
    final output = [List<double>.filled(numClasses, 0)];
    _interpreter.run(input, output);
    return output[0];
  }

  @override
  Future<void> dispose() async => _interpreter.close();
}
