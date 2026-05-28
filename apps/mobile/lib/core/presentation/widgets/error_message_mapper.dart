/// Error type taxonomy for the application.
/// 
/// Provides a unified classification of errors across the app
/// for consistent handling and user messaging.
enum AppErrorType {
  /// Network connectivity issues
  network,
  
  /// Authentication/authorization failures
  auth,
  
  /// Database/storage errors
  database,
  
  /// Data validation errors
  validation,
  
  /// Request timeout errors
  timeout,
  
  /// Server-side errors (5xx)
  server,
  
  /// Data conflict errors
  conflict,
  
  /// Unknown/unclassified errors
  unknown,
}

/// Base exception class for application errors.
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final AppErrorType type;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppException({
    required this.message,
    this.code,
    required this.type,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'AppException($type): $message';
}

/// Network-related exceptions
class NetworkException extends AppException {
  const NetworkException({
    super.message = '网络连接失败',
    super.code,
    super.originalError,
    super.stackTrace,
  }) : super(type: AppErrorType.network);
}

/// Authentication-related exceptions
class AuthException extends AppException {
  const AuthException({
    super.message = '认证失败',
    super.code,
    super.originalError,
    super.stackTrace,
  }) : super(type: AppErrorType.auth);
}

/// Database/storage-related exceptions
class DatabaseException extends AppException {
  const DatabaseException({
    super.message = '数据操作失败',
    super.code,
    super.originalError,
    super.stackTrace,
  }) : super(type: AppErrorType.database);
}

/// Validation-related exceptions
class ValidationException extends AppException {
  const ValidationException({
    super.message = '数据验证失败',
    super.code,
    super.originalError,
    super.stackTrace,
  }) : super(type: AppErrorType.validation);
}

/// Timeout-related exceptions
class TimeoutException extends AppException {
  const TimeoutException({
    super.message = '请求超时',
    super.code,
    super.originalError,
    super.stackTrace,
  }) : super(type: AppErrorType.timeout);
}

/// Server-related exceptions
class ServerException extends AppException {
  const ServerException({
    super.message = '服务器错误',
    super.code,
    super.originalError,
    super.stackTrace,
  }) : super(type: AppErrorType.server);
}

/// Conflict-related exceptions
class ConflictException extends AppException {
  const ConflictException({
    super.message = '数据冲突',
    super.code,
    super.originalError,
    super.stackTrace,
  }) : super(type: AppErrorType.conflict);
}

/// Utility class for mapping errors to user-friendly Chinese messages.
/// 
/// Centralizes all error message logic for consistency and maintainability.
class ErrorMessageMapper {
  ErrorMessageMapper._();

  /// Maps an error to a user-friendly Chinese message.
  static String map(Object error) {
    // Handle AppException types directly
    if (error is AppException) {
      return _mapAppException(error);
    }

    // Handle common Dart/Flutter exceptions
    if (error is FormatException) {
      return '数据格式错误，请检查输入';
    }

    if (error is ArgumentError) {
      return '参数错误，请检查输入';
    }

    if (error is StateError) {
      return '状态错误，请刷新页面';
    }

    if (error is UnimplementedError) {
      return '功能暂未实现';
    }

    if (error is UnsupportedError) {
      return '不支持的操作';
    }

    if (error is RangeError) {
      return '数值超出范围';
    }

    // Handle async errors
    if (error.toString().contains('SocketException') ||
        error.toString().contains('Connection refused') ||
        error.toString().contains('Connection timed out')) {
      return '网络连接失败，请检查网络设置';
    }

    if (error.toString().contains('401') ||
        error.toString().contains('Unauthorized')) {
      return '登录已过期，请重新登录';
    }

    if (error.toString().contains('403') ||
        error.toString().contains('Forbidden')) {
      return '没有权限执行此操作';
    }

    if (error.toString().contains('404') ||
        error.toString().contains('Not Found')) {
      return '请求的资源不存在';
    }

    if (error.toString().contains('500') ||
        error.toString().contains('Internal Server Error')) {
      return '服务器暂时不可用，请稍后重试';
    }

    if (error.toString().contains('502') ||
        error.toString().contains('Bad Gateway')) {
      return '服务器网关错误，请稍后重试';
    }

    if (error.toString().contains('503') ||
        error.toString().contains('Service Unavailable')) {
      return '服务暂时不可用，请稍后重试';
    }

    if (error.toString().contains('TimeoutException') ||
        error.toString().contains('Timeout')) {
      return '请求超时，请重试';
    }

    // Default fallback
    return '操作失败，请稍后重试';
  }

  /// Maps AppException to user-friendly message
  static String _mapAppException(AppException error) {
    return switch (error.type) {
      AppErrorType.network => '网络连接失败，请检查网络设置',
      AppErrorType.auth => '登录已过期，请重新登录',
      AppErrorType.database => '数据加载失败，请稍后重试',
      AppErrorType.validation => '数据验证失败，请检查输入',
      AppErrorType.timeout => '请求超时，请重试',
      AppErrorType.server => '服务器暂时不可用，请稍后重试',
      AppErrorType.conflict => '数据冲突，需要手动解决',
      AppErrorType.unknown => '操作失败，请稍后重试',
    };
  }

  /// Gets the error type from an error object
  static AppErrorType getErrorType(Object error) {
    if (error is AppException) {
      return error.type;
    }

    // Infer type from error string
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('socket') ||
        errorString.contains('connection') ||
        errorString.contains('network')) {
      return AppErrorType.network;
    }

    if (errorString.contains('401') ||
        errorString.contains('403') ||
        errorString.contains('unauthorized') ||
        errorString.contains('forbidden') ||
        errorString.contains('auth')) {
      return AppErrorType.auth;
    }

    if (errorString.contains('database') ||
        errorString.contains('sql') ||
        errorString.contains('storage')) {
      return AppErrorType.database;
    }

    if (errorString.contains('validation') ||
        errorString.contains('invalid') ||
        errorString.contains('format')) {
      return AppErrorType.validation;
    }

    if (errorString.contains('timeout')) {
      return AppErrorType.timeout;
    }

    if (errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('server')) {
      return AppErrorType.server;
    }

    if (errorString.contains('conflict') ||
        errorString.contains('duplicate')) {
      return AppErrorType.conflict;
    }

    return AppErrorType.unknown;
  }

  /// Checks if an error is retryable
  static bool isRetryable(Object error) {
    final type = getErrorType(error);
    return type == AppErrorType.network ||
        type == AppErrorType.timeout ||
        type == AppErrorType.server;
  }

  /// Gets a suggested action for an error
  static String getSuggestedAction(Object error) {
    final type = getErrorType(error);
    return switch (type) {
      AppErrorType.network => '请检查网络连接后重试',
      AppErrorType.auth => '请重新登录',
      AppErrorType.database => '请稍后重试',
      AppErrorType.validation => '请检查输入数据',
      AppErrorType.timeout => '请重试',
      AppErrorType.server => '请稍后重试',
      AppErrorType.conflict => '请手动解决冲突',
      AppErrorType.unknown => '请重试或联系支持',
    };
  }
}
