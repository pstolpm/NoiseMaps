import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/measurement_filter.dart';
import '../models/noise_category.dart';
import '../models/noise_level_class.dart';

/// Bottom Sheet zur Filterauswahl. Gibt den neuen Filter über [onChanged]
/// sofort zurück, damit die Karte live reagiert.
class MapFilterSheet extends StatefulWidget {
  const MapFilterSheet({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  final MeasurementFilter initial;
  final ValueChanged<MeasurementFilter> onChanged;

  static Future<void> show(
    BuildContext context, {
    required MeasurementFilter initial,
    required ValueChanged<MeasurementFilter> onChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => MapFilterSheet(initial: initial, onChanged: onChanged),
    );
  }

  @override
  State<MapFilterSheet> createState() => _MapFilterSheetState();
}

class _MapFilterSheetState extends State<MapFilterSheet> {
  late MeasurementFilter _filter = widget.initial;

  void _update(MeasurementFilter f) {
    setState(() => _filter = f);
    widget.onChanged(f);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Filter', style: theme.textTheme.titleLarge),
              const Spacer(),
              TextButton(
                onPressed: _filter.isActive
                    ? () => _update(MeasurementFilter.none)
                    : null,
                child: const Text('Zurücksetzen'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Geräuschklasse', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final c in NoiseCategory.values)
                FilterChip(
                  label: Text(c.label),
                  avatar: Icon(AppTheme.categoryIcon(c), size: 18),
                  selected: _filter.categories.contains(c),
                  onSelected: (sel) {
                    final s = {..._filter.categories};
                    sel ? s.add(c) : s.remove(c);
                    _update(_filter.copyWith(categories: s));
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Pegelklasse (indikativ)', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final l in NoiseLevelClass.values)
                FilterChip(
                  label: Text('${l.label} · ${l.rangeLabel}'),
                  avatar: CircleAvatar(
                    backgroundColor: AppTheme.levelColor(l),
                    radius: 6,
                  ),
                  selected: _filter.levelClasses.contains(l),
                  onSelected: (sel) {
                    final s = {..._filter.levelClasses};
                    sel ? s.add(l) : s.remove(l);
                    _update(_filter.copyWith(levelClasses: s));
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Zeitraum', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          SegmentedButton<TimeRangeFilter>(
            segments: const [
              ButtonSegment(value: TimeRangeFilter.all, label: Text('Alle')),
              ButtonSegment(value: TimeRangeFilter.today, label: Text('Heute')),
            ],
            selected: {_filter.timeRange},
            onSelectionChanged: (s) =>
                _update(_filter.copyWith(timeRange: s.first)),
          ),
        ],
      ),
    );
  }
}
