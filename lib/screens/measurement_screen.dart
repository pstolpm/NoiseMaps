import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/noise_category.dart';
import '../models/noise_measurement.dart';
import '../repositories/measurement_repository.dart';
import '../services/location_service.dart';
import 'result_screen.dart';

/// Messbildschirm.
///
/// Phase 2: Standort wird echt über [LocationService] ermittelt (parallel
/// zum Countdown). Audio und AI sind noch simuliert und folgen in
/// späteren Phasen über eigene Services.
class MeasurementScreen extends StatefulWidget {
  const MeasurementScreen({
    super.key,
    required this.repository,
    required this.locationService,
  });

  final MeasurementRepository repository;
  final LocationService locationService;

  static const measurementDuration = Duration(seconds: 4);

  /// GPS-Genauigkeit oberhalb dieses Werts wird als "schlecht" markiert
  /// (Messung bleibt erlaubt, qualityFlag = 'low_gps_accuracy').
  static const maxGoodAccuracyMeters = 30.0;

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

enum _LocationState { idle, searching, ok, error }

class _MeasurementScreenState extends State<MeasurementScreen> {
  Timer? _timer;
  double _progress = 0;
  bool _running = false;

  _LocationState _locState = _LocationState.idle;
  LocationFix? _fix;
  LocationException? _locError;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _running = true;
      _progress = 0;
      _locState = _LocationState.searching;
      _fix = null;
      _locError = null;
    });

    // Standort und (simulierter) Audio-Countdown laufen parallel.
    final locationFuture = _fetchLocation();
    final audioFuture = _runCountdown();
    await Future.wait([locationFuture, audioFuture]);
    if (!mounted) return;

    if (_fix == null) {
      // Ohne Position keine Messung (Project Brain, Abschnitt 9).
      setState(() => _running = false);
      return;
    }
    _finish(_fix!);
  }

  Future<void> _fetchLocation() async {
    try {
      final fix = await widget.locationService.getCurrentFix();
      if (!mounted) return;
      setState(() {
        _fix = fix;
        _locState = _LocationState.ok;
      });
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _locError = e;
        _locState = _LocationState.error;
      });
    }
  }

  Future<void> _runCountdown() {
    final completer = Completer<void>();
    const tick = Duration(milliseconds: 50);
    final totalTicks =
        MeasurementScreen.measurementDuration.inMilliseconds / tick.inMilliseconds;
    var ticks = 0;
    _timer = Timer.periodic(tick, (t) {
      ticks++;
      if (mounted) setState(() => _progress = min(1, ticks / totalTicks));
      if (ticks >= totalTicks) {
        t.cancel();
        completer.complete();
      }
    });
    return completer.future;
  }

  void _finish(LocationFix fix) {
    final rnd = Random();
    final cats = NoiseCategory.values;
    final measurement = NoiseMeasurement(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      latitude: fix.latitude,
      longitude: fix.longitude,
      timestamp: DateTime.now(),
      soundLevel: 40 + rnd.nextDouble() * 45, // simuliert (Phase 3)
      aiCategory: cats[rnd.nextInt(cats.length)], // simuliert (Phase 4)
      aiConfidence: 0.3 + rnd.nextDouble() * 0.65, // simuliert (Phase 4)
      gpsAccuracy: fix.accuracy,
      durationSeconds: MeasurementScreen.measurementDuration.inSeconds,
      qualityFlag: fix.accuracy > MeasurementScreen.maxGoodAccuracyMeters
          ? 'low_gps_accuracy'
          : 'valid',
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          measurement: measurement,
          repository: widget.repository,
        ),
      ),
    );
  }

  String get _locationLabel => switch (_locState) {
        _LocationState.idle => 'bereit',
        _LocationState.searching => 'wird ermittelt …',
        _LocationState.ok => '± ${_fix!.accuracy.toStringAsFixed(0)} m',
        _LocationState.error => 'Fehler',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining =
        (MeasurementScreen.measurementDuration.inSeconds * (1 - _progress)).ceil();
    final waitingForGps = _running && _progress >= 1 && _locState == _LocationState.searching;

    return Scaffold(
      appBar: AppBar(title: const Text('Messung')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: waitingForGps ? null : (_running ? _progress : 0),
                      strokeWidth: 10,
                    ),
                    Center(
                      child: Text(
                        !_running
                            ? 'Bereit'
                            : waitingForGps
                                ? 'GPS …'
                                : '$remaining s',
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _StatusRow(
                icon: Icons.location_on,
                label: 'Standort',
                value: _locationLabel,
                color: _locState == _LocationState.error
                    ? theme.colorScheme.error
                    : null,
              ),
              const _StatusRow(icon: Icons.mic, label: 'Mikrofon', value: 'simuliert'),
              const SizedBox(height: 24),
              if (_locError != null) _ErrorBox(error: _locError!, service: widget.locationService),
              const SizedBox(height: 8),
              if (!_running)
                FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(_locError == null ? 'Aufnahme starten' : 'Erneut versuchen'),
                )
              else
                Text(waitingForGps ? 'Warte auf GPS-Position …' : 'Bitte ruhig halten …'),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text('$label: $value', style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.error, required this.service});

  final LocationException error;
  final LocationService service;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final VoidCallback? action = switch (error.failure) {
      LocationFailure.serviceDisabled => service.openLocationSettings,
      LocationFailure.permissionDeniedForever => service.openAppSettings,
      _ => null,
    };
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(error.message, style: TextStyle(color: scheme.onErrorContainer)),
            if (action != null)
              TextButton(
                onPressed: action,
                child: const Text('Einstellungen öffnen'),
              ),
          ],
        ),
      ),
    );
  }
}
