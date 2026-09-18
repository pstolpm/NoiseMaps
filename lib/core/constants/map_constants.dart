import 'package:maplibre_gl/maplibre_gl.dart';

/// Kartenkonfiguration. Der Stil ist bewusst an einer Stelle austauschbar.
class MapConstants {
  MapConstants._();

  /// OpenFreeMap "Liberty": OSM-basierter Vektorstil, kostenlos, ohne API-Key.
  /// Quelle/Lizenz: https://openfreemap.org – Daten © OpenStreetMap-Mitwirkende.
  static const styleUrl = 'https://tiles.openfreemap.org/styles/liberty';

  /// Fallback ohne Straßen (nur Länder), falls OpenFreeMap nicht erreichbar ist.
  static const fallbackStyleUrl = 'https://demotiles.maplibre.org/style.json';

  static const berlinCenter = LatLng(52.5200, 13.4050);
  static const initialZoom = 11.0;
  static const focusZoom = 15.0;

  static const measurementsSource = 'measurements';
  static const measurementsLayer = 'measurements-circles';
  static const heatmapLayer = 'measurements-heatmap';
}
