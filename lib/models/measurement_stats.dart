import 'noise_category.dart';
import 'noise_level_class.dart';
import 'noise_measurement.dart';

/// Einfache deskriptive Statistik über eine Messungsliste.
class MeasurementStats {
  MeasurementStats._({
    required this.count,
    required this.meanLevel,
    required this.medianLevel,
    required this.maxLevel,
    required this.minLevel,
    required this.meanConfidence,
    required this.uncertainShare,
    required this.userCorrectedShare,
    required this.byCategory,
    required this.byLevelClass,
    required this.byHour,
    required this.meanLevelByHour,
  });

  final int count;
  final double meanLevel;
  final double medianLevel;
  final double maxLevel;
  final double minLevel;
  final double meanConfidence;

  /// Anteil Messungen mit effektiver Klasse "unsicher" (0…1).
  final double uncertainShare;

  /// Anteil vom Nutzer korrigierter Klassen (0…1).
  final double userCorrectedShare;

  final Map<NoiseCategory, int> byCategory;
  final Map<NoiseLevelClass, int> byLevelClass;

  /// Anzahl Messungen je Stunde (Index 0–23, lokale Zeit).
  final List<int> byHour;

  /// Mittlerer Pegel je Stunde, null wenn keine Messung.
  final List<double?> meanLevelByHour;

  bool get isEmpty => count == 0;

  NoiseCategory? get mostFrequentCategory {
    if (isEmpty) return null;
    return byCategory.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  int? get busiestHour {
    if (isEmpty) return null;
    var best = 0;
    for (var h = 1; h < 24; h++) {
      if (byHour[h] > byHour[best]) best = h;
    }
    return best;
  }

  factory MeasurementStats.of(Iterable<NoiseMeasurement> items) {
    final list = items.toList();
    final byCategory = {for (final c in NoiseCategory.values) c: 0};
    final byLevel = {for (final l in NoiseLevelClass.values) l: 0};
    final byHour = List<int>.filled(24, 0);
    final sumByHour = List<double>.filled(24, 0);

    if (list.isEmpty) {
      return MeasurementStats._(
        count: 0,
        meanLevel: 0,
        medianLevel: 0,
        maxLevel: 0,
        minLevel: 0,
        meanConfidence: 0,
        uncertainShare: 0,
        userCorrectedShare: 0,
        byCategory: byCategory,
        byLevelClass: byLevel,
        byHour: byHour,
        meanLevelByHour: List<double?>.filled(24, null),
      );
    }

    var sum = 0.0, sumConf = 0.0;
    var uncertain = 0, corrected = 0;
    var maxL = double.negativeInfinity, minL = double.infinity;
    for (final m in list) {
      sum += m.soundLevel;
      sumConf += m.aiConfidence;
      if (m.soundLevel > maxL) maxL = m.soundLevel;
      if (m.soundLevel < minL) minL = m.soundLevel;
      if (m.effectiveCategory == NoiseCategory.uncertain) uncertain++;
      if (m.isUserCorrected) corrected++;
      byCategory[m.effectiveCategory] = byCategory[m.effectiveCategory]! + 1;
      byLevel[m.levelClass] = byLevel[m.levelClass]! + 1;
      final h = m.timestamp.toLocal().hour;
      byHour[h]++;
      sumByHour[h] += m.soundLevel;
    }
    final sorted = list.map((m) => m.soundLevel).toList()..sort();
    final mid = sorted.length ~/ 2;
    final median = sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;

    return MeasurementStats._(
      count: list.length,
      meanLevel: sum / list.length,
      medianLevel: median,
      maxLevel: maxL,
      minLevel: minL,
      meanConfidence: sumConf / list.length,
      uncertainShare: uncertain / list.length,
      userCorrectedShare: corrected / list.length,
      byCategory: byCategory,
      byLevelClass: byLevel,
      byHour: byHour,
      meanLevelByHour: [
        for (var h = 0; h < 24; h++)
          byHour[h] == 0 ? null : sumByHour[h] / byHour[h],
      ],
    );
  }
}
