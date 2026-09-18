import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Ergebnis einer Standortabfrage – bewusst unabhängig vom Geolocator-Typ,
/// damit die Implementierung austauschbar bleibt.
class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;

  /// Horizontale Genauigkeit in Metern.
  final double accuracy;
  final DateTime timestamp;
}

enum LocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unknown,
}

class LocationException implements Exception {
  const LocationException(this.failure, [this.detail]);

  final LocationFailure failure;
  final String? detail;

  /// Nutzerverständliche deutsche Meldung.
  String get message => switch (failure) {
        LocationFailure.serviceDisabled =>
          'Standortdienste sind deaktiviert. Bitte GPS einschalten.',
        LocationFailure.permissionDenied =>
          'Standortberechtigung wurde verweigert.',
        LocationFailure.permissionDeniedForever =>
          'Standortberechtigung dauerhaft verweigert. Bitte in den App-Einstellungen erlauben.',
        LocationFailure.timeout =>
          'Kein GPS-Fix innerhalb der Zeit. Bitte im Freien erneut versuchen.',
        LocationFailure.unknown =>
          'Standort konnte nicht ermittelt werden${detail == null ? '' : ' ($detail)'}.',
      };

  @override
  String toString() => 'LocationException(${failure.name}): $message';
}

/// Abstraktion über die Standortermittlung.
abstract class LocationService {
  /// Prüft Dienst + Berechtigung, fragt die Berechtigung bei Bedarf an
  /// und liefert eine aktuelle Position. Wirft [LocationException].
  Future<LocationFix> getCurrentFix({Duration timeout});

  /// Öffnet die App-Einstellungen (für dauerhaft verweigerte Berechtigung).
  Future<bool> openAppSettings();

  /// Öffnet die System-Standorteinstellungen.
  Future<bool> openLocationSettings();
}

/// Produktive Implementierung über das geolocator-Paket.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<LocationFix> getCurrentFix({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationFailure.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.denied:
        throw const LocationException(LocationFailure.permissionDenied);
      case LocationPermission.deniedForever:
        throw const LocationException(LocationFailure.permissionDeniedForever);
      case LocationPermission.unableToDetermine:
        throw const LocationException(
            LocationFailure.unknown, 'Berechtigungsstatus unbekannt');
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        break;
    }

    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      return LocationFix(
        latitude: p.latitude,
        longitude: p.longitude,
        accuracy: p.accuracy,
        timestamp: p.timestamp,
      );
    } on TimeoutException {
      throw const LocationException(LocationFailure.timeout);
    } on LocationServiceDisabledException {
      throw const LocationException(LocationFailure.serviceDisabled);
    } on PermissionDeniedException {
      throw const LocationException(LocationFailure.permissionDenied);
    } catch (e) {
      throw LocationException(LocationFailure.unknown, e.toString());
    }
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

/// Feste Position für Tests und Entwicklung ohne GPS.
class FakeLocationService implements LocationService {
  const FakeLocationService({
    this.latitude = 52.5200,
    this.longitude = 13.4050,
    this.accuracy = 8.0,
    this.delay = Duration.zero,
    this.failure,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final Duration delay;

  /// Wenn gesetzt, schlägt jede Abfrage mit diesem Fehler fehl.
  final LocationFailure? failure;

  @override
  Future<LocationFix> getCurrentFix({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await Future<void>.delayed(delay);
    if (failure != null) throw LocationException(failure!);
    return LocationFix(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<bool> openLocationSettings() async => false;
}
