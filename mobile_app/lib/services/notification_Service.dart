import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Android Settings (Bisa const karena nilainya tetap)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS Settings (Bisa const karena nilainya tetap)
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    // Combined Settings (Bisa const)
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Initialize
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('🔔 Notifikasi diklik dengan payload: ${response.payload}');
        // Bisa tambahkan navigasi ke halaman tertentu di sini nanti
      },
    );

    // Request permission untuk iOS
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    debugPrint("✅ Notification Service initialized");
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    // 1. Tentukan warna berdasarkan tipe (INI NILAI RUNTIME, JADI TIDAK BISA CONST)
    final Color notifColor = payload == 'warning'
        ? const Color(0xFFFF9800) // Orange
        : const Color(0xFF4CAF50); // Hijau

    // 2. Android Details (UBAH 'const' MENJADI 'final' KARENA MEMAKAI notifColor)
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'smart_irrigation_channel',
      'Smart Irrigation Alerts',
      channelDescription: 'Notifikasi kondisi tanah dan penyiraman',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: notifColor,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: notifColor,
      visibility: NotificationVisibility.public,
    );

    // 3. iOS Details (UBAH 'const' MENJADI 'final' AGAR KONSISTEN)
    final DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // 4. Combined Details (UBAH 'const' MENJADI 'final')
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    // 5. Show notification
    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000), // ID unik
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    debugPrint("📱 System notification displayed: $title");
  }
}
