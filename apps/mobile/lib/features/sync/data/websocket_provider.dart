import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync/sync.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';

import 'sync_providers.dart';
import 'sync_feature_flag.dart';
import 'auth_provider_impl.dart';

final _log = Logger('WebSocketProvider');

/// Key for storing WebSocket feature flag in SharedPreferences.
const String _websocketFeatureFlagKey = 'websocket_feature_enabled';

/// Provider for WebSocket feature flag.
final websocketFeatureFlagProvider = NotifierProvider<WebSocketFeatureFlagNotifier, bool>(() {
  return WebSocketFeatureFlagNotifier();
});

/// Notifier for managing the WebSocket feature flag.
class WebSocketFeatureFlagNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadFromPrefs();
    return false;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final enabled = prefs.getBool(_websocketFeatureFlagKey) ?? false;
      state = enabled;
    } catch (e) {
      state = false;
    }
  }

  /// Enables or disables WebSocket real-time sync.
  Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(_websocketFeatureFlagKey, enabled);
      state = enabled;
      _log.info('WebSocket feature flag set to: $enabled');
    } catch (e) {
      state = !enabled;
      rethrow;
    }
  }

  /// Toggles the WebSocket feature.
  Future<void> toggle() async {
    await setEnabled(!state);
  }
}

/// Sync config provider for WebSocket connection.
/// 
/// Returns sync server URL if configured, null otherwise.
final syncServerUrlProvider = Provider<String?>((ref) {
  // This would normally come from user settings
  // For now, return null until user configures sync server
  return null;
});

/// Auth token provider for WebSocket authentication.
/// 
/// Returns JWT token if available, null otherwise.
final websocketAuthTokenProvider = Provider<String?>((ref) {
  final isSyncEnabled = ref.watch(syncFeatureFlagProvider);
  
  if (!isSyncEnabled) {
    return null;
  }
  
  // Watch the stored auth token provider
  final tokenAsync = ref.watch(storedAuthTokenProvider);
  
  return tokenAsync.when(
    data: (token) => token,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// WebSocket client provider.
/// 
/// Returns SyncWebSocket instance if sync is enabled and configured.
/// Returns null if sync or WebSocket feature is disabled or not configured.
final websocketProvider = Provider<SyncWebSocket?>((ref) {
  final isSyncEnabled = ref.watch(syncFeatureFlagProvider);
  final isWebsocketEnabled = ref.watch(websocketFeatureFlagProvider);
  
  if (!isSyncEnabled || !isWebsocketEnabled) {
    return null;
  }
  
  final serverUrl = ref.watch(syncServerUrlProvider);
  final token = ref.watch(websocketAuthTokenProvider);
  
  if (serverUrl == null || token == null) {
    return null;
  }
  
  return SyncWebSocket(
    serverUrl: serverUrl,
    jwtToken: token,
  );
});

/// WebSocket connection state provider.
final websocketConnectedProvider = StateProvider<bool>((ref) {
  final ws = ref.watch(websocketProvider);
  return ws?.isConnected ?? false;
});

/// WebSocket notifications stream provider.
/// 
/// Emits sync notifications from the WebSocket connection.
/// Returns empty stream if WebSocket is not available.
final websocketNotificationsProvider = StreamProvider<SyncNotification>((ref) {
  final ws = ref.watch(websocketProvider);
  
  if (ws == null) {
    _log.info('WebSocket not available, returning empty notifications stream');
    return Stream.empty();
  }
  
  // Auto-connect on first watch
  ref.onDispose(() {
    _log.info('Disposing WebSocket notifications provider');
    ws.disconnect();
  });
  
  // Start connection
  ws.connect();
  
  return ws.notifications;
});

/// WebSocket notifier for managing connection state.
class WebSocketNotifier extends StateNotifier<AsyncValue<bool>> {
  final SyncWebSocket? _websocket;
  final Ref _ref;
  
  WebSocketNotifier(this._websocket, this._ref) : super(const AsyncValue.data(false));
  
  /// Connect to WebSocket server.
  Future<void> connect() async {
    if (_websocket == null) {
      _log.warning('Cannot connect: WebSocket not configured');
      return;
    }
    
    state = const AsyncValue.loading();
    
    try {
      await _websocket!.connect();
      _ref.read(websocketConnectedProvider.notifier).state = true;
      state = const AsyncValue.data(true);
      _log.info('WebSocket connected successfully');
    } catch (e, st) {
      _ref.read(websocketConnectedProvider.notifier).state = false;
      state = AsyncValue.error(e, st);
      _log.severe('WebSocket connection failed: $e');
    }
  }
  
  /// Disconnect from WebSocket server.
  Future<void> disconnect() async {
    if (_websocket == null) {
      return;
    }
    
    state = const AsyncValue.loading();
    
    try {
      await _websocket!.disconnect();
      _ref.read(websocketConnectedProvider.notifier).state = false;
      state = const AsyncValue.data(false);
      _log.info('WebSocket disconnected');
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  /// Check current connection state.
  bool get isConnected => _websocket?.isConnected ?? false;
}

/// WebSocket notifier provider.
final websocketNotifierProvider = StateNotifierProvider<WebSocketNotifier, AsyncValue<bool>>((ref) {
  final ws = ref.watch(websocketProvider);
  return WebSocketNotifier(ws, ref);
});

/// Handler for sync notifications - triggers pull sync on remote changes.
/// 
/// This provider watches WebSocket notifications and triggers
/// sync operations when relevant notifications arrive.
final notificationHandlerProvider = Provider<void>((ref) {
  final notifications = ref.watch(websocketNotificationsProvider);
  final syncNotifier = ref.read(syncNotifierProvider.notifier);
  final isSyncEnabled = ref.read(syncFeatureFlagProvider);
  
  notifications.when(
    data: (notification) {
      _log.info('Received WebSocket notification: ${notification.type}');
      
      if (!isSyncEnabled) {
        _log.warning('Received notification but sync is disabled');
        return;
      }
      
      // On syncComplete or conflictDetected from remote, trigger pull sync
      if (notification.type == NotificationType.syncComplete ||
          notification.type == NotificationType.conflictDetected) {
        _log.info('Triggering sync due to notification: ${notification.type}');
        syncNotifier.sync();
      }
    },
    loading: () {
      _log.fine('WebSocket notifications loading...');
    },
    error: (error, _) {
      _log.warning('WebSocket notifications error: $error');
    },
  );
});

/// Whether WebSocket real-time sync is available.
/// 
/// Returns true if both sync and WebSocket features are enabled
/// and the WebSocket client is properly configured.
final isWebsocketAvailableProvider = Provider<bool>((ref) {
  final isSyncEnabled = ref.watch(syncFeatureFlagProvider);
  final isWebsocketEnabled = ref.watch(websocketFeatureFlagProvider);
  final hasConfig = ref.watch(websocketProvider) != null;
  
  return isSyncEnabled && isWebsocketEnabled && hasConfig;
});

/// WebSocket connection status display name.
final websocketStatusDisplayProvider = Provider<String>((ref) {
  final isConnected = ref.watch(websocketConnectedProvider);
  final isAvailable = ref.watch(isWebsocketAvailableProvider);
  final notifierState = ref.watch(websocketNotifierProvider);
  
  if (!isAvailable) {
    return 'Not Configured';
  }
  
  return notifierState.when(
    data: (connected) => connected ? 'Connected' : 'Disconnected',
    loading: () => 'Connecting...',
    error: (_, __) => 'Error',
  );
});