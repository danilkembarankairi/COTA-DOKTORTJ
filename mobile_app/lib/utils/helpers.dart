import 'package:intl/intl.dart';

class Helpers {
  // Format DateTime
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  static String formatDate(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  static String formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  // Format Number
  static String formatNumber(double number, {int decimals = 1}) {
    return number.toStringAsFixed(decimals);
  }

  // Get Status Text
  static String getMoistureStatus(double moisture) {
    if (moisture < 30) return 'Kering';
    if (moisture < 60) return 'Normal';
    return 'Basah';
  }

  static String getPhStatus(double ph) {
    if (ph < 5.5) return 'Asam';
    if (ph > 6.5) return 'Basa';
    return 'Normal';
  }

  static String getTemperatureStatus(double temp) {
    if (temp < 15) return 'Dingin';
    if (temp > 35) return 'Panas';
    return 'Normal';
  }

  // Get Status Color
  static String getStatusColor(String status) {
    switch (status) {
      case 'Kering':
      case 'Asam':
      case 'Basa':
      case 'Dingin':
      case 'Panas':
        return 'red';
      case 'Normal':
      case 'Ideal':
        return 'green';
      default:
        return 'grey';
    }
  }

  // Validate Email
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Validate Password
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }
}
