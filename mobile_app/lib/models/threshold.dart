class ThresholdModel {
  final double moistureMin;
  final double moistureMax;
  final double phMin;
  final double phMax;
  final double tempMin;
  final double tempMax;
  final bool isAutoWateringEnabled;
  final bool isAlertEnabled;
  final DateTime? lastTriggeredAt;

  ThresholdModel({
    required this.moistureMin,
    required this.moistureMax,
    required this.phMin,
    required this.phMax,
    required this.tempMin,
    required this.tempMax,
    required this.isAutoWateringEnabled,
    required this.isAlertEnabled,
    this.lastTriggeredAt,
  });

  factory ThresholdModel.fromJson(Map<String, dynamic> json) {
    return ThresholdModel(
      // 🔥 PERBAIKAN: Menggunakan double.tryParse agar aman dari tipe data String/Num
      moistureMin:
          double.tryParse(json['moistureMin']?.toString() ?? '') ?? 30.0,
      moistureMax:
          double.tryParse(json['moistureMax']?.toString() ?? '') ?? 40.0,
      phMin: double.tryParse(json['phMin']?.toString() ?? '') ?? 5.5,
      phMax: double.tryParse(json['phMax']?.toString() ?? '') ?? 6.5,
      tempMin: double.tryParse(json['tempMin']?.toString() ?? '') ?? 15.0,
      tempMax: double.tryParse(json['tempMax']?.toString() ?? '') ?? 35.0,

      isAutoWateringEnabled: json['isAutoWateringEnabled'] ?? true,
      isAlertEnabled: json['isAlertEnabled'] ?? true,

      lastTriggeredAt: json['lastTriggeredAt'] != null
          ? DateTime.tryParse(json['lastTriggeredAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'moistureMin': moistureMin,
      'moistureMax': moistureMax,
      'phMin': phMin,
      'phMax': phMax,
      'tempMin': tempMin,
      'tempMax': tempMax,
      'isAutoWateringEnabled': isAutoWateringEnabled,
      'isAlertEnabled': isAlertEnabled,
      'lastTriggeredAt': lastTriggeredAt?.toIso8601String(),
    };
  }
}
