import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/noise_category.dart';
import '../models/noise_measurement.dart';
import '../repositories/measurement_repository.dart';
import '../services/audio_service.dart';
import '../services/location_service.dart';
import '../services/sound_level_service.dart';
import 'result_screen.dart';

/// Messbildschirm.
///
/// Phase 3: Standort (LocationService) und Audio (AudioService) laufen
/// parallel; der Pegel kommt aus SoundLevelService. Die AI-Klasse ist
/// noch simuliert und folgt in Phase 4 über AiClassificationService.
class MeasurementScreen extends StatefulWidget {
  const MeasurementScreen({
    super.key,
    required this.repository,
    required this.locationService,
    required this.audioService,
    this.soundLevelService = const SoundLevelService(),
  });

  final MeasurementRepository repository;
  final LocationService locationService;
  final AudioService audioService;
  final SoundLevelService soundLevelService;

  static const measurementDuration = Duration(seconds: 4);

  /// GPS-Genauigkeit oberhalb dieses Werts wird markiert
  /// (Messung bleibt erlaubt, qualityFlag = 'low_gps_accuracy').
  static const maxGoodAccuracyMeters = 30.0;

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

enum _Status { idle, working, ok, error }

class _MeasurementScreenState extends State<MeasurementScreen> {
  bool _running = false;
  double _progress = 0;

  _Status _locStatus = _Status.idle;
  LocationFix? _fix;
  LocationException? _locError;

  _Status _micStatus = _Status.idle;
  double? _liveDbfs;
  SoundLevelResult? _level;
  AudioException? _audioError;

  Future<void> _start() async {
    setState(() {
      _running = true;
      _progress = 0;
      _locStatus = _Status.working;
      _micStatus = _Status.working;
      _fix = null;
      _locError = null;
      _level = null;
      _liveDbfs = null;
      _audioError = null;
    });

    await Future.wait([_fetchLocation(), _recordAudio()]);
    if (!mounted) return;

    if (_fix == null || _level == null) {
      // Ohne Position oder ohne Audio keine Messung (Project Brain, Abschnitt 9).
      setState(() => _running = false);
      return;
    }
    _finish(_fix!, _level!);
  }

  Future<void> _fetchLocation() async {
    try {
      final fix = await widget.locationService.getCurrentFix();
      if (!mounted) return;
      setState(() {
        _fix = fix;
        _locStatus = _Status.ok;
      });
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _locError = e;
        _locStatus = _Status.error;
      });
    }
  }

  Future<void> _recordAudio() async {
    try {
      final sample = await widget.audioService.recordSample(
        duration: MeasurementScreen.measurementDuration,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onLiveLevel: (dbfs) {
          if (mounted) setState(() => _liveDbfs = dbfs);
        },
      );
      final level = widget.soundLevelService.analyze(sample);
      // `sample` wird hier verworfen – kein Roh-Audio bleibt erhalten.
      if (!mounted) return;
      setState(() {
        _level = level;
        _micStatus = _Status.ok;
        _progress = 1;
      });
    } on AudioException catch (e) {
      if (!mounted) return;
      setState(() {
        _audioError = e;
        _micStatus = _Status.error;
      });
    }
  }

  void _finish(LocationFix fix, SoundLevelResult level) {
    final rnd = Random();
    final cats = NoiseCategory.values;
    final flags = <String>[
      if (fix.accuracy > MeasurementScreen.maxGoodAccuracyMeters) 'low_gps_accuracy',
      if (level.isClipping) 'clipping',
    ];
    final measurement = NoiseMeasurement(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      latitude: fix.latitude,
      longitude: fix.longitude,
      timestamp: DateTime.now(),
      soundLevel: double.parse(level.indicativeDb.toStringAsFixed(1)),
      aiCategory: cats[rnd.nextInt(cats.length)], // simuliert (Phase 4)
      aiConfidence: 0.3 + rnd.nextDouble() * 0.65, // simuliert (Phase 4)
      gpsAccuracy: fix.accuracy,
      durationSeconds: MeasurementScreen.measurementDuration.inSeconds,
      qualityFlag: flags.isEmpty ? 'valid' : flags.join(','),
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

  String get _locLabel => switch (_locStatus) {
        _Status.idle => 'bereit',
        _Status.working => 'wird ermittelt …',
        _Status.ok => '± ${_fix!.accuracy.toStringAsFixed(0)} m',
        _Status.error => 'Fehler',
      };

  String get _micLabel => switch (_micStatus) {
        _Status.idle => 'bereit',
        _Status.working => _liveDbfs == null
            ? 'nimmt auf …'
            : 'live ${(_liveDbfs! + widget.soundLevelService.calibrationOffsetDb).clamp(0, 140).toStringAsFixed(0)} dB'
                ' (${_liveDbfs!.toStringAsFixed(0)} dBFS)',
        _Status.ok => '${_level!.indicativeDb.toStringAsFixed(1)} dB'
            ' (${_level!.rmsDbfs.toStringAsFixed(0)} dBFS)',
        _Status.error => 'Fehler',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;
    final audioDone = _micStatus != _Status.working;
    final waitingForGps = _running && audioDone && _locStatus == _Status.working;
    final remaining =
        (MeasurementScreen.measurementDuration.inSeconds * (1 - _progress)).ceil();
    final hasError = _locError != null || _audioError != null;

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
                value: _locLabel,
                color: _locStatus == _Status.error ? errorColor : null,
              ),
              _StatusRow(
                icon: Icons.mic,
                label: 'Mikrofon',
                value: _micLabel,
                color: _micStatus == _Status.error ? errorColor : null,
              ),
              const SizedBox(height: 24),
              if (_locError != null)
                _ErrorBox(
                  message: _locError!.message,
                  onSettings: switch (_locError!.failure) {
                    LocationFailure.serviceDisabled =>
                      widget.locationService.openLocationSettings,
                    LocationFailure.permissionDeniedForever =>
                      widget.locationService.openAppSettings,
                    _ => null,
                  },
                ),
              if (_audioError != null)
                _ErrorBox(
                  message: _audioError!.message,
                  onSettings: _audioError!.failure == AudioFailure.permissionDenied
                      ? widget.locationService.openAppSettings
                      : null,
                ),
              const SizedBox(height: 8),
              if (!_running)
                FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(hasError ? 'Erneut versuchen' : 'Aufnahme starten'),
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
  const _ErrorBox({required this.message, this.onSettings});

  final String message;
  final Future<bool> Function()? onSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(message, style: TextStyle(color: scheme.onErrorContainer)),
            if (onSettings != null)
              TextButton(
                onPressed: onSettings,
                child: const Text('Einstellungen öffnen'),
              ),
          ],
        ),
      ),
    );
  }
}
