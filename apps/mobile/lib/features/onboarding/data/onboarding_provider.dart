import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../main.dart' show sharedPreferencesProvider;

/// Key for storing onboarding completion status
const _onboardingCompletedKey = 'onboarding_completed';

/// Onboarding state notifier
class OnboardingNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  
  OnboardingNotifier(this._prefs) : super(false) {
    _loadOnboardingStatus();
  }
  
  Future<void> _loadOnboardingStatus() async {
    state = _prefs.getBool(_onboardingCompletedKey) ?? false;
  }
  
  /// Mark onboarding as completed
  Future<void> completeOnboarding() async {
    await _prefs.setBool(_onboardingCompletedKey, true);
    state = true;
  }
  
  /// Check if onboarding has been completed
  bool isOnboardingCompleted() => state;
  
  /// Reset onboarding status (for testing)
  Future<void> resetOnboarding() async {
    await _prefs.remove(_onboardingCompletedKey);
    state = false;
  }
}

/// Provider for onboarding state
final onboardingProvider = StateNotifierProvider<OnboardingNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return OnboardingNotifier(prefs);
});