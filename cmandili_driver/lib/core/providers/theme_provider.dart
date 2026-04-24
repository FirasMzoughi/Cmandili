import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.light) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeStr = prefs.getString('themeMode');
    if (themeModeStr != null) {
      state = ThemeMode.values.firstWhere(
        (e) => e.toString() == themeModeStr,
        orElse: () => ThemeMode.light,
      );
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.toString());
  }

  void toggleTheme() {
    setTheme(state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
  }
}
