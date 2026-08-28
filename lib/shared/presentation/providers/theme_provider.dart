import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppAccent {
  ocean('Ocean', Color(0xFF1769E0), false),
  violet('Violet', Color(0xFF7557D5), true),
  emerald('Emerald', Color(0xFF008F76), true),
  sunset('Sunset', Color(0xFFE05A3F), true);

  final String label;
  final Color seedColor;
  final bool isPremium;

  const AppAccent(this.label, this.seedColor, this.isPremium);
}

class AppThemeSettings {
  final ThemeMode mode;
  final AppAccent accent;

  const AppThemeSettings({
    this.mode = ThemeMode.light,
    this.accent = AppAccent.ocean,
  });

  AppThemeSettings copyWith({ThemeMode? mode, AppAccent? accent}) {
    return AppThemeSettings(
      mode: mode ?? this.mode,
      accent: accent ?? this.accent,
    );
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeSettings>((
  ref,
) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<AppThemeSettings> {
  ThemeNotifier() : super(const AppThemeSettings()) {
    unawaited(_load());
  }

  static const String _modeKey = 'app_theme_mode';
  static const String _accentKey = 'app_theme_accent';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool(_modeKey) ?? false;
      final accentName = prefs.getString(_accentKey);
      final accent = AppAccent.values.firstWhere(
        (value) => value.name == accentName,
        orElse: () => AppAccent.ocean,
      );
      if (!mounted) return;
      state = AppThemeSettings(
        mode: isDark ? ThemeMode.dark : ThemeMode.light,
        accent: accent,
      );
    } catch (_) {
      // The default theme remains usable if platform preferences are absent.
    }
  }

  Future<void> toggleTheme() async {
    final next = state.mode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    state = state.copyWith(mode: next);
    await _persist();
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    await _persist();
  }

  Future<void> setAccent(AppAccent accent) async {
    state = state.copyWith(accent: accent);
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setBool(_modeKey, state.mode == ThemeMode.dark),
        prefs.setString(_accentKey, state.accent.name),
      ]);
    } catch (_) {
      // Theme changes still apply for the current session.
    }
  }
}
