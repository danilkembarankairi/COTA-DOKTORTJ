import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'services/mqtt_service.dart';
import 'providers/theme_provider.dart';
import 'config/theme_config.dart';
import 'providers/device_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  // ✅ WAJIB: Pastikan binding diinisialisasi sebelum memanggil fungsi async
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ INISIALISASI NOTIFIKASI LOKAL SEBELUM APP BERJALAN
  await NotificationService.initialize();

  // ✅ FIX UTAMA: PRELOAD theme SEBELUM runApp
  // Supaya saat Dashboard pertama kali render, theme sudah sesuai storage
  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme(); // ← WAJIB await!

  runApp(MyApp(themeProvider: themeProvider));
}

class MyApp extends StatelessWidget {
  final ThemeProvider themeProvider; // ✅ Terima dari main()
  const MyApp({Key? key, required this.themeProvider}) : super(key: key);

  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => MQTTService()),
        // ✅ Pakai .value karena sudah di-create + di-load di main()
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Smart Irrigation',
            debugShowCheckedModeBanner: false,

            // Theme Support
            themeMode: themeProvider.themeMode,
            theme: ThemeConfig.lightTheme,
            darkTheme: ThemeConfig.darkTheme,

            // Localization
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('id', 'ID'),
              Locale('en', 'US'),
            ],
            locale: const Locale('id', 'ID'),

            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
