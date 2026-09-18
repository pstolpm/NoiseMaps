import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../repositories/measurement_repository.dart';
import '../widgets/measurement_card.dart';

/// Platzhalter für die Kartenansicht. In Phase 6 wird hier MapLibre
/// eingebunden; bis dahin zeigt die Seite alle Messungen als Liste,
/// damit Speichern/Löschen bereits testbar ist.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key, required this.repository});

  final MeasurementRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Karte (Platzhalter)'),
        actions: [
          if (kDebugMode)
            PopupMenuButton<String>(
              tooltip: 'Debug',
              onSelected: (v) async {
                if (v == 'sample') await repository.addSampleData();
                if (v == 'clear') await repository.clear();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'sample', child: Text('Beispieldaten laden')),
                PopupMenuItem(value: 'clear', child: Text('Alle Messungen löschen')),
              ],
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: repository,
        builder: (context, _) {
          final items = repository.all.toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
          if (items.isEmpty) {
            return const Center(child: Text('Keine Messungen vorhanden.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final m = items[i];
              return Dismissible(
                key: ValueKey(m.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: const Icon(Icons.delete),
                ),
                onDismissed: (_) => repository.remove(m.id),
                child: MeasurementCard(measurement: m),
              );
            },
          );
        },
      ),
    );
  }
}
