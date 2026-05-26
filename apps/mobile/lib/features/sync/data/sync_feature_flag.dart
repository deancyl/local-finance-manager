import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sync/sync.dart';

part 'sync_feature_flag.g.dart';

/// Key for storing sync feature flag in SharedPreferences.
const String _syncFeatureFlagKey = 'sync_feature_enabled';

/// Provider for SharedPreferences instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

/// Notifier for managing the sync feature flag.
class SyncFeatureFlagNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Default to false (sync disabled)
    // Try to load from SharedPreferences
    _loadFromPrefs();
    return false;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final enabled = prefs.getBool(_syncFeatureFlagKey) ?? false;
      state = enabled;
    } catch (e) {
      // If we can't load, default to false
      state = false;
    }
  }

  /// Enables or disables the sync feature.
  Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(_syncFeatureFlagKey, enabled);
      state = enabled;
    } catch (e) {
      // Revert state on error
      state = !enabled;
      rethrow;
    }
  }

  /// Toggles the sync feature.
  Future<void> toggle() async {
    await setEnabled(!state);
  }
}

/// Provider for the sync feature flag.
final syncFeatureFlagProvider = NotifierProvider<SyncFeatureFlagNotifier, bool>(() {
  return SyncFeatureFlagNotifier();
});

/// Whether sync feature is currently enabled.
final isSyncFeatureEnabledProvider = Provider<bool>((ref) {
  return ref.watch(syncFeatureFlagProvider);
});

/// Provider for sync diagnostic information.
final syncDiagnosticProvider = FutureProvider<SyncDiagnosticReport?>((ref) async {
  final isEnabled = ref.watch(syncFeatureFlagProvider);
  
  if (!isEnabled) {
    return null;
  }

  // Run diagnostics to check sync compatibility
  final checker = SyncCompatibilityChecker();
  return await checker.runFullDiagnostics();
});

/// Result of checking if sync can be enabled.
class SyncEnableCheckResult {
  final bool canEnable;
  final String? reason;
  final SyncDiagnosticReport? diagnosticReport;

  const SyncEnableCheckResult({
    required this.canEnable,
    this.reason,
    this.diagnosticReport,
  });

  factory SyncEnableCheckResult.ok({SyncDiagnosticReport? report}) {
    return SyncEnableCheckResult(
      canEnable: true,
      diagnosticReport: report,
    );
  }

  factory SyncEnableCheckResult.notReady(String reason, {SyncDiagnosticReport? report}) {
    return SyncEnableCheckResult(
      canEnable: false,
      reason: reason,
      diagnosticReport: report,
    );
  }
}

/// Provider that checks if sync can be safely enabled.
final canEnableSyncProvider = FutureProvider<SyncEnableCheckResult>((ref) async {
  final checker = SyncCompatibilityChecker();
  final report = await checker.runFullDiagnostics();

  if (report.isCompatible) {
    return SyncEnableCheckResult.ok(report: report);
  } else {
    return SyncEnableCheckResult.notReady(
      report.summary,
      report: report,
    );
  }
});
