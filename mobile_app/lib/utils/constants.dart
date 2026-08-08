class AppConstants {
  // App Info
  static const String appName = 'Smart Irrigation';
  static const String appVersion = '1.0.0';

  // Sensor Thresholds
  static const double minSoilMoisture = 30.0;
  static const double maxSoilMoisture = 80.0;
  static const double idealPhMin = 5.5;
  static const double idealPhMax = 6.5;
  static const double minTemperature = 15.0;
  static const double maxTemperature = 35.0;

  // MQTT
  static const int mqttKeepAlive = 20;
  static const int mqttQos = 1;

  // UI
  static const double defaultPadding = 16.0;
  static const double cardBorderRadius = 12.0;
  static const Duration animationDuration = Duration(milliseconds: 300);
}
