import 'package:dart_frog/dart_frog.dart';
import 'package:dotenv/dotenv.dart';
import '../src/services/websocket_service.dart';
import '../src/services/auth_service.dart';
import '../src/services/encryption_service.dart';

/// Middleware to provide WebSocket service to all routes.
Handler middleware(Handler handler) {
  final env = DotEnv(includePlatformEnvironment: true)..load();
  
  final jwtSecret = env.containsKey('JWT_SECRET')
      ? env['JWT_SECRET']!
      : 'default-secret';
  final encryptionKey = env.containsKey('ENCRYPTION_KEY')
      ? env['ENCRYPTION_KEY']!
      : 'default-key';
  final encryption = EncryptionService(encryptionKey);
  final authService = AuthService(encryption, jwtSecret);
  final wsService = WebSocketService(authService);
  
  return handler.use(
    provider<WebSocketService>((context) => wsService),
  );
}