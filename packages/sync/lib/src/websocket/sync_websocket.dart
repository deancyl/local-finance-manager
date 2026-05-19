import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logging/logging.dart';
import 'notification_models.dart';

final _log = Logger('SyncWebSocket');

/// WebSocket client for sync notifications.
class SyncWebSocket {
  final String serverUrl;
  final String jwtToken;
  
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _notificationController = StreamController<SyncNotification>.broadcast();
  
  bool _connected = false;
  bool _connecting = false;
  
  SyncWebSocket({
    required this.serverUrl,
    required this.jwtToken,
  });
  
  /// Stream of sync notifications.
  Stream<SyncNotification> get notifications => _notificationController.stream;
  
  /// Connect to WebSocket server.
  Future<void> connect() async {
    if (_connected || _connecting) return;
    
    _connecting = true;
    _log.info('Connecting to WebSocket: $serverUrl/ws');
    
    try {
      final uri = Uri.parse('$serverUrl/ws');
      _channel = WebSocketChannel.connect(uri);
      
      // Send auth token as first message
      _channel!.sink.add('auth:$jwtToken');
      
      // Listen for notifications
      _subscription = _channel!.stream.listen(
        (message) {
          if (message is String) {
            _handleMessage(message);
          }
        },
        onError: (error) {
          _log.severe('WebSocket error: $error');
          _connected = false;
          _scheduleReconnect();
        },
        onDone: () {
          _log.info('WebSocket closed');
          _connected = false;
          _scheduleReconnect();
        },
      );
      
      _connected = true;
      _connecting = false;
      _log.info('WebSocket connected');
    } catch (e) {
      _connecting = false;
      _log.severe('WebSocket connection failed: $e');
      _scheduleReconnect();
    }
  }
  
  /// Disconnect from server.
  Future<void> disconnect() async {
    _log.info('Disconnecting WebSocket...');
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _subscription = null;
    _connected = false;
    _notificationController.close();
  }
  
  /// Handle incoming message.
  void _handleMessage(String message) {
    try {
      final json = jsonDecode(message) as Map<String, dynamic>;
      final notification = SyncNotification.fromJson(json);
      _notificationController.add(notification);
      _log.fine('Received notification: ${notification.type}');
    } catch (e) {
      _log.warning('Failed to parse notification: $e');
    }
  }
  
  /// Schedule reconnect with exponential backoff.
  void _scheduleReconnect() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!_connected && !_connecting) {
        connect();
      }
    });
  }
  
  /// Check if connected.
  bool get isConnected => _connected;
}
