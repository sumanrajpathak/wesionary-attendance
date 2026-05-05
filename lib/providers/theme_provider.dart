import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _kMode = 'theme_mode_v1';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kMode);
    _mode = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMode, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  Future<void> toggle(BuildContext context) async {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final effective = _mode == ThemeMode.system
        ? (brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light)
        : _mode;
    await setMode(
      effective == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }
}
