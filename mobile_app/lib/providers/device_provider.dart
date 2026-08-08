import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart'; // ✅ BARU: untuk ambil token dari storage

class DeviceModel {
  final String id;
  final String deviceId;
  final String deviceName;
  final String location;
  final bool isActive;
  final DateTime lastSeen;

  DeviceModel({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.location,
    required this.isActive,
    required this.lastSeen,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? 'unknown_id',
      deviceId: json['deviceId']?.toString() ?? 'unknown_device',
      deviceName: json['deviceName']?.toString() ?? 'Unnamed Device',
      location: json['location']?.toString() ?? '',
      isActive: json['isActive'] ?? true,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'].toString())
          : DateTime.now(),
    );
  }
}

class DeviceProvider extends ChangeNotifier {
  List<DeviceModel> _devices = [];
  DeviceModel? _selectedDevice;
  bool _isLoading = false;

  List<DeviceModel> get devices => _devices;
  DeviceModel? get selectedDevice => _selectedDevice;
  bool get isLoading => _isLoading;

  String? get currentDeviceId => _selectedDevice?.deviceId;
  bool get hasSelectedDevice => _selectedDevice != null;

  bool get isCurrentDeviceOnline {
    if (_selectedDevice == null) return false;
    final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
    return _selectedDevice!.lastSeen.isAfter(fiveMinutesAgo);
  }

  // ✅ HELPER: Ambil token dari storage (lebih reliable dari authService.user?.token)
  Future<String?> _getToken() async {
    return await StorageService.getToken();
  }

  // ✅ 1. FETCH DEVICES — path sudah dibetulkan
  Future<void> fetchDevices(AuthService authService) async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _getToken();
      if (token == null) {
        debugPrint('❌ Token null, tidak bisa fetch devices');
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/device/my-devices'), // ✅ +/api
        headers: {'Authorization': 'Bearer $token'},
      );

      debugPrint('📡 [FETCH DEVICES] Status: ${response.statusCode}');
      debugPrint('📡 [FETCH DEVICES] Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final data = responseData['data'] as List;

        _devices = data.map((d) => DeviceModel.fromJson(d)).toList();

        if (_devices.isNotEmpty) {
          debugPrint('✅ [DEBUG] ${_devices.length} device ditemukan:');
          for (var d in _devices) {
            debugPrint('   - ${d.deviceName} (${d.deviceId})');
          }
        } else {
          debugPrint('⚠️ [DEBUG] Tidak ada device terdaftar untuk user ini');
        }

        if (_selectedDevice != null &&
            !_devices.any((d) => d.id == _selectedDevice!.id)) {
          _selectedDevice = _devices.isNotEmpty ? _devices.first : null;
        } else if (_selectedDevice == null && _devices.isNotEmpty) {
          _selectedDevice = _devices.first;
        }
      } else {
        debugPrint('❌ [FETCH DEVICES] Gagal: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching devices: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectDevice(DeviceModel device) {
    _selectedDevice = device;
    debugPrint(
        '🔄 [DEVICE] Switched to: ${device.deviceName} (${device.deviceId})');
    notifyListeners();
  }

  void selectDeviceById(String deviceId) {
    final device = _devices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => _devices.isNotEmpty
          ? _devices.first
          : throw Exception('Device not found'),
    );
    selectDevice(device);
  }

  void selectDeviceByDeviceId(String deviceIdString) {
    final device = _devices.firstWhere(
      (d) => d.deviceId == deviceIdString,
      orElse: () => _devices.isNotEmpty
          ? _devices.first
          : throw Exception('Device not found'),
    );
    selectDevice(device);
  }

  void selectNextDevice() {
    if (_devices.isEmpty) return;

    if (_selectedDevice == null) {
      _selectedDevice = _devices.first;
    } else {
      final currentIndex =
          _devices.indexWhere((d) => d.id == _selectedDevice!.id);
      final nextIndex = (currentIndex + 1) % _devices.length;
      _selectedDevice = _devices[nextIndex];
    }

    debugPrint('🔄 [DEVICE] Next device: ${_selectedDevice!.deviceName}');
    notifyListeners();
  }

  void refreshSelectedDevice() {
    if (_selectedDevice == null) return;

    final updated = _devices.firstWhere(
      (d) => d.id == _selectedDevice!.id,
      orElse: () => _selectedDevice!,
    );

    if (updated.id != _selectedDevice!.id ||
        updated.lastSeen != _selectedDevice!.lastSeen) {
      _selectedDevice = updated;
      notifyListeners();
    }
  }

  // ✅ 3. REGISTER DEVICE — path sudah dibetulkan
  Future<bool> registerDevice(AuthService authService, String deviceId,
      String deviceName, String location) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/device/register'), // ✅ +/api
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'deviceId': deviceId,
          'deviceName': deviceName,
          'location': location,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        await fetchDevices(authService);
        return true;
      }
      debugPrint('❌ Register gagal: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      debugPrint('❌ Error registering device: $e');
      return false;
    }
  }

  // ✅ 4. UPDATE DEVICE — path sudah dibetulkan
  Future<bool> updateDevice(AuthService authService, String id,
      String deviceName, String location) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/device/$id'), // ✅ +/api
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'deviceName': deviceName,
          'location': location,
        }),
      );

      if (response.statusCode == 200) {
        await fetchDevices(authService);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error updating device: $e');
      return false;
    }
  }

  // ✅ 5. DELETE DEVICE — path sudah dibetulkan
  Future<bool> deleteDevice(AuthService authService, String id) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/device/$id'), // ✅ +/api
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        await fetchDevices(authService);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting device: $e');
      return false;
    }
  }

  // ✅ 6. SET DEVICE ACTIVE/INACTIVE — path sudah dibetulkan
  Future<bool> setDeviceActive(
      AuthService authService, String id, bool isActive) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/device/$id/status'), // ✅ +/api
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'isActive': isActive}),
      );

      if (response.statusCode == 200) {
        await fetchDevices(authService);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error setting device active: $e');
      return false;
    }
  }
}
