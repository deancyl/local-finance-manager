import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode enum for settings.
enum AppThemeMode {
  system,
  light,
  dark,
  amoledBlack,
}

/// Theme settings model containing all theme-related preferences.
class ThemeSettings {
  final AppThemeMode mode;
  final Color accentColor;
  final bool useScheduledDarkMode;
  final TimeOfDay darkModeStartTime;
  final TimeOfDay darkModeEndTime;

  const ThemeSettings({
    this.mode = AppThemeMode.system,
    this.accentColor = const Color(0xFF2196F3),
    this.useScheduledDarkMode = false,
    this.darkModeStartTime = const TimeOfDay(hour: 20, minute: 0),
    this.darkModeEndTime = const TimeOfDay(hour: 6, minute: 0),
  });

  ThemeSettings copyWith({
    AppThemeMode? mode,
    Color? accentColor,
    bool? useScheduledDarkMode,
    TimeOfDay? darkModeStartTime,
    TimeOfDay? darkModeEndTime,
  }) {
    return ThemeSettings(
      mode: mode ?? this.mode,
      accentColor: accentColor ?? this.accentColor,
      useScheduledDarkMode: useScheduledDarkMode ?? this.useScheduledDarkMode,
      darkModeStartTime: darkModeStartTime ?? this.darkModeStartTime,
      darkModeEndTime: darkModeEndTime ?? this.darkModeEndTime,
    );
  }

  /// Check if dark mode should be active based on current time.
  bool shouldUseDarkMode() {
    if (!useScheduledDarkMode) return false;
    
    final now = TimeOfDay.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = darkModeStartTime.hour * 60 + darkModeStartTime.minute;
    final endMinutes = darkModeEndTime.hour * 60 + darkModeEndTime.minute;

    // Handle overnight schedule (e.g., 20:00 to 06:00)
    if (startMinutes > endMinutes) {
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    } else {
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    }
  }
}

/// Notifier for managing app theme.
class ThemeNotifier extends StateNotifier<ThemeSettings> {
  static const _modeKey = 'theme_mode';
  static const _accentColorKey = 'accent_color';
  static const _scheduledKey = 'scheduled_dark_mode';
  static const _startTimeKey = 'dark_mode_start_time';
  static const _endTimeKey = 'dark_mode_end_time';

  ThemeNotifier() : super(const ThemeSettings()) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    
    final savedMode = prefs.getString(_modeKey);
    final mode = savedMode != null
        ? AppThemeMode.values.firstWhere(
            (m) => m.name == savedMode,
            orElse: () => AppThemeMode.system,
          )
        : AppThemeMode.system;

    final savedAccentColor = prefs.getInt(_accentColorKey);
    final accentColor = savedAccentColor != null
        ? Color(savedAccentColor)
        : const Color(0xFF2196F3);

    final useScheduled = prefs.getBool(_scheduledKey) ?? false;

    final startTimeStr = prefs.getString(_startTimeKey);
    final startTime = _parseTimeOfDay(startTimeStr) ?? const TimeOfDay(hour: 20, minute: 0);

    final endTimeStr = prefs.getString(_endTimeKey);
    final endTime = _parseTimeOfDay(endTimeStr) ?? const TimeOfDay(hour: 6, minute: 0);

    state = ThemeSettings(
      mode: mode,
      accentColor: accentColor,
      useScheduledDarkMode: useScheduled,
      darkModeStartTime: startTime,
      darkModeEndTime: endTime,
    );
  }

  TimeOfDay? _parseTimeOfDay(String? timeStr) {
    if (timeStr == null) return null;
    final parts = timeStr.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour}:${time.minute}';
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(mode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }

  Future<void> setAccentColor(Color color) async {
    state = state.copyWith(accentColor: color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentColorKey, color.value);
  }

  Future<void> setScheduledDarkMode(bool enabled) async {
    state = state.copyWith(useScheduledDarkMode: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scheduledKey, enabled);
  }

  Future<void> setDarkModeSchedule({
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async {
    state = state.copyWith(
      darkModeStartTime: startTime,
      darkModeEndTime: endTime,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_startTimeKey, _formatTimeOfDay(startTime));
    await prefs.setString(_endTimeKey, _formatTimeOfDay(endTime));
  }

  /// Get the effective theme mode considering scheduled dark mode.
  AppThemeMode get effectiveThemeMode {
    // Check scheduled dark mode first
    if (state.shouldUseDarkMode()) {
      return AppThemeMode.dark;
    }
    return state.mode;
  }

  ThemeMode get materialThemeMode {
    final effective = effectiveThemeMode;
    switch (effective) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
      case AppThemeMode.amoledBlack:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  bool get isAmoledBlack => state.mode == AppThemeMode.amoledBlack;
}

/// Provider for theme state.
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeSettings>((ref) {
  return ThemeNotifier();
});
