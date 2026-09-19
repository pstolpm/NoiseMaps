# NoiseMaps

Mobile GeoIT-App zur crowd-basierten, **indikativen** Erfassung und Visualisierung urbaner Lärmbelastung.

Studienprojekt im Master Geoinformation, BHT Berlin – Kurs GeoIT / Automatisierte Geodatenprozessierung (Prof. Wagner).

## Was die App tut

1. nimmt für wenige Sekunden Audio über das Smartphone-Mikrofon auf,
2. berechnet daraus einen indikativen Geräuschpegel,
3. klassifiziert die Geräuschquelle mit einem lokalen AI-Modell (Verkehr, Baustelle/Maschinen, Menschen, Natur, unsicher),
4. verortet die Messung per GPS,
5. speichert Messung und AI-Ergebnis lokal,
6. zeigt Messpunkte auf einer MapLibre-Karte.

**Hinweis:** NoiseMaps ist keine amtliche Schallpegelmessung. Smartphone-Mikrofone sind nicht kalibriert; alle Pegelwerte sind indikativ. Roh-Audio wird nach der Auswertung verworfen und nicht gespeichert.

## Stack

Flutter / Dart · Android (primäre Zielplattform) · MapLibre GL · TensorFlow Lite (on-device) · lokale Persistenz

## Entwicklung

Voraussetzungen: Flutter (stable), Android SDK inkl. NDK, ein Android-Emulator oder physisches Gerät.

```bash
flutter pub get
flutter run
```

Release-APK:

```bash
flutter build apk --release
```

Ergebnis: `build/app/outputs/flutter-apk/app-release.apk`

## Projektstruktur

Siehe `lib/` – Aufbau nach Screens, Models, Services und Repositories (wird schrittweise ergänzt).

## Status

Phase 0 – Projekt-Setup. Die App-Funktionen werden inkrementell umgesetzt.
