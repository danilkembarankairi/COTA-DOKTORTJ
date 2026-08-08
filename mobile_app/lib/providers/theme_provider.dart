import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  // ✅ HAPUS pemanggilan dari constructor (sudah dipanggil manual di main.dart)
  // Constructor sekarang kosong — state awal tetap light (default)
  ThemeProvider();

  // ✅ RENAMED: dari private _loadThemeFromPrefs() jadi public loadTheme()
  // Supaya bisa di-await dari main.dart SEBELUM runApp
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString(_themeKey);

    if (themeString != null) {
      _themeMode = themeString == 'dark' ? ThemeMode.dark : ThemeMode.light;
    } else {
      // Default: ikuti sistem
      _themeMode = ThemeMode.system;
    }

    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _themeKey, _themeMode == ThemeMode.dark ? 'dark' : 'light');

    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;

    final prefs = await SharedPreferences.getInstance();
    String themeString;

    switch (mode) {
      case ThemeMode.dark:
        themeString = 'dark';
        break;
      case ThemeMode.light:
        themeString = 'light';
        break;
      default:
        themeString = 'system';
    }

    await prefs.setString(_themeKey, themeString);
    notifyListeners();
  }

  bool get isDarkMode => _themeMode == ThemeMode.dark;
}
