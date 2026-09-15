import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider para gerenciar e persistir a preferência de tema do usuário.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(() {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _themeKey = 'theme_mode';

  @override
  ThemeMode build() {
    // Carregar o tema salvo no início (padrão é sistema)
    _loadTheme();
    return ThemeMode.system;
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);
    
    if (savedTheme != null) {
      state = ThemeMode.values.firstWhere(
        (e) => e.name == savedTheme,
        orElse: () => ThemeMode.system,
      );
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }
}
