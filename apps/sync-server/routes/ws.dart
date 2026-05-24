import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_web_socket/dart_frog_web_socket.dart';
import 'package:dotenv/dotenv.dart';
import '../src/services/websocket_service.dart';
import '../src/services/auth_service.dart';
import '../src/services/encryption_service.dart';

/// WebSocket endpoint for sync notifications.
/// 
/// Protocol:
/// 1. Client connects and sends: "auth:<jwt_token>"
/// 2. Server validates token and subscribes channel to user's notifications
/// 3. Server broadcasts sync notifications to subscribed channels
/// 4. Ping/pong every 30 seconds for keepalive
Handler get onRequest => webSocketHandler(
  _handleWebSocket,
  pingInterval: const Duration(seconds: 30),
);

Future<void> _handleWebSocket(
  WebSocketChannel channel,
  String? protocol,
) async {
  // Load dotenv
  final env = DotEnv(includePlatformEnvironment: true)..load();
  
  final jwtSecret = env.containsKey('JWT_SECRET')
      ? env['JWT_SECRET']!
      : 'default-secret';
  final encryptionKey = env.containsKey('ENCRYPTION_KEY')
      ? env['ENCRYPTION_KEY']!
      : 'default-key';
  final encryption = EncryptionService(encryptionKey);
  final wsService = WebSocketService(AuthService(encryption, jwtSecret));
  
  String? userId;
  bool authenticated = false;
  
  channel.stream.listen(
    (message) {
      if (message is String) {
        // First message must be auth token
        if (!authenticated && message.startsWith('auth:')) {
          final token = message.substring(5);
          userId = wsService.validateToken(token, jwtSecret);
          
          if (userId != null) {
            authenticated = true;
            wsService.subscribe(channel, userId!);
            channel.sink.add(jsonEncode({
              'type': 'connected',
              'timestamp': DateTime.now().toIso8601String(),
            }));
          } else {
            channel.sink.add(jsonEncode({
              'type': 'auth_failed',
              'message': 'Invalid token',
            }));
            channel.sink.close(1008, 'Authentication failed');
          }
        }
        
        // After auth, handle other messages
        if (authenticated) {
          // Could handle ping/pong or other client messages here
        }
      }
    },
    onDone: () {
      if (userId != null) {
        wsService.unsubscribe(channel, userId!);
      }
    },
    onError: (error) {
      if (userId != null) {
        wsService.unsubscribe(channel, userId!);
      }
    },
  );
}
