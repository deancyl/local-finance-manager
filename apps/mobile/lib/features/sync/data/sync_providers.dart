// Sync providers with feature flag support
// Sync functionality can be enabled/disabled via feature flag

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'package:sync/sync.dart';
import 'sync_feature_flag.dart';

final _log = Logger('SyncProvider');

/// Re-exports feature flag providers
export 'sync_feature_flag.dart';

/// Sync status stream provider.
/// 
/// Emits sync status changes in real-time.
/// Returns disabled status if feature is not enabled.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final isEnabled = ref.watch(syncFeatureFlagProvider);
  
  if (!isEnabled) {
    return Stream.value(SyncStatus.notInitialized);
  }
  
  // When sync is enabled, we would connect to actual sync client
  // For now, return disabled status
  _log.info('Sync status requested but sync client not initialized');
  return Stream.value(SyncStatus.disconnected);
});

/// Sync progress provider.
/// 
/// Provides current sync progress information.
/// Returns null progress if feature is not enabled.
final syncProgressProvider = FutureProvider<SyncProgress>((ref) async {
  final isEnabled = ref.watch(syncFeatureFlagProvider);
  
  if (!isEnabled) {
    return const SyncProgress(status: SyncStatus.notInitialized);
  }
  
  // When sync is enabled, we would get progress from actual sync client
  return const SyncProgress(status: SyncStatus.disconnected);
});

/// Sync operations notifier.
/// 
/// Manages sync connection and manual sync operations.
/// Operations are no-ops when sync is disabled.
class SyncNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  
  SyncNotifier(this._ref) : super(const AsyncValue.data(null));
  
  /// Initializes and connects to the sync server.
  /// 
  /// Does nothing if sync feature is disabled.
  Future<void> connect() async {
    final isEnabled = _ref.read(syncFeatureFlagProvider);
    
    if (!isEnabled) {
      _log.warning('Attempted to connect but sync feature is disabled');
      return;
    }
    
    state = const AsyncValue.loading();
    
    try {
      // When sync is properly enabled, initialize and connect
      // For now, we just set connected state
      _log.info('Sync connect requested');
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  /// Disconnects from the sync server.
  Future<void> disconnect() async {
    final isEnabled = _ref.read(syncFeatureFlagProvider);
    
    if (!isEnabled) {
      return;
    }
    
    state = const AsyncValue.loading();
    
    try {
      _log.info('Sync disconnect requested');
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  /// Triggers a manual sync.
  Future<void> sync() async {
    final isEnabled = _ref.read(syncFeatureFlagProvider);
    
    if (!isEnabled) {
      _log.warning('Attempted to sync but sync feature is disabled');
      return;
    }
    
    state = const AsyncValue.loading();
    
    try {
      _log.info('Manual sync triggered');
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  /// Closes the sync client and releases resources.
  Future<void> close() async {
    state = const AsyncValue.loading();
    
    try {
      _log.info('Sync close requested');
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Sync notifier provider.
final syncNotifierProvider = StateNotifierProvider<SyncNotifier, AsyncValue<void>>((ref) {
  return SyncNotifier(ref);
});

/// Pending conflicts provider.
/// 
/// Returns list of sync conflicts that need resolution.
/// Returns empty list if sync is disabled.
final pendingConflictsProvider = FutureProvider<List<SyncConflict>>((ref) async {
  final isEnabled = ref.watch(syncFeatureFlagProvider);
  
  if (!isEnabled) {
    return [];
  }
  
  // When sync is enabled, this would query the conflict table
  return [];
});

/// Registered devices provider.
/// 
/// Returns list of devices registered for sync.
/// Returns empty list if sync is disabled.
final registeredDevicesProvider = FutureProvider<List<SyncDevice>>((ref) async {
  final isEnabled = ref.watch(syncFeatureFlagProvider);
  
  if (!isEnabled) {
    return [];
  }
  
  // When sync is enabled, this would fetch from the sync server
  return [];
});

/// Whether sync is enabled and configured.
final isSyncEnabledProvider = Provider<bool>((ref) {
  return ref.watch(syncFeatureFlagProvider);
});

/// Whether sync is currently connected.
final isSyncConnectedProvider = Provider<bool>((ref) {
  final statusAsync = ref.watch(syncStatusProvider);
  return statusAsync.when(
    data: (status) => status == SyncStatus.connected,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Convenience provider that combines feature flag and sync status.
/// 
/// Returns the current sync state considering both feature flag and
/// actual sync connection status.
final syncStateProvider = Provider<SyncState>((ref) {
  final isEnabled = ref.watch(syncFeatureFlagProvider);
  
  if (!isEnabled) {
    return SyncState.disabled;
  }
  
  final statusAsync = ref.watch(syncStatusProvider);
  return statusAsync.when(
    data: (status) {
      switch (status) {
        case SyncStatus.notInitialized:
          return SyncState.notInitialized;
        case SyncStatus.disconnected:
          return SyncState.disconnected;
        case SyncStatus.connecting:
          return SyncState.connecting;
        case SyncStatus.connected:
          return SyncState.connected;
        case SyncStatus.error:
          return SyncState.error;
      }
    },
    loading: () => SyncState.connecting,
    error: (_, __) => SyncState.error,
  );
});

/// Combined sync state enum.
enum SyncState {
  /// Sync feature is disabled.
  disabled,
  
  /// Sync feature enabled but not initialized.
  notInitialized,
  
  /// Sync is disconnected.
  disconnected,
  
  /// Sync is connecting.
  connecting,
  
  /// Sync is connected and active.
  connected,
  
  /// Sync has an error.
  error,
}

/// Extension for SyncState.
extension SyncStateExtension on SyncState {
  /// Returns true if sync is operational (connected).
  bool get isOperational => this == SyncState.connected;
  
  /// Returns true if sync is available (feature enabled).
  bool get isAvailable => this != SyncState.disabled;
  
  /// Returns human-readable display name.
  String get displayName {
    switch (this) {
      case SyncState.disabled:
        return 'Disabled';
      case SyncState.notInitialized:
        return 'Not Initialized';
      case SyncState.disconnected:
        return 'Disconnected';
      case SyncState.connecting:
        return 'Connecting';
      case SyncState.connected:
        return 'Connected';
      case SyncState.error:
        return 'Error';
    }
  }
}
