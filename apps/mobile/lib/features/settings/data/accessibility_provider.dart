import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Accessibility settings model containing all accessibility-related preferences.
class AccessibilitySettings {
  /// Enable screen reader optimizations
  final bool screenReaderEnabled;
  
  /// Use high contrast theme
  final bool highContrastEnabled;
  
  /// Text scale factor (1.0 = normal, 1.15 = large, 1.3 = extra large)
  final double textScaleFactor;
  
  /// Whether to use system text scale
  final bool useSystemTextScale;
  
  /// Enable enhanced focus indicators
  final bool enhancedFocusIndicators;
  
  /// Focus indicator thickness
  final double focusIndicatorThickness;
  
  /// Minimum touch target size (for accessibility)
  final double minTouchTargetSize;
  
  /// Reduce animations for users with motion sensitivity
  final bool reduceAnimations;
  
  /// Bold text for better readability
  final bool boldText;

  const AccessibilitySettings({
    this.screenReaderEnabled = false,
    this.highContrastEnabled = false,
    this.textScaleFactor = 1.0,
    this.useSystemTextScale = true,
    this.enhancedFocusIndicators = true,
    this.focusIndicatorThickness = 3.0,
    this.minTouchTargetSize = 48.0,
    this.reduceAnimations = false,
    this.boldText = false,
  });

  AccessibilitySettings copyWith({
    bool? screenReaderEnabled,
    bool? highContrastEnabled,
    double? textScaleFactor,
    bool? useSystemTextScale,
    bool? enhancedFocusIndicators,
    double? focusIndicatorThickness,
    double? minTouchTargetSize,
    bool? reduceAnimations,
    bool? boldText,
  }) {
    return AccessibilitySettings(
      screenReaderEnabled: screenReaderEnabled ?? this.screenReaderEnabled,
      highContrastEnabled: highContrastEnabled ?? this.highContrastEnabled,
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
      useSystemTextScale: useSystemTextScale ?? this.useSystemTextScale,
      enhancedFocusIndicators: enhancedFocusIndicators ?? this.enhancedFocusIndicators,
      focusIndicatorThickness: focusIndicatorThickness ?? this.focusIndicatorThickness,
      minTouchTargetSize: minTouchTargetSize ?? this.minTouchTargetSize,
      reduceAnimations: reduceAnimations ?? this.reduceAnimations,
      boldText: boldText ?? this.boldText,
    );
  }

  /// Preset text scale options
  static const Map<String, double> textScalePresets = {
    'normal': 1.0,
    'large': 1.15,
    'extra_large': 1.3,
    'huge': 1.5,
  };
}

/// Notifier for managing accessibility settings.
class AccessibilityNotifier extends StateNotifier<AccessibilitySettings> {
  static const _screenReaderKey = 'accessibility_screen_reader';
  static const _highContrastKey = 'accessibility_high_contrast';
  static const _textScaleKey = 'accessibility_text_scale';
  static const _useSystemTextScaleKey = 'accessibility_use_system_text_scale';
  static const _enhancedFocusKey = 'accessibility_enhanced_focus';
  static const _focusThicknessKey = 'accessibility_focus_thickness';
  static const _minTouchTargetKey = 'accessibility_min_touch_target';
  static const _reduceAnimationsKey = 'accessibility_reduce_animations';
  static const _boldTextKey = 'accessibility_bold_text';

  AccessibilityNotifier() : super(const AccessibilitySettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    state = AccessibilitySettings(
      screenReaderEnabled: prefs.getBool(_screenReaderKey) ?? false,
      highContrastEnabled: prefs.getBool(_highContrastKey) ?? false,
      textScaleFactor: prefs.getDouble(_textScaleKey) ?? 1.0,
      useSystemTextScale: prefs.getBool(_useSystemTextScaleKey) ?? true,
      enhancedFocusIndicators: prefs.getBool(_enhancedFocusKey) ?? true,
      focusIndicatorThickness: prefs.getDouble(_focusThicknessKey) ?? 3.0,
      minTouchTargetSize: prefs.getDouble(_minTouchTargetKey) ?? 48.0,
      reduceAnimations: prefs.getBool(_reduceAnimationsKey) ?? false,
      boldText: prefs.getBool(_boldTextKey) ?? false,
    );
  }

  Future<void> setScreenReaderEnabled(bool enabled) async {
    state = state.copyWith(screenReaderEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_screenReaderKey, enabled);
  }

  Future<void> setHighContrastEnabled(bool enabled) async {
    state = state.copyWith(highContrastEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_highContrastKey, enabled);
  }

  Future<void> setTextScaleFactor(double factor) async {
    state = state.copyWith(textScaleFactor: factor);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_textScaleKey, factor);
  }

  Future<void> setUseSystemTextScale(bool useSystem) async {
    state = state.copyWith(useSystemTextScale: useSystem);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useSystemTextScaleKey, useSystem);
  }

  Future<void> setEnhancedFocusIndicators(bool enabled) async {
    state = state.copyWith(enhancedFocusIndicators: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enhancedFocusKey, enabled);
  }

  Future<void> setFocusIndicatorThickness(double thickness) async {
    state = state.copyWith(focusIndicatorThickness: thickness);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_focusThicknessKey, thickness);
  }

  Future<void> setMinTouchTargetSize(double size) async {
    state = state.copyWith(minTouchTargetSize: size);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_minTouchTargetKey, size);
  }

  Future<void> setReduceAnimations(bool reduce) async {
    state = state.copyWith(reduceAnimations: reduce);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reduceAnimationsKey, reduce);
  }

  Future<void> setBoldText(bool bold) async {
    state = state.copyWith(boldText: bold);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_boldTextKey, bold);
  }

  /// Reset all accessibility settings to defaults
  Future<void> resetToDefaults() async {
    state = const AccessibilitySettings();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_screenReaderKey);
    await prefs.remove(_highContrastKey);
    await prefs.remove(_textScaleKey);
    await prefs.remove(_useSystemTextScaleKey);
    await prefs.remove(_enhancedFocusKey);
    await prefs.remove(_focusThicknessKey);
    await prefs.remove(_minTouchTargetKey);
    await prefs.remove(_reduceAnimationsKey);
    await prefs.remove(_boldTextKey);
  }
}

/// Provider for accessibility settings state.
final accessibilityProvider = StateNotifierProvider<AccessibilityNotifier, AccessibilitySettings>((ref) {
  return AccessibilityNotifier();
});
