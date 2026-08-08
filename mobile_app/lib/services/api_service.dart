import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'storage_service.dart';

class ApiService {
  static Future<http.Response> _request(String method, String endpoint,
      {Map<String, dynamic>? body}) async {
    final token = await StorageService.getToken();
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    switch (method) {
      case 'GET':
        return await http.get(url, headers: headers);
      case 'POST':
        return await http.post(url, headers: headers, body: jsonEncode(body));
      case 'PUT':
        return await http.put(url, headers: headers, body: jsonEncode(body));
      case 'DELETE':
        return await http.delete(url, headers: headers);
      default:
        throw Exception('Invalid method');
    }
  }

  // ===== AUTH METHODS =====
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final response = await _request('POST', ApiConfig.endpointLogin,
        body: {'email': email, 'password': password});
    return jsonDecode(response.body);
  }

  // ✅ UBAH: register sekarang WAJIB kirim OTP
  static Future<Map<String, dynamic>> register(
      String name, String email, String password, String otp) async {
    final response = await _request('POST', ApiConfig.endpointRegister, body: {
      'name': name,
      'email': email,
      'password': password,
      'otp': otp, // ✅ BARU
    });
    return jsonDecode(response.body);
  }

  // ✅ BARU: Kirim OTP ke email untuk verifikasi pendaftaran
  static Future<Map<String, dynamic>> sendRegisterOtp(String email) async {
    final path = ApiConfig.endpointForgotPassword
        .replaceFirst('/forgot-password', '/send-register-otp');
    final response = await _request('POST', path, body: {'email': email});
    return jsonDecode(response.body);
  }

  // ===== SENSOR METHODS =====
  static Future<Map<String, dynamic>> getSensorHistory(
      {String? startDate, String? endDate}) async {
    String url = ApiConfig.endpointSensorsHistory;
    if (startDate != null && endDate != null) {
      url += '?startDate=$startDate&endDate=$endDate';
    }
    final response = await _request('GET', url);
    return jsonDecode(response.body);
  }

  // ===== PUMP METHODS =====
  static Future<Map<String, dynamic>> getSchedules({String? deviceId}) async {
    String url = ApiConfig.endpointSchedule;
    if (deviceId != null && deviceId.isNotEmpty) {
      url += '?deviceId=$deviceId';
    }
    final response = await _request('GET', url);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> createSchedule(
      Map<String, dynamic> data) async {
    final response =
        await _request('POST', ApiConfig.endpointSchedule, body: data);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateSchedule(
      String id, Map<String, dynamic> data) async {
    final response =
        await _request('PUT', '${ApiConfig.endpointSchedule}/$id', body: data);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> deleteSchedule(String id) async {
    final response =
        await _request('DELETE', '${ApiConfig.endpointSchedule}/$id');
    return jsonDecode(response.body);
  }

  // ===== THRESHOLD METHODS (✅ PER-DEVICE) =====
  static Future<Map<String, dynamic>> getThreshold(String deviceId) async {
    final response =
        await _request('GET', '${ApiConfig.endpointThreshold}/$deviceId');
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateThreshold(
      String deviceId, Map<String, dynamic> data) async {
    final response = await _request(
        'PUT', '${ApiConfig.endpointThreshold}/$deviceId',
        body: data);
    return jsonDecode(response.body);
  }

  // ==========================================
  // PROFILE & SECURITY METHODS
  // ==========================================

  // ✅ BARU: Ambil data user lengkap (termasuk createdAt untuk "Bergabung Sejak")
  static Future<Map<String, dynamic>> getMe() async {
    final response = await _request('GET', ApiConfig.endpointMe);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateProfile(String name) async {
    final response = await _request('PUT', ApiConfig.endpointUpdateProfile,
        body: {'name': name});
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> changePassword(
      String currentPassword, String newPassword) async {
    final response = await _request('PUT', ApiConfig.endpointChangePassword,
        body: {'currentPassword': currentPassword, 'newPassword': newPassword});
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await _request('POST', ApiConfig.endpointForgotPassword,
        body: {'email': email});
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> resetPassword(
      String email, String code, String newPassword) async {
    final response = await _request('POST', ApiConfig.endpointResetPassword,
        body: {'email': email, 'code': code, 'newPassword': newPassword});
    return jsonDecode(response.body);
  }
}
