import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/noise_category.dart';
import '../models/noise_measurement.dart';
import '../repositories/measurement_repository.dart';
import 'result_screen.dart';

/// Messbildschirm. Im Skelett wird die Messung simuliert:
/// 4 Sekunden Fortschritt, danach ein zufälliges Dummy-Ergebnis.
/// Audio, GPS und AI werden in späteren Phasen über Services eingehängt.
class MeasurementScreen extends StatefulWidget {
  const MeasurementScreen({super.key, required this.repository});

  final MeasurementRepository repository;

  static const measurementDuration = Duration(seconds: 4);

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> {
  Timer? _timer;
  double _progress = 0;
  bool _running = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _running = true;
      _progress = 0;
    });
    const tick = Duration(milliseconds: 50);
    final totalTicks =
        MeasurementScreen.measurementDuration.inMilliseconds / tick.inMilliseconds;
    var ticks = 0;
    _timer = Timer.periodic(tick, (t) {
      ticks++;
      setState(() => _progress = min(1, ticks / totalTicks));
      if (ticks >= totalTicks) {
        t.cancel();
        _finish();
      }
    });
  }

  void _finish() {
    final rnd = Random();
    final cats = NoiseCategory.values;
    final measurement = NoiseMeasurement(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      latitude: 52.52 + (rnd.nextDouble() - 0.5) * 0.02,
      longitude: 13.40 + (rnd.nextDouble() - 0.5) * 0.03,
      timestamp: DateTime.now(),
      soundLevel: 40 + rnd.nextDouble() * 45,
      aiCategory: cats[rnd.nextInt(cats.length)],
      aiConfidence: 0.3 + rnd.nextDouble() * 0.65,
      gpsAccuracy: 5 + rnd.nextDouble() * 20,
      durationSeconds: MeasurementScreen.measurementDuration.inSeconds,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          measurement: measurement,
          repository: widget.repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = (MeasurementScreen.measurementDuration.inSeconds * (1 - _progress))
        .ceil();
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
                      value: _running ? _progress : 0,
                      strokeWidth: 10,
                    ),
                    Center(
                      child: Text(
                        _running ? '$remaining s' : 'Bereit',
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _StatusRow(icon: Icons.location_on, label: 'Standort', value: 'simuliert'),
              _StatusRow(icon: Icons.mic, label: 'Mikrofon', value: 'simuliert'),
              const SizedBox(height: 32),
              if (!_running)
                FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Aufnahme starten'),
                )
              else
                const Text('Bitte ruhig halten …'),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text('$label: $value'),
        ],
      ),
    );
  }
}
