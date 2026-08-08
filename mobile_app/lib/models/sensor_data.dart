class SensorData {
  final String? id;
  final String userId;
  final double soilMoisture;
  final double temperature;
  final double ph;
  final String pumpStatus;
  final DateTime timestamp;

  SensorData({
    this.id,
    required this.userId,
    required this.soilMoisture,
    required this.temperature,
    required this.ph,
    required this.pumpStatus,
    required this.timestamp,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      id: json['_id'],
      userId: json['userId'] ?? '',
      soilMoisture: (json['soilMoisture'] ?? 0).toDouble(),
      temperature: (json['temperature'] ?? 0).toDouble(),
      ph: (json['ph'] ?? 0).toDouble(),
      pumpStatus: json['pumpStatus'] ?? 'OFF',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'soilMoisture': soilMoisture,
      'temperature': temperature,
      'ph': ph,
      'pumpStatus': pumpStatus,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  SensorData copyWith({
    String? id,
    String? userId,
    double? soilMoisture,
    double? temperature,
    double? ph,
    String? pumpStatus,
    DateTime? timestamp,
  }) {
    return SensorData(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      soilMoisture: soilMoisture ?? this.soilMoisture,
      temperature: temperature ?? this.temperature,
      ph: ph ?? this.ph,
      pumpStatus: pumpStatus ?? this.pumpStatus,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  bool get isPumpOn => pumpStatus.toUpperCase() == 'ON';

  String get moistureStatus {
    if (soilMoisture < 30) return 'Kering';
    if (soilMoisture < 60) return 'Normal';
    return 'Basah';
  }

  String get phStatus {
    if (ph < 5.5) return 'Asam';
    if (ph > 6.5) return 'Basa';
    return 'Normal';
  }
}
