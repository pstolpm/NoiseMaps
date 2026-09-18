import 'dart:math' show Point;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../core/constants/map_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/measurement_filter.dart';
import '../models/noise_category.dart';
import '../models/noise_measurement.dart';
import '../repositories/measurement_repository.dart';
import '../services/location_service.dart';
import '../widgets/map_filter_sheet.dart';
import '../widgets/measurement_card.dart';
import '../widgets/noise_legend.dart';

/// Kartenansicht: MapLibre mit Messpunkten als GeoJSON-Kreisen,
/// eingefärbt nach Geräuschklasse. Tap auf einen Punkt öffnet ein Bottom Sheet.
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.repository,
    required this.locationService,
  });

  final MeasurementRepository repository;
  final LocationService locationService;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapLibreMapController? _controller;
  bool _styleLoaded = false;
  bool _locating = false;
  MeasurementFilter _filter = MeasurementFilter.none;

  List<NoiseMeasurement> get _visible => _filter.apply(widget.repository.all);

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() => _pushData();

  Future<void> _onStyleLoaded() async {
    final c = _controller;
    if (c == null) return;

    await c.addSource(
      MapConstants.measurementsSource,
      GeojsonSourceProperties(data: _toGeoJson(_visible)),
    );

    // Farbe je Klasse aus dem Theme, damit Karte und Listen übereinstimmen.
    final colorExpr = <dynamic>['match', <dynamic>['get', 'category']];
    for (final cat in NoiseCategory.values) {
      colorExpr
        ..add(cat.key)
        ..add(AppTheme.toHex(AppTheme.categoryColor(cat)));
    }
    colorExpr.add(AppTheme.toHex(AppTheme.categoryColor(NoiseCategory.uncertain)));

    await c.addCircleLayer(
      MapConstants.measurementsSource,
      MapConstants.measurementsLayer,
      CircleLayerProperties(
        circleColor: colorExpr,
        // Radius wächst leicht mit dem Pegel (40 dB -> 6 px, 90 dB -> 12 px).
        circleRadius: <dynamic>[
          'interpolate',
          <dynamic>['linear'],
          <dynamic>['get', 'soundLevel'],
          40, 6,
          90, 12,
        ],
        circleOpacity: 0.85,
        circleStrokeColor: '#ffffff',
        circleStrokeWidth: 1.5,
      ),
    );

    c.onFeatureTapped.add(_onFeatureTapped);
    setState(() => _styleLoaded = true);
  }

  Future<void> _pushData() async {
    final c = _controller;
    if (c == null || !_styleLoaded) return;
    await c.setGeoJsonSource(
      MapConstants.measurementsSource,
      _toGeoJson(_visible),
    );
  }

  void _openFilter() {
    MapFilterSheet.show(
      context,
      initial: _filter,
      onChanged: (f) {
        setState(() => _filter = f);
        _pushData();
      },
    );
  }

  static Map<String, dynamic> _toGeoJson(List<NoiseMeasurement> items) => {
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
                'id': m.id,
                'category': m.effectiveCategory.key,
                'soundLevel': m.soundLevel,
              },
            },
        ],
      };

  void _onFeatureTapped(
    Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (layerId != MapConstants.measurementsLayer) return;
    final m = widget.repository.all.where((x) => x.id == id).firstOrNull;
    if (m == null) return;
    _showDetails(m);
  }

  void _showDetails(NoiseMeasurement m) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MeasurementCard(measurement: m),
            if (m.qualityFlag != 'valid')
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 8),
                child: Text('Qualität: ${m.qualityFlag}',
                    style: Theme.of(ctx).textTheme.bodySmall),
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                await widget.repository.remove(m.id);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Messung löschen'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _goToMyLocation() async {
    final c = _controller;
    if (c == null || _locating) return;
    setState(() => _locating = true);
    try {
      final fix = await widget.locationService.getCurrentFix();
      await c.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(fix.latitude, fix.longitude),
          MapConstants.focusZoom,
        ),
        duration: const Duration(milliseconds: 600),
      );
    } on LocationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Karte'),
        actions: [
          IconButton(
            tooltip: 'Filter',
            onPressed: _openFilter,
            icon: Badge(
              isLabelVisible: _filter.isActive,
              label: Text('${_filter.activeCount}'),
              child: const Icon(Icons.filter_list),
            ),
          ),
          if (kDebugMode)
            PopupMenuButton<String>(
              tooltip: 'Debug',
              onSelected: (v) async {
                if (v == 'sample') await widget.repository.addSampleData();
                if (v == 'clear') await widget.repository.clear();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'sample', child: Text('Beispieldaten laden')),
                PopupMenuItem(value: 'clear', child: Text('Alle Messungen löschen')),
              ],
            ),
        ],
      ),
      body: Stack(
        children: [
          MapLibreMap(
            styleString: MapConstants.styleUrl,
            initialCameraPosition: const CameraPosition(
              target: MapConstants.berlinCenter,
              zoom: MapConstants.initialZoom,
            ),
            myLocationEnabled: true,
            trackCameraPosition: true,
            onMapCreated: (c) => _controller = c,
            onStyleLoadedCallback: _onStyleLoaded,
            attributionButtonPosition: AttributionButtonPosition.bottomLeft,
          ),
          const Positioned(top: 12, left: 12, child: NoiseLegend()),
          Positioned(
            right: 12,
            bottom: 24,
            child: ListenableBuilder(
              listenable: widget.repository,
              builder: (_, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text(_filter.isActive
                          ? '${_visible.length} von ${widget.repository.all.length} Messungen'
                          : '${widget.repository.all.length} Messungen'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    onPressed: _goToMyLocation,
                    tooltip: 'Zu meinem Standort',
                    child: _locating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
