/// Error recovery and resilience utilities (v0.3.120)
/// 
/// Provides graceful error handling, retry mechanisms,
/// and circuit breaker patterns for improved stability.

import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Retry configuration.
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
  });

  /// Calculates the delay for a given attempt.
  Duration delayForAttempt(int attempt) {
    final delayMs = initialDelay.inMilliseconds *
        pow(backoffMultiplier, attempt - 1).toInt();
    return Duration(
      milliseconds: delayMs.clamp(0, maxDelay.inMilliseconds) as int,
    );
  }
}

/// Retry executor with exponential backoff.
class RetryExecutor {
  final RetryConfig config;
  final _attemptCounts = <String, int>{};

  RetryExecutor({this.config = const RetryConfig()});

  /// Executes an operation with retry logic.
  Future<T> execute<T>({
    required String operationId,
    required Future<T> Function() operation,
    void Function(int attempt, Object error)? onRetry,
  }) async {
    var attempt = _attemptCounts[operationId] ?? 0;
    
    while (true) {
      try {
        final result = await operation();
        _attemptCounts.remove(operationId);
        return result;
      } catch (e) {
        attempt++;
        _attemptCounts[operationId] = attempt;
        
        if (attempt >= config.maxAttempts) {
          _attemptCounts.remove(operationId);
          rethrow;
        }
        
        onRetry?.call(attempt, e);
        
        await Future.delayed(config.delayForAttempt(attempt));
      }
    }
  }

  /// Resets the attempt count for an operation.
  void reset(String operationId) {
    _attemptCounts.remove(operationId);
  }

  /// Resets all attempt counts.
  void resetAll() {
    _attemptCounts.clear();
  }
}

/// Circuit breaker state.
enum CircuitState {
  closed,    // Normal operation
  open,      // Failing, rejecting calls
  halfOpen,  // Testing if recovered
}

/// Circuit breaker for preventing cascade failures.
class CircuitBreaker {
  final int failureThreshold;
  final Duration resetTimeout;
  final Duration halfOpenTimeout;
  
  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  Timer? _resetTimer;

  CircuitBreaker({
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(seconds: 60),
    this.halfOpenTimeout = const Duration(seconds: 10),
  });

  CircuitState get state => _state;
  int get failureCount => _failureCount;

  /// Executes an operation through the circuit breaker.
  Future<T> execute<T>({
    required Future<T> Function() operation,
    required Future<T> Function() fallback,
  }) async {
    if (_state == CircuitState.open) {
      return fallback();
    }

    try {
      final result = await operation();
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure();
      if (_state == CircuitState.open) {
        return fallback();
      }
      rethrow;
    }
  }

  void _onSuccess() {
    _failureCount = 0;
    if (_state == CircuitState.halfOpen) {
      _state = CircuitState.closed;
      _resetTimer?.cancel();
    }
  }

  void _onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_failureCount >= failureThreshold) {
      _state = CircuitState.open;
      _resetTimer?.cancel();
      _resetTimer = Timer(resetTimeout, () {
        _state = CircuitState.halfOpen;
        _resetTimer = Timer(halfOpenTimeout, () {
          if (_state == CircuitState.halfOpen) {
            // Still failing, go back to open
            _state = CircuitState.open;
          }
        });
      });
    }
  }

  /// Resets the circuit breaker.
  void reset() {
    _state = CircuitState.closed;
    _failureCount = 0;
    _lastFailureTime = null;
    _resetTimer?.cancel();
  }
}

/// Error recovery handler for managing errors gracefully.
class ErrorRecoveryHandler {
  static final ErrorRecoveryHandler _instance = ErrorRecoveryHandler._internal();
  factory ErrorRecoveryHandler() => _instance;
  ErrorRecoveryHandler._internal();

  final _retryExecutor = RetryExecutor();
  final _circuitBreakers = <String, CircuitBreaker>{};
  final _errorHandlers = <Type, Future<void> Function(Object error, StackTrace stack)>{};

  /// Registers an error handler for a specific error type.
  void registerHandler<T>(
    Future<void> Function(T error, StackTrace stack) handler,
  ) {
    _errorHandlers[T] = (error, stack) => handler(error as T, stack);
  }

  /// Gets or creates a circuit breaker for an operation.
  CircuitBreaker getCircuitBreaker(String operationId) {
    return _circuitBreakers.putIfAbsent(
      operationId,
      () => CircuitBreaker(),
    );
  }

  /// Executes an operation with error recovery.
  Future<T?> executeWithRecovery<T>({
    required String operationId,
    required Future<T> Function() operation,
    required Future<T> Function() fallback,
    RetryConfig? retryConfig,
  }) async {
    try {
      // Try with retry
      if (retryConfig != null) {
        return await _retryExecutor.execute(
          operationId: operationId,
          operation: operation,
        );
      }

      // Use circuit breaker
      final circuit = getCircuitBreaker(operationId);
      return await circuit.execute(
        operation: operation,
        fallback: fallback,
      );
    } catch (e, st) {
      // Try to handle the error
      final handler = _errorHandlers[e.runtimeType];
      if (handler != null) {
        await handler(e, st);
      }
      
      // Return fallback result
      return await fallback();
    }
  }

  /// Handles an error using registered handlers.
  Future<void> handleError(Object error, StackTrace stack) async {
    final handler = _errorHandlers[error.runtimeType];
    if (handler != null) {
      await handler(error, stack);
    } else {
      print('Unhandled error: $error');
      print('Stack trace: $stack');
    }
  }
}

/// Provider for error recovery handler.
final errorRecoveryProvider = Provider<ErrorRecoveryHandler>((ref) {
  return ErrorRecoveryHandler();
});

/// Provider for retry executor.
final retryExecutorProvider = Provider<RetryExecutor>((ref) {
  return RetryExecutor();
});
