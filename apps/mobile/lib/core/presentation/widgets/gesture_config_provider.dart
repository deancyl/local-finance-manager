import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gesture_controls.dart';

/// Gesture configuration state notifier
class GestureConfigNotifier extends StateNotifier<GestureConfig> {
  static const String _keyPrefix = 'gesture_config_';
  final SharedPreferences _prefs;

  GestureConfigNotifier(this._prefs) : super(const GestureConfig()) {
    _loadConfig();
  }

  void _loadConfig() {
    state = GestureConfig(
      swipeLeft: _loadAction('swipeLeft', GestureAction.delete),
      swipeRight: _loadAction('swipeRight', GestureAction.edit),
      longPress: _loadAction('longPress', GestureAction.categorize),
      doubleTap: _loadAction('doubleTap', GestureAction.duplicate),
      enableHapticFeedback: _prefs.getBool('${_keyPrefix}haptic') ?? true,
      swipeThreshold: _prefs.getDouble('${_keyPrefix}threshold') ?? 0.25,
      longPressDuration: Duration(
        milliseconds: _prefs.getInt('${_keyPrefix}longPressMs') ?? 500,
      ),
    );
  }

  GestureAction _loadAction(String key, GestureAction defaultValue) {
    final actionName = _prefs.getString('${_keyPrefix}$key');
    if (actionName == null) return defaultValue;
    return GestureAction.values.firstWhere(
      (e) => e.name == actionName,
      orElse: () => defaultValue,
    );
  }

  void updateSwipeLeft(GestureAction action) {
    _saveAction('swipeLeft', action);
    state = state.copyWith(swipeLeft: action);
  }

  void updateSwipeRight(GestureAction action) {
    _saveAction('swipeRight', action);
    state = state.copyWith(swipeRight: action);
  }

  void updateLongPress(GestureAction action) {
    _saveAction('longPress', action);
    state = state.copyWith(longPress: action);
  }

  void updateDoubleTap(GestureAction action) {
    _saveAction('doubleTap', action);
    state = state.copyWith(doubleTap: action);
  }

  void updateHapticFeedback(bool enabled) {
    _prefs.setBool('${_keyPrefix}haptic', enabled);
    state = state.copyWith(enableHapticFeedback: enabled);
  }

  void updateSwipeThreshold(double threshold) {
    _prefs.setDouble('${_keyPrefix}threshold', threshold);
    state = state.copyWith(swipeThreshold: threshold);
  }

  void updateLongPressDuration(Duration duration) {
    _prefs.setInt('${_keyPrefix}longPressMs', duration.inMilliseconds);
    state = state.copyWith(longPressDuration: duration);
  }

  void _saveAction(String key, GestureAction action) {
    _prefs.setString('${_keyPrefix}$key', action.name);
  }

  void resetToDefaults() {
    _prefs.remove('${_keyPrefix}swipeLeft');
    _prefs.remove('${_keyPrefix}swipeRight');
    _prefs.remove('${_keyPrefix}longPress');
    _prefs.remove('${_keyPrefix}doubleTap');
    _prefs.remove('${_keyPrefix}haptic');
    _prefs.remove('${_keyPrefix}threshold');
    _prefs.remove('${_keyPrefix}longPressMs');
    state = const GestureConfig();
  }
}

/// Provider for gesture configuration
final gestureConfigProvider = StateNotifierProvider<GestureConfigNotifier, GestureConfig>((ref) {
  throw UnimplementedError('gestureConfigProvider must be overridden');
});

/// Provider for SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

/// Initialize gesture config provider
Future<GestureConfigNotifier> createGestureConfigNotifier() async {
  final prefs = await SharedPreferences.getInstance();
  return GestureConfigNotifier(prefs);
}
