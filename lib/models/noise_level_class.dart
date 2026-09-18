/// Indikative Pegelklassen. Die Grenzen sind bewusst grob, da
/// Smartphone-Mikrofone nicht kalibriert sind.
enum NoiseLevelClass {
  quiet('quiet', 'Leise', '< 50 dB'),
  moderate('moderate', 'Mäßig', '50–65 dB'),
  loud('loud', 'Laut', '65–80 dB'),
  veryLoud('very_loud', 'Sehr laut', '> 80 dB');

  const NoiseLevelClass(this.key, this.label, this.rangeLabel);

  final String key;
  final String label;
  final String rangeLabel;

  static NoiseLevelClass fromLevel(double dB) {
    if (dB < 50) return NoiseLevelClass.quiet;
    if (dB < 65) return NoiseLevelClass.moderate;
    if (dB < 80) return NoiseLevelClass.loud;
    return NoiseLevelClass.veryLoud;
  }

  static NoiseLevelClass fromKey(String? key) {
    return values.firstWhere(
      (c) => c.key == key,
      orElse: () => NoiseLevelClass.moderate,
    );
  }
}
