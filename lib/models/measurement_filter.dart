import 'noise_category.dart';
import 'noise_level_class.dart';
import 'noise_measurement.dart';

enum TimeRangeFilter { all, today }

/// Unveränderliches Filter-Wertobjekt für die Kartenansicht.
/// Leere Mengen bedeuten "keine Einschränkung".
class MeasurementFilter {
  const MeasurementFilter({
    this.categories = const {},
    this.levelClasses = const {},
    this.timeRange = TimeRangeFilter.all,
  });

  final Set<NoiseCategory> categories;
  final Set<NoiseLevelClass> levelClasses;
  final TimeRangeFilter timeRange;

  static const none = MeasurementFilter();

  bool get isActive =>
      categories.isNotEmpty ||
      levelClasses.isNotEmpty ||
      timeRange != TimeRangeFilter.all;

  int get activeCount =>
      (categories.isNotEmpty ? 1 : 0) +
      (levelClasses.isNotEmpty ? 1 : 0) +
      (timeRange != TimeRangeFilter.all ? 1 : 0);

  MeasurementFilter copyWith({
    Set<NoiseCategory>? categories,
    Set<NoiseLevelClass>? levelClasses,
    TimeRangeFilter? timeRange,
  }) {
    return MeasurementFilter(
      categories: categories ?? this.categories,
      levelClasses: levelClasses ?? this.levelClasses,
      timeRange: timeRange ?? this.timeRange,
    );
  }

  bool matches(NoiseMeasurement m, {DateTime? now}) {
    if (categories.isNotEmpty && !categories.contains(m.effectiveCategory)) {
      return false;
    }
    if (levelClasses.isNotEmpty && !levelClasses.contains(m.levelClass)) {
      return false;
    }
    if (timeRange == TimeRangeFilter.today) {
      final n = (now ?? DateTime.now()).toLocal();
      final t = m.timestamp.toLocal();
      if (t.year != n.year || t.month != n.month || t.day != n.day) return false;
    }
    return true;
  }

  List<NoiseMeasurement> apply(Iterable<NoiseMeasurement> items, {DateTime? now}) =>
      items.where((m) => matches(m, now: now)).toList();
}
