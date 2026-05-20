import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported app languages.
enum AppLocale {
  system('跟随系统', null),
  zhCN('中文简体', Locale('zh', 'CN')),
  zhTW('中文繁體', Locale('zh', 'TW')),
  enUS('English', Locale('en', 'US'));

  final String displayName;
  final Locale? locale;

  const AppLocale(this.displayName, this.locale);
}

/// Notifier for managing app locale.
class LocaleNotifier extends StateNotifier<AppLocale> {
  static const _key = 'app_locale';

  LocaleNotifier() : super(AppLocale.system) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString(_key);
    if (savedLocale != null) {
      state = AppLocale.values.firstWhere(
        (locale) => locale.name == savedLocale,
        orElse: () => AppLocale.system,
      );
    }
  }

  Future<void> setLocale(AppLocale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.name);
  }

  /// Returns the actual Locale to use, or null for system default.
  Locale? get flutterLocale => state.locale;
}

/// Provider for locale state.
final localeProvider = StateNotifierProvider<LocaleNotifier, AppLocale>((ref) {
  return LocaleNotifier();
});
