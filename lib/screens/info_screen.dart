import 'package:flutter/material.dart';

import '../services/ai_classification_service.dart';

/// Info-Bereich mit drei Reitern: Über, FAQ, Datenschutz & Quellen.
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key, required this.aiService});

  final AiClassificationService aiService;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Info'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Über'),
            Tab(text: 'FAQ'),
            Tab(text: 'Datenschutz & Quellen'),
          ]),
        ),
        body: TabBarView(children: [
          _AboutTab(aiService: aiService),
          const _FaqTab(),
          const _PrivacyTab(),
        ]),
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.aiService});

  final AiClassificationService aiService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('NoiseMaps', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Crowd-basierte, indikative Erfassung und Visualisierung urbaner Lärmbelastung.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        Text('So funktioniert eine Messung', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        const _Step(n: 1, text: 'Die App nimmt 4 Sekunden Audio über das Mikrofon auf (16 kHz, mono).'),
        const _Step(n: 2, text: 'Aus dem Signal wird ein indikativer Pegel (RMS in dBFS + fester Offset) berechnet.'),
        const _Step(n: 3, text: 'Ein lokales KI-Modell (YAMNet, TensorFlow Lite) klassifiziert die Geräuschquelle. 521 Originalklassen werden auf Verkehr, Baustelle/Maschinen, Menschen, Natur und „unsicher“ abgebildet.'),
        const _Step(n: 4, text: 'Parallel wird die GPS-Position inkl. Genauigkeit ermittelt.'),
        const _Step(n: 5, text: 'Du prüfst das Ergebnis, kannst die Klasse korrigieren und speicherst die Messung lokal.'),
        const _Step(n: 6, text: 'Die Karte zeigt alle Messungen als Punkte oder Heatmap, filterbar und exportierbar (GeoJSON, CSV).'),
        const SizedBox(height: 16),
        Text('Technik', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text('Flutter/Dart · MapLibre GL · TensorFlow Lite · SQLite\n'
            'KI-Modell aktiv: ${aiService.name}\n'
            'Unsicher-Schwelle: Confidence < ${(AiClassificationService.uncertainThreshold * 100).round()} %'),
        const SizedBox(height: 16),
        Text('Projekt', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        const Text('Studienprojekt im Master Geoinformation, Berliner Hochschule für Technik (BHT), '
            'Kurs Automatisierte Geodatenprozessierung.'),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});

  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            child: Text('$n', style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _FaqTab extends StatelessWidget {
  const _FaqTab();

  static const _items = <(String, String)>[
    (
      'Wie genau ist der gemessene Pegel?',
      'Nur indikativ. Smartphone-Mikrofone sind nicht kalibriert, ihr Frequenzgang und '
          'ihre Empfindlichkeit unterscheiden sich je nach Gerät. Der angezeigte dB-Wert ist '
          'der digitale Effektivwert (dBFS) plus ein fester Offset. Er eignet sich für '
          'Vergleiche zwischen Orten und Zeiten, nicht für amtliche Aussagen.'
    ),
    (
      'Warum steht bei manchen Messungen „unsicher“?',
      'Die KI liefert für jede Klasse eine Wahrscheinlichkeit. Liegt die beste Zielklasse '
          'unter 40 %, wird die Messung als „unsicher“ markiert, statt eine schwache Vermutung '
          'als Fakt darzustellen. Häufige Gründe: sehr leise Umgebung, Mischgeräusche oder '
          'Geräusche, die das Modell nicht kennt. Du kannst die Klasse im Ergebnis manuell setzen.'
    ),
    (
      'Was passiert mit der Tonaufnahme?',
      'Sie bleibt nur wenige Sekunden im Arbeitsspeicher, wird für Pegel und Klassifikation '
          'ausgewertet und dann verworfen. Es wird keine Audiodatei gespeichert oder übertragen.'
    ),
    (
      'Braucht die App Internet?',
      'Messen, Klassifizieren und Speichern funktionieren vollständig offline. Nur die '
          'Kartenkacheln (OpenFreeMap) werden aus dem Internet geladen; ohne Verbindung '
          'bleibt die Karte leer, die Messpunkte werden aber weiterhin gespeichert.'
    ),
    (
      'Warum ist die Messung 4 Sekunden lang?',
      'Das KI-Modell arbeitet mit Fenstern von knapp einer Sekunde. Vier Sekunden liefern '
          'mehrere Fenster, deren Ergebnisse gemittelt werden – das ist stabiler als ein '
          'einzelnes Fenster, aber noch kurz genug für eine schnelle Messung.'
    ),
    (
      'Was bedeutet die GPS-Genauigkeit?',
      'Der Wert (± m) ist die vom Gerät geschätzte horizontale Unsicherheit. Über 30 m wird '
          'die Messung mit „low_gps_accuracy“ markiert; sie bleibt gespeichert, sollte aber '
          'bei Auswertungen mit Vorsicht behandelt werden. Im Freien ist die Genauigkeit meist besser.'
    ),
    (
      'Kann ich mehrfach am selben Ort messen?',
      'Ja, ausdrücklich. Lärm ändert sich mit der Tageszeit; mehrere Messungen am selben '
          'Ort zu verschiedenen Zeiten sind wertvoller als eine einzelne.'
    ),
    (
      'Wie bekomme ich die Daten in QGIS?',
      'Karte → Export → GeoJSON. Die Datei enthält alle Messungen (bzw. die gefilterten) '
          'in WGS84 mit allen Attributen und lässt sich direkt in QGIS ziehen. CSV eignet sich '
          'für Tabellenkalkulationen.'
    ),
    (
      'Wird das Modell auf dem Gerät ausgeführt?',
      'Ja. YAMNet läuft als TensorFlow-Lite-Modell lokal auf dem Smartphone. Es werden keine '
          'Audiodaten an einen Server gesendet.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final (q, a) in _items)
          ExpansionTile(
            title: Text(q, style: const TextStyle(fontWeight: FontWeight.w600)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [Text(a)],
          ),
      ],
    );
  }
}

class _PrivacyTab extends StatelessWidget {
  const _PrivacyTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Datenschutz', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        const Text(
          '• Roh-Audio wird nach der Auswertung sofort verworfen und nie gespeichert.\n'
          '• Die KI-Klassifikation läuft ausschließlich auf dem Gerät.\n'
          '• Messungen werden nur lokal in einer Datenbank auf dem Gerät gespeichert.\n'
          '• Es gibt keine Benutzerkonten, keine Nutzer-IDs und keine Bewegungsprofile – '
          'jede Messung ist ein einzelner, unabhängiger Punkt.\n'
          '• Standort- und Mikrofonzugriff erfolgen nur während einer aktiven Messung.\n'
          '• Ein Export geschieht nur, wenn du ihn selbst auslöst.',
        ),
        const SizedBox(height: 20),
        Text('Quellen & Lizenzen', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        const _Source(
          name: 'YAMNet (TensorFlow Lite)',
          detail: 'Google Research, Audio-Klassifikationsmodell auf Basis von AudioSet. '
              'Apache License 2.0. Bezogen über MediaPipe Models.',
        ),
        const _Source(
          name: 'AudioSet-Klassenliste (yamnet_class_map.csv)',
          detail: 'tensorflow/models, Apache License 2.0.',
        ),
        const _Source(
          name: 'Kartenstil „Liberty“ und Kacheln',
          detail: 'OpenFreeMap (openfreemap.org). Kartendaten © OpenStreetMap-Mitwirkende, ODbL.',
        ),
        const _Source(
          name: 'MapLibre GL',
          detail: 'maplibre_gl für Flutter, BSD-Lizenz.',
        ),
        const _Source(
          name: 'Schrift Inter',
          detail: 'Rasmus Andersson, SIL Open Font License 1.1.',
        ),
        const _Source(
          name: 'Flutter-Pakete',
          detail: 'geolocator, record, tflite_flutter, sqflite, share_plus – jeweils MIT/BSD/Apache.',
        ),
      ],
    );
  }
}

class _Source extends StatelessWidget {
  const _Source({required this.name, required this.detail});

  final String name;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(detail, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
