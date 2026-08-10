import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../config/api_config.dart';

class MQTTService extends ChangeNotifier {
  // 1. VARIABEL KONEKSI & STATUS
  MqttServerClient? _client;
  StreamSubscription? _mqttUpdatesSubscription;
  bool _isConnected = false;
  bool _isPumpOn = false;

  // ✅ Menyimpan Device ID yang sedang aktif
  String? _currentDeviceId;

  // ✅ Status koneksi device (online/offline/unknown)
  String _deviceStatus = 'unknown';

  // 2. VARIABEL DATA SENSOR (Default 0 agar tidak null)
  double _soilMoisture = 0.0;
  double _temperature = 0.0;
  double _ph = 0.0;

  // 3. VARIABEL WAKTU & RIWAYAT
  DateTime? _lastMessageTime;
  final List<Map<String, dynamic>> _moistureHistory = [];
  final List<Map<String, dynamic>> _temperatureHistory = [];
  final List<Map<String, dynamic>> _phHistory = [];

  // 4. STREAM CONTROLLER UNTUK NOTIFIKASI REAL-TIME KE UI
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  // 5. WATCHDOG TIMER (CEK KONEKSI SECARA RUTIN)
  Timer? _offlineCheckTimer;

  // --- GETTERS ---
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  bool get isConnected => _isConnected;
  bool get isPumpOn => _isPumpOn;
  DateTime? get lastMessageTime => _lastMessageTime;
  double get soilMoisture => _soilMoisture;
  double get temperature => _temperature;
  double get ph => _ph;
  List<Map<String, dynamic>> get moistureHistory => _moistureHistory;
  List<Map<String, dynamic>> get temperatureHistory => _temperatureHistory;
  List<Map<String, dynamic>> get phHistory => _phHistory;
  String? get currentDeviceId => _currentDeviceId;
  String get deviceStatus => _deviceStatus;

  // ✅ GETTER: Cek apakah device benar-benar ONLINE (hanya true jika ada pesan LIVE < 15 detik)
  bool get isDeviceOnline {
    if (_lastMessageTime == null) return false;
    final secondsSinceLastMessage =
        DateTime.now().difference(_lastMessageTime!).inSeconds;
    return secondsSinceLastMessage < 15;
  }

  // ✅ GETTER: Cek apakah ada data yang VALID (bukan retained message lama)
  bool get hasFreshData {
    return isDeviceOnline && (_soilMoisture > 0 || _temperature > 0 || _ph > 0);
  }

  // ✅ SETTER: Dipanggil saat user mengganti device di Dashboard
  void setCurrentDevice(String? deviceId) {
    debugPrint(
        '🔄 [MQTT-SET] setCurrentDevice dipanggil: "$deviceId" (sebelumnya: "$_currentDeviceId")');
    _currentDeviceId = deviceId;
    _deviceStatus = 'unknown';
    clearOldData();
    debugPrint(
        '🔄 [MQTT-SET] Device sekarang: "$_currentDeviceId" | data direset');
  }

  // ==========================================
  // A. FUNGSI KONEKSI
  // ==========================================
  Future<void> connect() async {
    debugPrint('🔌 MQTTService: Mencoba menghubungkan...');

    if (_client != null && _isConnected) {
      await disconnect();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    try {
      final clientId = 'flutter_app_${DateTime.now().millisecondsSinceEpoch}';

      _client = MqttServerClient.withPort(
        ApiConfig.mqttBroker,
        clientId,
        ApiConfig.mqttPort,
      );

      _client!.autoReconnect = true;
      _client!.keepAlivePeriod = 60;
      _client!.logging(on: kDebugMode);
      _client!.resubscribeOnAutoReconnect = true;

      _client!.onConnected = () {
        debugPrint('✅ MQTT: Berhasil terhubung ke Broker');
      };

      _client!.onDisconnected = () {
        debugPrint('🔌 MQTT: Terputus dari Broker');
        _isConnected = false;
        notifyListeners();
      };

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);

      _client!.connectionMessage = connMessage;
      await _client!.connect();

      if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
        _isConnected = true;
        _setupMessageListener();
        await _subscribeToTopics();
        _startOfflineCheckTimer();
        notifyListeners();
      } else {
        debugPrint(
            '❌ MQTT: Gagal terhubung. Status: ${_client!.connectionStatus}');
        _isConnected = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ MQTT Error: $e');
      _isConnected = false;
      notifyListeners();

      Future.delayed(const Duration(seconds: 5), () {
        if (!_isConnected) connect();
      });
    }
  }

  // ==========================================
  // B. MENDENGARKAN DATA
  // ==========================================
  void _setupMessageListener() {
    _mqttUpdatesSubscription?.cancel();
    _mqttUpdatesSubscription = _client!.updates?.listen(
      (List<MqttReceivedMessage<MqttMessage>> messages) {
        for (final msg in messages) {
          final topic = msg.topic;
          if (topic == null) continue;

          final payload = msg.payload;
          if (payload is! MqttPublishMessage) continue;

          final payloadString = MqttPublishPayload.bytesToStringAsString(
            payload.payload.message,
          ).trim();

          final bool isRetained = payload.header?.retain ?? false;

          _handleMessage(topic, payloadString, isRetained);
        }
      },
      onError: (error) {
        debugPrint('❌ MQTT Stream Error: $error');
        _isConnected = false;
        notifyListeners();
      },
    );
  }

  Future<void> _subscribeToTopics() async {
    try {
      _client!.subscribe(
          'cota/smart_irrigation/+/soil_moisture', MqttQos.atLeastOnce);
      _client!.subscribe(
          'cota/smart_irrigation/+/temperature', MqttQos.atLeastOnce);
      _client!.subscribe('cota/smart_irrigation/+/ph', MqttQos.atLeastOnce);
      _client!.subscribe(
          'cota/smart_irrigation/+/pump/status', MqttQos.atLeastOnce);
      _client!.subscribe(
          'cota/smart_irrigation/+/notifications', MqttQos.atLeastOnce);
      _client!.subscribe('cota/smart_irrigation/+/status', MqttQos.atLeastOnce);

      debugPrint('✅ MQTT: Semua topik berhasil di-subscribe (Wildcard +)');
    } catch (e) {
      debugPrint('❌ MQTT Error saat subscribe: $e');
    }
  }

  // ==========================================
  // C. MEMPROSES DATA (THE BRAIN) - + LOG VERBOSE
  // ==========================================
  void _handleMessage(String topic, String payload, bool isRetained) {
    // ✅ LOG VERBOSE: setiap pesan yang masuk
    debugPrint(
        '📥 [MQTT-IN] topic="$topic" payload="$payload" retained=$isRetained | currentDevice="$_currentDeviceId"');

    // ✅ FILTER 1: Jika belum ada device yang dipilih, abaikan SEMUA data
    if (_currentDeviceId == null || _currentDeviceId!.isEmpty) {
      debugPrint('🚫 [FILTER-1] DIBUANG: currentDeviceId null/empty');
      return;
    }

    // ✅ FILTER 2: Jika topik TIDAK mengandung ID device yang sedang dipilih, ABAIKAN!
    final topicLower = topic.toLowerCase();
    final idLower = _currentDeviceId!.toLowerCase();
    if (!topicLower.contains(idLower)) {
      debugPrint(
          '🚫 [FILTER-2] DIBUANG: topic "$topic" tidak mengandung "$_currentDeviceId"');
      return;
    }

    debugPrint(
        '✅ [FILTER-PASS] topic "$topic" cocok dengan device "$_currentDeviceId"');

    // ✅ FILTER 3 (ANTI-GHOST & ANTI-BACKEND-CHATTER) - PERBAIKAN KRUSIAL
    // ✅ FILTER 3 (ANTI-GHOST & ANTI-BACKEND-CHATTER) - PERBAIKAN KRUSIAL
    if (!isRetained) {
      if (topic.endsWith('/soil_moisture') ||
          topic.endsWith('/temperature') ||
          topic.endsWith('/ph')) {
        _lastMessageTime = DateTime.now();
        debugPrint('⏰ [TIME] _lastMessageTime diupdate: $_lastMessageTime');
      }
    }

    // ⚠️ WAJIB DICEK PALING AWAL: /pump/status
    if (topic.endsWith('/pump/status')) {
      final normalized = payload.trim().toUpperCase();
      final newState =
          normalized == 'ON' || normalized == '1' || normalized == 'TRUE';
      if (_isPumpOn != newState) {
        debugPrint('💧 Status Pompa berubah: ${newState ? "ON" : "OFF"}');
      }
      _isPumpOn = newState;
      notifyListeners();
      return;
    }

    // ✅ HANDLER: Deteksi device online/offline dari topik /status
    if (topic.endsWith('/status')) {
      final normalized = payload.trim().toLowerCase();
      if (normalized == 'online') {
        _deviceStatus = 'online';
        debugPrint('🟢 [STATUS] Device online');
      } else if (normalized.contains('offline') ||
          normalized == 'offline_power_loss') {
        _deviceStatus = 'offline';
        _isPumpOn = false;
        _lastMessageTime = null;
        debugPrint('🔴 [STATUS] Device OFFLINE - Pompa dipaksa OFF di UI');
      }
      notifyListeners();
      return;
    }

    if (topic.endsWith('/notifications')) {
      _messageController.add({
        'topic': topic,
        'payload': payload,
        'receivedAt': _lastMessageTime?.toIso8601String() ??
            DateTime.now().toIso8601String(),
      });
      return;
    }

    final now = DateTime.now();

    if (topic.endsWith('/soil_moisture')) {
      final value = double.tryParse(payload);
      if (value != null) {
        _soilMoisture = value;
        _addToHistory(_moistureHistory, value, now);
        debugPrint('💧 [DATA] soilMoisture = $value');
      }
    } else if (topic.endsWith('/temperature')) {
      final value = double.tryParse(payload);
      if (value != null) {
        _temperature = value;
        _addToHistory(_temperatureHistory, value, now);
        debugPrint('🌡️ [DATA] temperature = $value');
      }
    } else if (topic.endsWith('/ph')) {
      final value = double.tryParse(payload);
      if (value != null) {
        _ph = value;
        _addToHistory(_phHistory, value, now);
        debugPrint('🧪 [DATA] pH = $value');
      }
    }

    notifyListeners();
  }

  // ==========================================
  // D. MENGELOLA RIWAYAT
  // ==========================================
  void _addToHistory(
      List<Map<String, dynamic>> history, double value, DateTime time) {
    history.add({'x': history.length.toDouble(), 'y': value, 'time': time});

    if (history.length > 20) {
      history.removeAt(0);
      for (int i = 0; i < history.length; i++) {
        history[i]['x'] = i.toDouble();
      }
    }
  }

  // ==========================================
  // E. MENGIRIM PERINTAH
  // ==========================================
  void controlPump(bool turnOn) {
    if (!_isConnected || _client == null) {
      debugPrint('❌ Gagal kontrol pompa: Tidak terhubung');
      return;
    }

    if (_currentDeviceId == null || _currentDeviceId!.isEmpty) {
      debugPrint(
          '❌ Gagal kontrol pompa: Device ID belum dipilih di Dashboard!');
      return;
    }

    final command = turnOn ? 'ON' : 'OFF';
    final builder = MqttClientPayloadBuilder();
    builder.addString(command);

    final targetTopic = 'cota/smart_irrigation/$_currentDeviceId/pump/control';

    _client!.publishMessage(
      targetTopic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );

    debugPrint('📤 MQTT Mengirim perintah: $command ke $targetTopic');
    _isPumpOn = turnOn;
    notifyListeners();
  }

  // ==========================================
  // F. WATCHDOG TIMER (CEK KONEKSI SECARA RUTIN)
  // ==========================================
  void _startOfflineCheckTimer() {
    _offlineCheckTimer?.cancel();
    _offlineCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentDeviceId != null && !isDeviceOnline) {
        if (_deviceStatus != 'offline' || _isPumpOn) {
          _deviceStatus = 'offline';
          _isPumpOn = false;
          debugPrint(
              '⏱️ [WATCHDOG] ESP32 dicabut/mati > 15 detik. Paksa UI OFFLINE & Pompa OFF.');
          notifyListeners();
        }
      }
    });
  }

  void _stopOfflineCheckTimer() {
    _offlineCheckTimer?.cancel();
    _offlineCheckTimer = null;
  }

  // ==========================================
  // G. PEMBERSIHAN & KEAMANAN
  // ==========================================
  Future<void> disconnect() async {
    _stopOfflineCheckTimer();
    try {
      _mqttUpdatesSubscription?.cancel();
      _mqttUpdatesSubscription = null;
      if (_client != null) _client!.disconnect();
    } catch (e) {
      debugPrint('❌ Error saat disconnect: $e');
    } finally {
      _isConnected = false;
      _soilMoisture = 0.0;
      _temperature = 0.0;
      _ph = 0.0;
      _isPumpOn = false;
      _deviceStatus = 'unknown';
      _lastMessageTime = null;

      notifyListeners();
      debugPrint('🔌 MQTT: Terputus secara manual - Semua data direset');
    }
  }

  void clearOldData() {
    _soilMoisture = 0.0;
    _temperature = 0.0;
    _ph = 0.0;
    _isPumpOn = false;
    _deviceStatus = 'unknown';
    _lastMessageTime = null;
    _moistureHistory.clear();
    _temperatureHistory.clear();
    _phHistory.clear();
    notifyListeners();
  }

  void dispose() {
    _stopOfflineCheckTimer();
    _mqttUpdatesSubscription?.cancel();
    _messageController.close();
    _client?.disconnect();
    super.dispose();
  }
}
