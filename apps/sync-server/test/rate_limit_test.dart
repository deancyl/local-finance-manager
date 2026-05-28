import 'package:test/test.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:sync_server/src/middleware/rate_limit_middleware.dart';

void main() {
  group('RateLimitMiddleware', () {
    setUp(() {
      // Clear rate limit store before each test
      clearRateLimitStore();
    });

    test('allows requests within limit', () async {
      final middleware = rateLimitMiddleware(
        endpoint: 'test',
        maxRequests: 5,
        window: Duration(minutes: 1),
      );

      final handler = middleware((request) async {
        return shelf.Response(200, body: '{"success": true}');
      });

      // Make 5 requests - all should succeed
      for (var i = 0; i < 5; i++) {
        final request = shelf.Request(
          'POST',
          Uri.parse('http://localhost/test'),
          headers: {'X-Real-IP': '192.168.1.1'},
        );
        final response = await handler(request);
        expect(response.statusCode, equals(200));
      }
    });

    test('blocks requests exceeding limit with 429 status', () async {
      final middleware = rateLimitMiddleware(
        endpoint: 'test',
        maxRequests: 5,
        window: Duration(minutes: 1),
      );

      final handler = middleware((request) async {
        return shelf.Response(200, body: '{"success": true}');
      });

      // Make 5 requests - all should succeed
      for (var i = 0; i < 5; i++) {
        final request = shelf.Request(
          'POST',
          Uri.parse('http://localhost/test'),
          headers: {'X-Real-IP': '192.168.1.2'},
        );
        final response = await handler(request);
        expect(response.statusCode, equals(200));
      }

      // 6th request should be blocked
      final request = shelf.Request(
        'POST',
        Uri.parse('http://localhost/test'),
        headers: {'X-Real-IP': '192.168.1.2'},
      );
      final response = await handler(request);
      expect(response.statusCode, equals(429));
    });

    test('includes Retry-After header in 429 response', () async {
      final middleware = rateLimitMiddleware(
        endpoint: 'test',
        maxRequests: 5,
        window: Duration(minutes: 1),
      );

      final handler = middleware((request) async {
        return shelf.Response(200, body: '{"success": true}');
      });

      // Exhaust the limit
      for (var i = 0; i < 5; i++) {
        final request = shelf.Request(
          'POST',
          Uri.parse('http://localhost/test'),
          headers: {'X-Real-IP': '192.168.1.3'},
        );
        await handler(request);
      }

      // Check 429 response has Retry-After header
      final request = shelf.Request(
        'POST',
        Uri.parse('http://localhost/test'),
        headers: {'X-Real-IP': '192.168.1.3'},
      );
      final response = await handler(request);
      expect(response.statusCode, equals(429));
      expect(response.headers.containsKey('Retry-After'), isTrue);
      expect(int.tryParse(response.headers['Retry-After'] ?? ''), isNotNull);
    });

    test('tracks rate limits per IP address', () async {
      final middleware = rateLimitMiddleware(
        endpoint: 'test',
        maxRequests: 5,
        window: Duration(minutes: 1),
      );

      final handler = middleware((request) async {
        return shelf.Response(200, body: '{"success": true}');
      });

      // Make 5 requests from IP 1 - all should succeed
      for (var i = 0; i < 5; i++) {
        final request = shelf.Request(
          'POST',
          Uri.parse('http://localhost/test'),
          headers: {'X-Real-IP': '192.168.1.10'},
        );
        final response = await handler(request);
        expect(response.statusCode, equals(200));
      }

      // 6th request from IP 1 should be blocked
      var request = shelf.Request(
        'POST',
        Uri.parse('http://localhost/test'),
        headers: {'X-Real-IP': '192.168.1.10'},
      );
      var response = await handler(request);
      expect(response.statusCode, equals(429));

      // But request from IP 2 should succeed
      request = shelf.Request(
        'POST',
        Uri.parse('http://localhost/test'),
        headers: {'X-Real-IP': '192.168.1.20'},
      );
      response = await handler(request);
      expect(response.statusCode, equals(200));
    });

    test('tracks rate limits per endpoint', () async {
      final loginMiddleware = rateLimitMiddleware(
        endpoint: 'login',
        maxRequests: 5,
        window: Duration(minutes: 1),
      );

      final registerMiddleware = rateLimitMiddleware(
        endpoint: 'register',
        maxRequests: 3,
        window: Duration(minutes: 1),
      );

      final loginHandler = loginMiddleware((request) async {
        return shelf.Response(200, body: '{"success": true}');
      });

      final registerHandler = registerMiddleware((request) async {
        return shelf.Response(200, body: '{"success": true}');
      });

      // Exhaust login limit (5 requests)
      for (var i = 0; i < 5; i++) {
        final request = shelf.Request(
          'POST',
          Uri.parse('http://localhost/login'),
          headers: {'X-Real-IP': '192.168.1.30'},
        );
        final response = await loginHandler(request);
        expect(response.statusCode, equals(200));
      }

      // 6th login should be blocked
      var request = shelf.Request(
        'POST',
        Uri.parse('http://localhost/login'),
        headers: {'X-Real-IP': '192.168.1.30'},
      );
      var response = await loginHandler(request);
      expect(response.statusCode, equals(429));

      // But register should still work (only 0 requests so far)
      request = shelf.Request(
        'POST',
        Uri.parse('http://localhost/register'),
        headers: {'X-Real-IP': '192.168.1.30'},
      );
      response = await registerHandler(request);
      expect(response.statusCode, equals(200));

      // Exhaust register limit (3 requests total)
      for (var i = 0; i < 2; i++) {
        final req = shelf.Request(
          'POST',
          Uri.parse('http://localhost/register'),
          headers: {'X-Real-IP': '192.168.1.30'},
        );
        await registerHandler(req);
      }

      // 4th register should be blocked
      request = shelf.Request(
        'POST',
        Uri.parse('http://localhost/register'),
        headers: {'X-Real-IP': '192.168.1.30'},
      );
      response = await registerHandler(request);
      expect(response.statusCode, equals(429));
    });

    test('login endpoint: max 5 requests/min per IP', () async {
      final middleware = rateLimitMiddleware(
        endpoint: 'login',
        maxRequests: 5,
        window: Duration(minutes: 1),
      );

      final handler = middleware((request) async {
        return shelf.Response(200, body: '{"token": "test"}');
      });

      // Make 5 login attempts - all should succeed
      for (var i = 0; i < 5; i++) {
        final request = shelf.Request(
          'POST',
          Uri.parse('http://localhost/api/v1/auth/login'),
          headers: {'X-Real-IP': '10.0.0.1'},
        );
        final response = await handler(request);
        expect(response.statusCode, equals(200));
      }

      // 6th login attempt should return 429
      final request = shelf.Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/login'),
        headers: {'X-Real-IP': '10.0.0.1'},
      );
      final response = await handler(request);
      expect(response.statusCode, equals(429));
      expect(response.headers['Retry-After'], isNotNull);
    });

    test('register endpoint: max 3 requests/min per IP', () async {
      final middleware = rateLimitMiddleware(
        endpoint: 'register',
        maxRequests: 3,
        window: Duration(minutes: 1),
      );

      final handler = middleware((request) async {
        return shelf.Response(200, body: '{"user": "created"}');
      });

      // Make 3 register attempts - all should succeed
      for (var i = 0; i < 3; i++) {
        final request = shelf.Request(
          'POST',
          Uri.parse('http://localhost/api/v1/auth/register'),
          headers: {'X-Real-IP': '10.0.0.2'},
        );
        final response = await handler(request);
        expect(response.statusCode, equals(200));
      }

      // 4th register attempt should return 429
      final request = shelf.Request(
        'POST',
        Uri.parse('http://localhost/api/v1/auth/register'),
        headers: {'X-Real-IP': '10.0.0.2'},
      );
      final response = await handler(request);
      expect(response.statusCode, equals(429));
      expect(response.headers['Retry-After'], isNotNull);
    });

    test('extracts IP from X-Forwarded-For header', () async {
      final middleware = rateLimitMiddleware(
        endpoint: 'test',
        maxRequests: 2,
        window: Duration(minutes: 1),
      );

      final handler = middleware((request) async {
        return shelf.Response(200, body: '{"success": true}');
      });

      // Make 2 requests with X-Forwarded-For
      for (var i = 0; i < 2; i++) {
        final request = shelf.Request(
          'POST',
          Uri.parse('http://localhost/test'),
          headers: {'X-Forwarded-For': '203.0.113.1, 70.41.3.18'},
        );
        final response = await handler(request);
        expect(response.statusCode, equals(200));
      }

      // 3rd request should be blocked
      final request = shelf.Request(
        'POST',
        Uri.parse('http://localhost/test'),
        headers: {'X-Forwarded-For': '203.0.113.1, 70.41.3.18'},
      );
      final response = await handler(request);
      expect(response.statusCode, equals(429));
    });

    test('429 response body contains error message', () async {
      final middleware = rateLimitMiddleware(
        endpoint: 'test',
        maxRequests: 1,
        window: Duration(minutes: 1),
      );

      final handler = middleware((request) async {
        return shelf.Response(200, body: '{"success": true}');
      });

      // First request succeeds
      var request = shelf.Request(
        'POST',
        Uri.parse('http://localhost/test'),
        headers: {'X-Real-IP': '10.0.0.100'},
      );
      await handler(request);

      // Second request gets 429
      request = shelf.Request(
        'POST',
        Uri.parse('http://localhost/test'),
        headers: {'X-Real-IP': '10.0.0.100'},
      );
      final response = await handler(request);
      expect(response.statusCode, equals(429));
      
      final body = await response.readAsString();
      expect(body, contains('Too many requests'));
      expect(body, contains('Retry-After'));
    });
  });
}
