import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../config/api_config.dart';

class MQTTService extends ChangeNotifier {
  MqttServerClient? _client;
  StreamSubscription? _mqttUpdatesSubscription;

  bool _isConnected = false;
  bool _isPumpOn = false;
  bool _deviceOnline = false;

  double _soilMoisture = 0;
  double _temperature = 0;
  double _ph = 0;

  DateTime? _lastMessageTime;

  final List<Map<String, dynamic>> _moistureHistory = [];
  final List<Map<String, dynamic>> _temperatureHistory = [];
  final List<Map<String, dynamic>> _phHistory = [];

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  bool get isConnected => _isConnected;
  bool get isPumpOn => _isPumpOn;
  bool get deviceOnline => _deviceOnline;
  DateTime? get lastMessageTime => _lastMessageTime;
  double get soilMoisture => _soilMoisture;
  double get temperature => _temperature;
  double get ph => _ph;
  List<Map<String, dynamic>> get moistureHistory => _moistureHistory;
  List<Map<String, dynamic>> get temperatureHistory => _temperatureHistory;
  List<Map<String, dynamic>> get phHistory => _phHistory;

  bool get isDataFresh {
    if (_lastMessageTime == null) return false;
    return DateTime.now().difference(_lastMessageTime!).inSeconds <= 60;
  }

  bool get isReallyConnected => _isConnected && isDataFresh;

  Future<void> connect() async {
    debugPrint('🔌 MQTTService.connect() dipanggil');

    if (_client != null && _isConnected) {
      debugPrint('⚠️ Koneksi lama terdeteksi, memutuskan terlebih dahulu...');
      await disconnect();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    try {
      final clientId =
          '${ApiConfig.mqttClientId}${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('📱 Client ID: $clientId');
      debugPrint('🌐 Broker: ${ApiConfig.mqttBroker}:${ApiConfig.mqttPort}');

      _client = MqttServerClient.withPort(
        ApiConfig.mqttBroker,
        clientId,
        ApiConfig.mqttPort,
      );

      _client!.autoReconnect = true;
      _client!.resubscribeOnAutoReconnect = true;
      _client!.keepAlivePeriod = 60;
      _client!.logging(on: kDebugMode);
      _client!.onDisconnected = _handleDisconnected;

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);

      _client!.connectionMessage = connMessage;

      debugPrint('🔌 Attempting to connect...');
      await _client!.connect();

      if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
        _isConnected = true;
        debugPrint('✅ Connected to MQTT Broker');

        _setupMessageListener();
        await _subscribeToTopics();
        notifyListeners();
      } else {
        debugPrint('❌ MQTT connection failed: ${_client!.connectionStatus}');
        _isConnected = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ MQTT Error: $e');
      _isConnected = false;
      notifyListeners();

      Future.delayed(const Duration(seconds: 5), () {
        if (!_isConnected) {
          debugPrint('🔄 Attempting to reconnect...');
          connect();
        }
      });
    }
  }

  void _handleDisconnected() {
    _isConnected = false;
    notifyListeners();
    debugPrint('🔌 Disconnected from MQTT');
  }

  void _setupMessageListener() {
    debugPrint('👂 Setting up message listener...');

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

          debugPrint('📨 Received: $topic = $payloadString');
          _handleMessage(topic, payloadString);
        }
      },
      onError: (error) {
        debugPrint('❌ MQTT stream error: $error');
        _isConnected = false;
        notifyListeners();
      },
    );

    debugPrint('✅ Message listener setup complete');
  }

  Future<void> _subscribeToTopics() async {
    debugPrint('📡 Subscribing to topics...');

    try {
      _client!.subscribe(ApiConfig.topicSoilMoisture, MqttQos.atLeastOnce);
      _client!.subscribe(ApiConfig.topicTemperature, MqttQos.atLeastOnce);
      _client!.subscribe(ApiConfig.topicPh, MqttQos.atLeastOnce);
      _client!.subscribe(ApiConfig.topicPumpStatus, MqttQos.atLeastOnce);
      _client!.subscribe(ApiConfig.topicNotifications, MqttQos.atLeastOnce);

      debugPrint('✅ All subscriptions completed');
    } catch (e) {
      debugPrint('❌ Error subscribing: $e');
    }
  }

  void _handleMessage(String topic, String payload) {
    _lastMessageTime = DateTime.now();

    if (topic == ApiConfig.topicNotifications) {
      debugPrint('🔔 Notifikasi diterima, meneruskan ke UI Stream...');
      _messageController.add({
        'topic': topic,
        'payload': payload,
        'receivedAt': _lastMessageTime!.toIso8601String(),
      });
      return;
    }

    final now = DateTime.now();

    switch (topic) {
      case ApiConfig.topicSoilMoisture:
        final value = double.tryParse(payload);
        if (value != null) {
          _soilMoisture = value;
          _addToHistory(_moistureHistory, value, now);
        }
        break;

      case ApiConfig.topicTemperature:
        final value = double.tryParse(payload);
        if (value != null) {
          _temperature = value;
          _addToHistory(_temperatureHistory, value, now);
        }
        break;

      case ApiConfig.topicPh:
        final value = double.tryParse(payload);
        if (value != null) {
          _ph = value;
          _addToHistory(_phHistory, value, now);
        }
        break;

      case ApiConfig.topicPumpStatus:
        final normalized = payload.trim().toUpperCase();
        final newState =
            normalized == 'ON' || normalized == '1' || normalized == 'TRUE';
        _isPumpOn = newState;
        break;
    }

    notifyListeners();
  }

  void _addToHistory(
    List<Map<String, dynamic>> history,
    double value,
    DateTime time,
  ) {
    history.add({
      'x': history.length.toDouble(),
      'y': value,
      'time': time,
    });

    if (history.length > 20) {
      history.removeAt(0);
      for (int i = 0; i < history.length; i++) {
        history[i]['x'] = i.toDouble();
      }
    }
  }

  void controlPump(bool turnOn) {
    if (!_isConnected || _client == null) {
      debugPrint('❌ Cannot control pump - not connected');
      return;
    }

    final command = turnOn ? 'ON' : 'OFF';
    final builder = MqttClientPayloadBuilder();
    builder.addString(command);

    _client!.publishMessage(
      ApiConfig.topicPumpControl,
      MqttQos.atLeastOnce,
      builder.payload!,
    );

    debugPrint('📤 Sent pump command: $command');

    _isPumpOn = turnOn;
    notifyListeners();
  }

  Future<void> disconnect() async {
    try {
      _mqttUpdatesSubscription?.cancel();
      _mqttUpdatesSubscription = null;

      _client?.disconnect();
    } catch (e) {
      debugPrint('❌ Disconnect error: $e');
    } finally {
      _isConnected = false;
      notifyListeners();
      debugPrint('🔌 Disconnected from MQTT');
    }
  }

  void dispose() {
    _mqttUpdatesSubscription?.cancel();
    _messageController.close();
    _client?.disconnect();
    super.dispose();
  }
}
