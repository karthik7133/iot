/// Data model for the new Sequential Zone Irrigation system.
/// Replaces the old SensorData model that had temperature/humidity/battery/diseaseRisk.
class ZoneData {
  final int zone1Progress;   // 0–100 %
  final int zone2Progress;   // 0–100 %
  final double precipitation; // probability 0–100 %
  final bool gatesOpen;
  final int rainThreshold;
  final DateTime? zone1UpdatedAt;
  final DateTime? zone2UpdatedAt;
  final DateTime? precipUpdatedAt;

  const ZoneData({
    required this.zone1Progress,
    required this.zone2Progress,
    required this.precipitation,
    required this.gatesOpen,
    this.rainThreshold = 80,
    this.zone1UpdatedAt,
    this.zone2UpdatedAt,
    this.precipUpdatedAt,
  });

  factory ZoneData.empty() => const ZoneData(
    zone1Progress: 0,
    zone2Progress: 0,
    precipitation: 0,
    gatesOpen: true,
  );

  factory ZoneData.fromJson(Map<String, dynamic> json) {
    final z1 = json['zone1'] as Map<String, dynamic>? ?? {};
    final z2 = json['zone2'] as Map<String, dynamic>? ?? {};
    return ZoneData(
      zone1Progress:   ((z1['progress'] ?? 0) as num).toInt(),
      zone2Progress:   ((z2['progress'] ?? 0) as num).toInt(),
      precipitation:   ((json['precipitation'] ?? 0) as num).toDouble(),
      gatesOpen:       json['gatesOpen'] as bool? ?? true,
      rainThreshold:   ((json['rainThreshold'] ?? 80) as num).toInt(),
      zone1UpdatedAt:  z1['updatedAt'] != null ? DateTime.tryParse(z1['updatedAt']) : null,
      zone2UpdatedAt:  z2['updatedAt'] != null ? DateTime.tryParse(z2['updatedAt']) : null,
      precipUpdatedAt: json['precipUpdatedAt'] != null ? DateTime.tryParse(json['precipUpdatedAt']) : null,
    );
  }

  bool get zone1Complete => zone1Progress >= 100;
  bool get zone2Complete => zone2Progress >= 100;
  bool get allComplete => zone1Complete && zone2Complete;
  bool get rainLikely => precipitation > rainThreshold;
}
