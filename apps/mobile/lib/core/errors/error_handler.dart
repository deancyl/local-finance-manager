import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Comprehensive error handler utility for the application.
/// 
/// Provides centralized error handling, logging, and recovery mechanisms
/// for consistent error management across the app.
class ErrorHandler {
  ErrorHandler._();

  /// Global error handler for uncaught errors
  static void initialize() {
    // Catch Flutter framework errors
    FlutterError.onError = (details) {
      _logError('Flutter Error', details.exception, details.stack);
      _handleCriticalError(details.exception, details.stack);
    };

    // Catch async errors not caught by Flutter
    PlatformDispatcher.instance.onError = (error, stack) {
      _logError('Platform Error', error, stack);
      _handleCriticalError(error, stack);
      return true;
    };

    // Catch errors in zones
    runZonedGuarded(
      () {
        // Zone is active for the entire app lifecycle
      },
      (error, stack) {
        _logError('Zone Error', error, stack);
        _handleCriticalError(error, stack);
      },
    );
  }

  /// Handles an error with appropriate logging and recovery
  static void handle(
    Object error, {
    StackTrace? stackTrace,
    String? context,
    bool showDialog = false,
    VoidCallback? onRetry,
  }) {
    _logError(context ?? 'App Error', error, stackTrace);

    if (showDialog) {
      _showErrorDialog(error, onRetry: onRetry);
    }
  }

  /// Wraps an async operation with error handling
  static Future<T?> wrapAsync<T>(
    Future<T> Function() operation, {
    String? context,
    bool showDialog = false,
    T Function()? onError,
    VoidCallback? onRetry,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      handle(
        error,
        stackTrace: stackTrace,
        context: context,
        showDialog: showDialog,
        onRetry: onRetry,
      );
      return onError?.call();
    }
  }

  /// Wraps a synchronous operation with error handling
  static T? wrapSync<T>(
    T Function() operation, {
    String? context,
    bool showDialog = false,
    T Function()? onError,
  }) {
    try {
      return operation();
    } catch (error, stackTrace) {
      handle(
        error,
        stackTrace: stackTrace,
        context: context,
        showDialog: showDialog,
      );
      return onError?.call();
    }
  }

  /// Executes an operation with retry logic
  static Future<T> withRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
    String? context,
    bool exponentialBackoff = true,
  }) async {
    int attempt = 0;
    Object? lastError;
    StackTrace? lastStackTrace;

    while (attempt < maxRetries) {
      try {
        return await operation();
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        attempt++;

        if (attempt < maxRetries) {
          final waitTime = exponentialBackoff
              ? delay * (1 << (attempt - 1))
              : delay;
          
          _logError(
            '${context ?? 'Operation'} failed (attempt $attempt/$maxRetries)',
            error,
            stackTrace,
          );

          await Future.delayed(waitTime);
        }
      }
    }

    _logError(
      '${context ?? 'Operation'} failed after $maxRetries attempts',
      lastError!,
      lastStackTrace,
    );

    throw lastError;
  }

  /// Logs an error with context
  static void _logError(
    String context,
    Object error,
    StackTrace? stackTrace,
  ) {
    debugPrint('=== ERROR: $context ===');
    debugPrint('Error: $error');
    if (stackTrace != null) {
      debugPrint('Stack trace:\n$stackTrace');
    }
    debugPrint('========================');
  }

  /// Handles critical errors that may crash the app
  static void _handleCriticalError(Object error, StackTrace? stackTrace) {
    // In production, this would send to crash reporting service
    // For now, just log it
    _logError('CRITICAL ERROR', error, stackTrace);
  }

  /// Shows an error dialog to the user
  static void _showErrorDialog(
    Object error, {
    VoidCallback? onRetry,
  }) {
    // This would be implemented with actual dialog UI
    // For now, just log that we would show a dialog
    debugPrint('Would show error dialog for: $error');
    if (onRetry != null) {
      debugPrint('Retry option available');
    }
  }
}

/// Riverpod provider for global error handling
final errorHandlerProvider = Provider<ErrorHandler>((ref) {
  return ErrorHandler._();
});

/// Mixin for widgets that need error handling
mixin ErrorHandlerMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// Handles an error with optional retry
  void handleError(
    Object error, {
    StackTrace? stackTrace,
    String? context,
    bool showDialog = true,
    VoidCallback? onRetry,
  }) {
    ErrorHandler.handle(
      error,
      stackTrace: stackTrace,
      context: context,
      showDialog: showDialog,
      onRetry: onRetry,
    );
  }

  /// Wraps an async operation with error handling
  Future<T?> wrapAsync<T>(
    Future<T> Function() operation, {
    String? context,
    bool showDialog = true,
    T Function()? onError,
    VoidCallback? onRetry,
  }) {
    return ErrorHandler.wrapAsync(
      operation,
      context: context,
      showDialog: showDialog,
      onError: onError,
      onRetry: onRetry,
    );
  }
}

/// Extension methods for easier error handling on Future and Stream
extension ErrorHandlingFutureExtension<T> on Future<T> {
  /// Handles errors with the ErrorHandler
  Future<T?> handleErrors({
    String? context,
    bool showDialog = false,
    T Function()? onError,
  }) async {
    return ErrorHandler.wrapAsync(
      () => this,
      context: context,
      showDialog: showDialog,
      onError: onError,
    );
  }
}

extension ErrorHandlingStreamExtension<T> on Stream<T> {
  /// Handles errors with the ErrorHandler
  Stream<T> handleErrors({
    String? context,
    bool showDialog = false,
  }) {
    return handleError(
      (error, stackTrace) {
        ErrorHandler.handle(
          error,
          stackTrace: stackTrace,
          context: context,
          showDialog: showDialog,
        );
      },
    );
  }
}
