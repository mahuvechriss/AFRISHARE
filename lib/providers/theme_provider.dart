import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ThemeModePreference { light, dark, system }

final themeProvider =
    StateNotifierProvider<ThemeNotifier, ThemeModePreference>((ref) {
  return ThemeNotifier();
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  final preference = ref.watch(themeProvider);
  switch (preference) {
    case ThemeModePreference.light:
      return ThemeMode.light;
    case ThemeModePreference.dark:
      return ThemeMode.dark;
    case ThemeModePreference.system:
      return ThemeMode.system;
  }
});

class ThemeNotifier extends StateNotifier<ThemeModePreference> {
  ThemeNotifier() : super(ThemeModePreference.system);

  void setLightMode() => state = ThemeModePreference.light;
  void setDarkMode() => state = ThemeModePreference.dark;
  void setSystemMode() => state = ThemeModePreference.system;

  void toggle() {
    switch (state) {
      case ThemeModePreference.light:
        state = ThemeModePreference.dark;
        break;
      case ThemeModePreference.dark:
        state = ThemeModePreference.system;
        break;
      case ThemeModePreference.system:
        state = ThemeModePreference.light;
        break;
    }
  }
}
