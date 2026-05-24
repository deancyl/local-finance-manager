import 'package:shelf/shelf.dart' as shelf;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dotenv/dotenv.dart';

/// Middleware for JWT authentication using shelf
shelf.Middleware authMiddleware() {
  return (handler) {
    return (request) async {
      final authHeader = request.headers['authorization'];
      
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return shelf.Response.json(
          statusCode: 401,
          body: {'error': 'Missing or invalid authorization header'},
        );
      }

      final token = authHeader.substring(7);
      final env = DotEnv(includePlatformEnvironment: true)..load();
      final jwtSecret = env.containsKey('JWT_SECRET')
          ? env['JWT_SECRET']!
          : 'default-secret-change-in-production';
      
      try {
        final jwt = JWT.verify(token, SecretKey(jwtSecret));
        final userId = jwt.payload['sub'] as String?;
        
        if (userId == null) {
          return shelf.Response.json(
            statusCode: 401,
            body: {'error': 'Invalid token payload'},
          );
        }

        // Add user ID to request context for use in handlers
        // In shelf, we use request.context to store values
        final newRequest = request.change(context: {'userId': userId});
        return handler(newRequest);
      } catch (e) {
        return shelf.Response.json(
          statusCode: 401,
          body: {'error': 'Invalid or expired token'},
        );
      }
    };
  };
}

/// Helper to get userId from request context
String? getUserIdFromRequest(shelf.Request request) {
  return request.context['userId'] as String?;
}