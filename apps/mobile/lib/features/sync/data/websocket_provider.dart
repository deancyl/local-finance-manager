// DISABLED: sync package is temporarily disabled due to PowerSync compatibility issues
/*
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync/sync.dart';
import 'sync_provider.dart';
import 'auth_provider_impl.dart';

/// Token provider - gets the current auth token.
final authTokenProvider = FutureProvider<String?>((ref) async {
  final authProvider = ref.watch(authProviderImplProvider);
  if (authProvider == null) return null;
  return await authProvider.getToken();
});

/// WebSocket client provider.
final websocketProvider = Provider<SyncWebSocket?>((ref) {
  final config = ref.watch(syncConfigProvider);
  final tokenAsync = ref.watch(authTokenProvider);
  
  return config.when(
    data: (config) {
      if (config == null) return null;
      
      return tokenAsync.when(
        data: (token) {
          if (token == null) return null;
          
          return SyncWebSocket(
            serverUrl: config.serverUrl,
            jwtToken: token,
          );
        },
        loading: () => null,
        error: (_, __) => null,
      );
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// WebSocket connection state provider.
final websocketConnectedProvider = StateProvider<bool>((ref) {
  final ws = ref.watch(websocketProvider);
  return ws?.isConnected ?? false;
});

/// WebSocket notifications stream provider.
final websocketNotificationsProvider = StreamProvider<SyncNotification>((ref) {
  final ws = ref.watch(websocketProvider);
  if (ws == null) {
    return Stream.empty();
  }
  
  // Connect on first watch
  ws.connect();
  
  return ws.notifications;
});

/// WebSocket notifier for managing connection.
class WebSocketNotifier extends StateNotifier<AsyncValue<void>> {
  final SyncWebSocket _websocket;
  final Ref _ref;
  
  WebSocketNotifier(this._websocket, this._ref) : super(const AsyncValue.data(null));
  
  /// Connect to WebSocket.
  Future<void> connect() async {
    state = const AsyncValue.loading();
    try {
      await _websocket.connect();
      _ref.read(websocketConnectedProvider.notifier).state = true;
      state = const AsyncValue.data(null);
    } catch (e, st) {
      _ref.read(websocketConnectedProvider.notifier).state = false;
      state = AsyncValue.error(e, st);
    }
  }
  
  /// Disconnect from WebSocket.
  Future<void> disconnect() async {
    state = const AsyncValue.loading();
    try {
      await _websocket.disconnect();
      _ref.read(websocketConnectedProvider.notifier).state = false;
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final websocketNotifierProvider = StateNotifierProvider<WebSocketNotifier, AsyncValue<void>>((ref) {
  final ws = ref.watch(websocketProvider);
  if (ws == null) {
    return WebSocketNotifier(
      SyncWebSocket(serverUrl: '', jwtToken: ''),
      ref,
    );
  }
  return WebSocketNotifier(ws, ref);
});

/// Handler for sync notifications - triggers pull sync.
final notificationHandlerProvider = Provider<void>((ref) {
  final notifications = ref.watch(websocketNotificationsProvider);
  final syncNotifier = ref.read(syncNotifierProvider.notifier);
  
  notifications.when(
    data: (notification) {
      // On syncComplete or conflictDetected, trigger pull sync
      if (notification.type == NotificationType.syncComplete ||
          notification.type == NotificationType.conflictDetected) {
        syncNotifier.sync();
      }
    },
    loading: () {},
    error: (_, __) {},
  );
});
*/
