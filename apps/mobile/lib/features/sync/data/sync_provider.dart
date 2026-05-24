// DISABLED: sync package is temporarily disabled due to PowerSync compatibility issues
// Original content commented out below

/*
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';

import 'package:sync/sync.dart';

/// Sync configuration provider.
/// 
/// Loads sync config from secure storage or returns null if not configured.
final syncConfigProvider = FutureProvider<SyncConfig?>((ref) async {
  // This would need the schema and auth provider to be passed in
  // For now, return null - will be set when user configures sync
  return null;
});

/// Sync client instance provider.
/// 
/// Returns null if sync is not configured.
final syncClientProvider = Provider<SyncClient?>((ref) {
  final configAsync = ref.watch(syncConfigProvider);
  
  return configAsync.when(
    data: (config) {
      if (config == null) return null;
      return SyncClient(config: config);
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Sync status stream provider.
/// 
/// Emits sync status changes in real-time.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final client = ref.watch(syncClientProvider);
  if (client == null) {
    return Stream.value(SyncStatus.notInitialized);
  }
  return client.watchStatus();
});

/// Sync progress provider.
/// 
/// Provides current sync progress information.
final syncProgressProvider = FutureProvider<SyncProgress>((ref) async {
  final client = ref.watch(syncClientProvider);
  if (client == null) {
    return const SyncProgress(status: SyncStatus.notInitialized);
  }
  
  if (!client.isInitialized) {
    return const SyncProgress(status: SyncStatus.notInitialized);
  }
  
  return await client.getProgress();
});

/// Sync operations notifier.
/// 
/// Manages sync connection and manual sync operations.
class SyncNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  
  SyncNotifier(this._ref) : super(const AsyncValue.data(null));
  
  /// Initializes and connects to the sync server.
  Future<void> connect() async {
    state = const AsyncValue.loading();
    
    try {
      final client = _ref.read(syncClientProvider);
      if (client == null) {
        throw StateError('Sync client not configured');
      }
      
      if (!client.isInitialized) {
        await client.initialize();
      }
      
      await client.connect();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  /// Disconnects from the sync server.
  Future<void> disconnect() async {
    state = const AsyncValue.loading();
    
    try {
      final client = _ref.read(syncClientProvider);
      if (client == null) {
        state = const AsyncValue.data(null);
        return;
      }
      
      await client.disconnect();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  /// Triggers a manual sync.
  Future<void> sync() async {
    state = const AsyncValue.loading();
    
    try {
      final client = _ref.read(syncClientProvider);
      if (client == null) {
        throw StateError('Sync client not configured');
      }
      
      await client.sync();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  /// Closes the sync client and releases resources.
  Future<void> close() async {
    state = const AsyncValue.loading();
    
    try {
      final client = _ref.read(syncClientProvider);
      if (client == null) {
        state = const AsyncValue.data(null);
        return;
      }
      
      await client.close();
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
final pendingConflictsProvider = FutureProvider<List<SyncConflict>>((ref) async {
  // This would query the conflict table from the database
  // For now, return empty list
  return [];
});

/// Registered devices provider.
/// 
/// Returns list of devices registered for sync.
final registeredDevicesProvider = FutureProvider<List<SyncDevice>>((ref) async {
  // This would fetch from the sync server
  // For now, return empty list
  return [];
});

/// Whether sync is enabled and configured.
final isSyncEnabledProvider = Provider<bool>((ref) {
  final configAsync = ref.watch(syncConfigProvider);
  return configAsync.when(
    data: (config) => config != null,
    loading: () => false,
    error: (_, __) => false,
  );
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
*/
