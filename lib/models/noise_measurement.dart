import 'noise_category.dart';
import 'noise_level_class.dart';

/// Ein einzelner Messpunkt (Project Brain, Abschnitt 8).
///
/// Pflichtfelder: id, latitude, longitude, timestamp, soundLevel,
/// aiCategory, aiConfidence. Alle anderen Felder sind optional.
class NoiseMeasurement {
  const NoiseMeasurement({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.soundLevel,
    required this.aiCategory,
    required this.aiConfidence,
    this.gpsAccuracy,
    this.userCategory,
    this.isUserCorrected = false,
    this.deviceModel,
    this.osmRoadClass,
    this.durationSeconds,
    this.qualityFlag = 'valid',
  });

  final String id;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  /// Indikativer Pegel in dB (unkalibriert).
  final double soundLevel;
  final NoiseCategory aiCategory;

  /// 0.0 – 1.0
  final double aiConfidence;

  /// Horizontale GPS-Genauigkeit in Metern, falls bekannt.
  final double? gpsAccuracy;
  final NoiseCategory? userCategory;
  final bool isUserCorrected;
  final String? deviceModel;
  final String? osmRoadClass;
  final int? durationSeconds;
  final String qualityFlag;

  /// Nutzerkorrektur hat Vorrang vor der AI-Klasse.
  NoiseCategory get effectiveCategory => userCategory ?? aiCategory;

  NoiseLevelClass get levelClass => NoiseLevelClass.fromLevel(soundLevel);

  NoiseMeasurement copyWith({
    NoiseCategory? userCategory,
    bool? isUserCorrected,
    String? osmRoadClass,
    String? qualityFlag,
  }) {
    return NoiseMeasurement(
      id: id,
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
      soundLevel: soundLevel,
      aiCategory: aiCategory,
      aiConfidence: aiConfidence,
      gpsAccuracy: gpsAccuracy,
      userCategory: userCategory ?? this.userCategory,
      isUserCorrected: isUserCorrected ?? this.isUserCorrected,
      deviceModel: deviceModel,
      osmRoadClass: osmRoadClass ?? this.osmRoadClass,
      durationSeconds: durationSeconds,
      qualityFlag: qualityFlag ?? this.qualityFlag,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
        'soundLevel': soundLevel,
        'aiCategory': aiCategory.key,
        'aiConfidence': aiConfidence,
        'gpsAccuracy': gpsAccuracy,
        'userCategory': userCategory?.key,
        'isUserCorrected': isUserCorrected,
        'deviceModel': deviceModel,
        'osmRoadClass': osmRoadClass,
        'durationSeconds': durationSeconds,
        'qualityFlag': qualityFlag,
      };

  factory NoiseMeasurement.fromJson(Map<String, dynamic> json) {
    return NoiseMeasurement(
      id: json['id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      soundLevel: (json['soundLevel'] as num).toDouble(),
      aiCategory: NoiseCategory.fromKey(json['aiCategory'] as String?),
      aiConfidence: (json['aiConfidence'] as num).toDouble(),
      gpsAccuracy: (json['gpsAccuracy'] as num?)?.toDouble(),
      userCategory: json['userCategory'] == null
          ? null
          : NoiseCategory.fromKey(json['userCategory'] as String?),
      isUserCorrected: json['isUserCorrected'] as bool? ?? false,
      deviceModel: json['deviceModel'] as String?,
      osmRoadClass: json['osmRoadClass'] as String?,
      durationSeconds: json['durationSeconds'] as int?,
      qualityFlag: json['qualityFlag'] as String? ?? 'valid',
    );
  }
}
