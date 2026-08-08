import 'package:flutter/material.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService extends ChangeNotifier {
  User? _user;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  bool _isCheckingAuth = true;
  String? _errorMessage;

  User? get user => _user;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  bool get isCheckingAuth => _isCheckingAuth;
  String? get errorMessage => _errorMessage;

  AuthService() {
    _checkLoginStatus();
  }

  // ✅ FIX: Restore sesi dari storage (token + user data)
  Future<void> _checkLoginStatus() async {
    _isLoading = true;
    _isCheckingAuth = true;
    notifyListeners();

    try {
      final token = await StorageService.getToken();
      final userData = await StorageService.getUserData();

      print(
          '🔐 [AUTH RESTORE] token ada: ${token != null && token.isNotEmpty}, userData ada: ${userData != null}');

      if (token != null && token.isNotEmpty && userData != null) {
        _user = User.fromJson(userData);
        _isLoggedIn = true;
        print('🔐 [AUTH RESTORE] Sesi dipulihkan: ${_user!.name}');
      } else {
        _user = null;
        _isLoggedIn = false;
        print('🔐 [AUTH RESTORE] Tidak ada sesi tersimpan → Login');
      }
    } catch (e) {
      print('❌ [AUTH RESTORE] Error: $e');
      _user = null;
      _isLoggedIn = false;
    }

    _isLoading = false;
    _isCheckingAuth = false;
    notifyListeners();
  }

  // ✅ Method public untuk SplashScreen
  Future<void> restoreSession() async {
    await _checkLoginStatus();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.login(email, password);
      if (response['success'] == true) {
        final data = response['data'];
        _user = User.fromJson(data);
        _isLoggedIn = true;

        await StorageService.saveToken(data['token']);
        await StorageService.saveUserData(data);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Login gagal';
      }
    } catch (e) {
      _errorMessage = 'Koneksi error: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // ✅ UBAH: Tambah parameter otp (wajib sekarang)
  Future<bool> register(
      String name, String email, String password, String otp) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // ✅ UBAH: Kirim OTP ke ApiService
      final response = await ApiService.register(name, email, password, otp);
      if (response['success'] == true) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Registrasi gagal';
      }
    } catch (e) {
      _errorMessage = 'Koneksi error: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    // ✅ clearAuth: hapus token+user+remember, theme & setting tetap aman
    await StorageService.clearAuth();
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> updateProfile(String name) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.updateProfile(name);

      if (response['success'] == true && _user != null) {
        final data = response['data'];

        _user = User(
          id: data['_id'] ?? _user!.id,
          name: data['name'] ?? _user!.name,
          email: data['email'] ?? _user!.email,
          role: data['role'] ?? _user!.role,
        );

        // ✅ Simpan struktur LENGKAP biar restore selalu konsisten
        await StorageService.saveUserData({
          '_id': _user!.id,
          'id': _user!.id,
          'name': _user!.name,
          'email': _user!.email,
          'role': _user!.role,
        });

        _isLoading = false;
        notifyListeners();
        return {'success': true};
      } else {
        _errorMessage = response['message'] ?? 'Gagal memperbarui profil';
      }
    } catch (e) {
      _errorMessage = 'Koneksi error: $e';
    }

    _isLoading = false;
    notifyListeners();
    return {'success': false, 'message': _errorMessage};
  }

  Future<Map<String, dynamic>> changePassword(
      String currentPassword, String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response =
          await ApiService.changePassword(currentPassword, newPassword);

      _isLoading = false;
      notifyListeners();

      if (response['success'] == true) {
        return {'success': true, 'message': response['message']};
      } else {
        _errorMessage = response['message'] ?? 'Gagal mengubah password';
        return {'success': false, 'message': _errorMessage};
      }
    } catch (e) {
      _errorMessage = 'Koneksi error: $e';
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': _errorMessage};
    }
  }
}
