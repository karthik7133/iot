class SensorData {
  final double temperature;
  final double humidity;
  final int moisture;
  final double precipitation;
  final String motorStatus;
  final double savedWater;
  final double batteryLevel;
  final String diseaseRisk;
  final DateTime? time;

  SensorData({
    required this.temperature,
    required this.humidity,
    required this.moisture,
    required this.precipitation,
    required this.motorStatus,
    required this.savedWater,
    required this.batteryLevel,
    required this.diseaseRisk,
    this.time,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      temperature: (json['temperature'] ?? 0.0).toDouble(),
      humidity: (json['humidity'] ?? 0.0).toDouble(),
      moisture: (json['moisture'] ?? 0).toInt(),
      precipitation: (json['precipitation'] ?? 0.0).toDouble(),
      motorStatus: json['motorStatus'] ?? "OFF",
      savedWater: (json['savedWater'] ?? 0.0).toDouble(),
      batteryLevel: (json['batteryLevel'] ?? 0.0).toDouble(),
      diseaseRisk: json['diseaseRisk'] ?? "LOW",
      time: json['time'] != null ? DateTime.parse(json['time']) : null,
    );
  }

  // Calculated Wow Factors
  double get yieldHealth => (moisture >= 40 && moisture <= 70) ? 98.0 : 85.0;
}

class IrrigationStats {
  final String waterSavedPercent;

  IrrigationStats({required this.waterSavedPercent});

  factory IrrigationStats.fromJson(Map<String, dynamic> json) {
    return IrrigationStats(
      waterSavedPercent: json['waterSavedPercent'] ?? "0.00",
    );
  }
}
