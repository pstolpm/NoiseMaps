/// Grobe Zielklassen der Geräuschquelle (siehe Project Brain, Abschnitt 4.3).
///
/// Die Originalklassen eines Modells wie YAMNet werden später auf diese
/// Klassen gemappt. `key` ist der stabile Speicher-/Export-Schlüssel,
/// `label` die deutsche Anzeige.
enum NoiseCategory {
  traffic('traffic', 'Verkehr'),
  construction('construction', 'Baustelle / Maschinen'),
  people('people', 'Menschen / urbane Aktivität'),
  nature('nature', 'Natur'),
  uncertain('uncertain', 'Unsicher');

  const NoiseCategory(this.key, this.label);

  final String key;
  final String label;

  static NoiseCategory fromKey(String? key) {
    return values.firstWhere(
      (c) => c.key == key,
      orElse: () => NoiseCategory.uncertain,
    );
  }
}
