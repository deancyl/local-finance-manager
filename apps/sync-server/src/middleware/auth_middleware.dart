import 'package:dart_frog/dart_frog.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dotenv/dotenv.dart' as dotenv;

/// Middleware for JWT authentication
Middleware authMiddleware() {
  return (handler) {
    return (context) async {
      final authHeader = context.request.headers['authorization'];
      
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.json(
          statusCode: 401,
          body: {'error': 'Missing or invalid authorization header'},
        );
      }

      final token = authHeader.substring(7);
      final jwtSecret = dotenv.env['JWT_SECRET'] ?? 'default-secret-change-in-production';
      
      try {
        final jwt = JWT.verify(token, SecretKey(jwtSecret));
        final userId = jwt.payload['sub'] as String?;
        
        if (userId == null) {
          return Response.json(
            statusCode: 401,
            body: {'error': 'Invalid token payload'},
          );
        }

        // Add user ID to context for use in handlers
        return handler(context.provide<String>(() => userId));
      } catch (e) {
        return Response.json(
          statusCode: 401,
          body: {'error': 'Invalid or expired token'},
        );
      }
    };
  };
}

/// Extension to easily get user ID from context
extension RequestContextX on RequestContext {
  String get userId {
    final id = read<String>();
    if (id == null) {
      throw StateError('User ID not found in context. Did you forget to use authMiddleware?');
    }
    return id;
  }
}
