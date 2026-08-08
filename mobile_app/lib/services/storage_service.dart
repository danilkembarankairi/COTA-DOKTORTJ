import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  // ==========================================
  // 🔑 KEY CONSTANTS (anti typo, mudah di-refactor)
  // ==========================================
  static const String _keyToken = 'auth_token';
  static const String _keyUserData = 'user_data';
  static const String _keyRememberMe = 'remember_me';
  static const String _keyLastDeviceId = 'last_device_id';

  // ==========================================
  // 🔧 INTERNAL HELPER
  // ==========================================
  static Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  // ==========================================
  // 🔐 TOKEN METHODS
  // ==========================================

  /// Menyimpan token autentikasi ke SharedPreferences
  static Future<void> saveToken(String token) async {
    final prefs = await _prefs;
    await prefs.setString(_keyToken, token);
  }

  /// Mengambil token autentikasi dari SharedPreferences
  static Future<String?> getToken() async {
    final prefs = await _prefs;
    return prefs.getString(_keyToken);
  }

  /// ✅ BARU: Menghapus token saja (tanpa hapus data lain)
  static Future<void> removeToken() async {
    final prefs = await _prefs;
    await prefs.remove(_keyToken);
  }

  /// ✅ BARU: Cek apakah ada token tersimpan (untuk splash screen)
  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ==========================================
  // 👤 USER DATA METHODS
  // ==========================================

  /// Menyimpan data user (Map) sebagai JSON string
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    final prefs = await _prefs;
    final String encoded = jsonEncode(userData);
    await prefs.setString(_keyUserData, encoded);
  }

  /// Mengambil data user dari SharedPreferences dan decode JSON-nya
  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await _prefs;
    final String? data = prefs.getString(_keyUserData);
    if (data == null) return null;

    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      // Kalau JSON rusak, kembalikan null
      return null;
    }
  }

  /// ✅ BARU: Menghapus data user saja (tanpa hapus token)
  static Future<void> removeUserData() async {
    final prefs = await _prefs;
    await prefs.remove(_keyUserData);
  }

  // ==========================================
  // ✅ REMEMBER ME (opsional, untuk UI checkbox)
  // ==========================================

  /// Menyimpan preferensi "Ingat Saya"
  static Future<void> setRememberMe(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyRememberMe, value);
  }

  /// Mengambil preferensi "Ingat Saya"
  static Future<bool> getRememberMe() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyRememberMe) ?? false;
  }

  // ==========================================
  // 📱 LAST DEVICE (untuk auto-select device terakhir)
  // ==========================================

  /// ✅ BARU: Menyimpan ID device terakhir yang dipilih
  static Future<void> saveLastDeviceId(String deviceId) async {
    final prefs = await _prefs;
    await prefs.setString(_keyLastDeviceId, deviceId);
  }

  /// ✅ BARU: Mengambil ID device terakhir
  static Future<String?> getLastDeviceId() async {
    final prefs = await _prefs;
    return prefs.getString(_keyLastDeviceId);
  }

  // ==========================================
  // 🗑️ CLEAR METHODS
  // ==========================================

  /// ✅ BARU: Hapus semua data auth (token + user data + remember me)
  /// Gunakan ini saat LOGOUT agar bersih tapi setting app (theme, dll) tetap
  static Future<void> clearAuth() async {
    final prefs = await _prefs;
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserData);
    await prefs.remove(_keyRememberMe);
    await prefs.remove(_keyLastDeviceId);
  }

  /// Menghapus SEMUA data di SharedPreferences (termasuk theme, setting, dll)
  /// Gunakan hanya untuk "Factory Reset" atau debug
  static Future<void> clearAll() async {
    final prefs = await _prefs;
    await prefs.clear();
  }
}
