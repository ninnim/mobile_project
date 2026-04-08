import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';

class ThemeState {
  final ThemeMode mode;
  final Color accent;
  const ThemeState({required this.mode, required this.accent});
  ThemeState copyWith({ThemeMode? mode, Color? accent}) =>
      ThemeState(mode: mode ?? this.mode, accent: accent ?? this.accent);
}

class ThemeNotifier extends Notifier<ThemeState> {
  @override
  ThemeState build() {
    _load();
    return const ThemeState(mode: ThemeMode.system, accent: DarkColors.primary);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // 'themeMode': 0=system, 1=light, 2=dark  (null = never set → use system)
    final modeIndex = prefs.getInt('themeMode');
    final accentValue = prefs.getInt('accent') ?? DarkColors.primary.toARGB32();
    final mode = modeIndex == null
        ? ThemeMode.system
        : ThemeMode.values[modeIndex.clamp(0, 2)];
    state = ThemeState(mode: mode, accent: Color(accentValue));
  }

  Future<void> setMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(mode: mode);
    await prefs.setInt('themeMode', mode.index);
  }

  Future<void> toggleMode() async {
    final next = state.mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setMode(next);
  }

  Future<void> setAccent(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(accent: color);
    await prefs.setInt('accent', color.toARGB32());
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);
