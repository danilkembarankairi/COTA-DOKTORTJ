class ApiConfig {
  // ✅ IP laptop Anda (ganti kalau berubah)
  static const String baseUrl = 'http://10.0.2.2:3000';

  // static const String baseUrl = 'http://192.168.1.10:3000';

  // MQTT Configuration
  static const String mqttBroker = 'broker.hivemq.com';
  static const int mqttPort = 1883;
  static const String mqttClientId = 'flutter_app_';

  // ✅ MQTT topics dengan wildcard (+)
  static const String topicSoilMoisture =
      'cota/smart_irrigation/+/soil_moisture';
  static const String topicTemperature = 'cota/smart_irrigation/+/temperature';
  static const String topicPh = 'cota/smart_irrigation/+/ph';
  static const String topicPumpStatus = 'cota/smart_irrigation/+/pump/status';
  static const String topicPumpControl = 'cota/smart_irrigation/+/pump/control';
  static const String topicNotifications =
      'cota/smart_irrigation/+/notifications';
  static const String topicThreshold = 'cota/threshold/+/config';
  static const String topicSchedule =
      'cota/smart_irrigation/+/schedule/execute';

  // ✅ API Endpoints — TAMBAH /api di depan!
  static const String endpointLogin = '/api/auth/login';
  static const String endpointRegister = '/api/auth/register';
  static const String endpointSendRegisterOtp = '/api/auth/send-register-otp';
  static const String endpointSensorsHistory = '/api/sensors/history';
  static const String endpointSchedule = '/api/schedule';
  static const String endpointThreshold = '/api/threshold';
  static const String endpointUpdateProfile = '/api/auth/profile';
  static const String endpointChangePassword = '/api/auth/password';
  static const String endpointForgotPassword = '/api/auth/forgot-password';
  static const String endpointResetPassword = '/api/auth/reset-password';
  static const String endpointMe = '/api/auth/me'; // ✅ BARU
}
