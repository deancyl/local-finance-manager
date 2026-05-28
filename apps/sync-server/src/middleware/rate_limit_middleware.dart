import 'package:shelf/shelf.dart' as shelf;

/// Rate limit entry for tracking requests per IP
class RateLimitEntry {
  final int maxRequests;
  final Duration window;
  int tokens;
  DateTime lastRefill;

  RateLimitEntry({
    required this.maxRequests,
    required this.window,
  })  : tokens = maxRequests,
        lastRefill = DateTime.now();

  /// Check if request is allowed using token bucket algorithm
  bool isAllowed() {
    _refillTokens();
    if (tokens > 0) {
      tokens--;
      return true;
    }
    return false;
  }

  /// Get seconds until next token is available
  int getRetryAfterSeconds() {
    _refillTokens();
    if (tokens > 0) return 0;
    
    final refillInterval = window.inSeconds ~/ maxRequests;
    final elapsed = DateTime.now().difference(lastRefill).inSeconds;
    return refillInterval - (elapsed % refillInterval);
  }

  void _refillTokens() {
    final now = DateTime.now();
    final elapsed = now.difference(lastRefill);
    
    if (elapsed >= window) {
      tokens = maxRequests;
      lastRefill = now;
    }
  }
}

/// In-memory rate limit store (IP -> endpoint -> entry)
final Map<String, Map<String, RateLimitEntry>> _rateLimitStore = {};

/// Create rate limiting middleware for specific endpoint
shelf.Middleware rateLimitMiddleware({
  required String endpoint,
  required int maxRequests,
  required Duration window,
}) {
  return (shelf.Handler handler) {
    return (shelf.Request request) async {
      final clientIp = _getClientIp(request);
      
      // Get or create rate limit entry
      if (!_rateLimitStore.containsKey(clientIp)) {
        _rateLimitStore[clientIp] = {};
      }
      
      if (!_rateLimitStore[clientIp]!.containsKey(endpoint)) {
        _rateLimitStore[clientIp]![endpoint] = RateLimitEntry(
          maxRequests: maxRequests,
          window: window,
        );
      }
      
      final entry = _rateLimitStore[clientIp]![endpoint]!;
      
      if (!entry.isAllowed()) {
        final retryAfter = entry.getRetryAfterSeconds();
        return shelf.Response(
          429,
          headers: {
            'Content-Type': 'application/json',
            'Retry-After': retryAfter.toString(),
          },
          body: '{"error":"Too many requests. Please try again in $retryAfter seconds."}',
        );
      }
      
      return handler(request);
    };
  };
}

/// Extract client IP from request
String _getClientIp(shelf.Request request) {
  // Check X-Forwarded-For header first (for reverse proxy scenarios)
  final forwardedFor = request.headers['x-forwarded-for'];
  if (forwardedFor != null && forwardedFor.isNotEmpty) {
    // Take the first IP in the chain
    return forwardedFor.split(',').first.trim();
  }
  
  // Check X-Real-IP header
  final realIp = request.headers['x-real-ip'];
  if (realIp != null && realIp.isNotEmpty) {
    return realIp;
  }
  
  // Fallback to a default (in production, this would come from connection info)
  return 'unknown';
}

/// Clear rate limit entries for testing
void clearRateLimitStore() {
  _rateLimitStore.clear();
}
