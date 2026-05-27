import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'sync_providers.dart';
import 'sync_feature_flag.dart';

final _log = Logger('SyncErrorRecovery');

/// Types of sync errors.
enum SyncErrorType {
  /// Network connectivity issue.
  networkError,
  
  /// Authentication failure.
  authError,
  
  /// Server error (5xx).
  serverError,
  
  /// Client error (4xx).
  clientError,
  
  /// Conflict resolution failure.
  conflictError,
  
  /// Data validation error.
  validationError,
  
  /// Timeout error.
  timeoutError,
  
  /// Unknown error.
  unknownError,
}

/// Sync error with context.
class SyncError {
  final SyncErrorType type;
  final String message;
  final String? code;
  final DateTime timestamp;
  final String? tableName;
  final String? recordId;
  final Map<String, dynamic>? context;
  final int retryCount;
  
  const SyncError({
    required this.type,
    required this.message,
    this.code,
    required this.timestamp,
    this.tableName,
    this.recordId,
    this.context,
    this.retryCount = 0,
  });
  
  /// Whether this error can be retried.
  bool get canRetry => type == SyncErrorType.networkError ||
      type == SyncErrorType.serverError ||
      type == SyncErrorType.timeoutError ||
      (type == SyncErrorType.unknownError && retryCount < 3);
  
  /// Recommended recovery action.
  RecoveryAction get recommendedAction => switch (type) {
    SyncErrorType.networkError => RecoveryAction.retryAfterDelay,
    SyncErrorType.authError => RecoveryAction.reauthenticate,
    SyncErrorType.serverError => RecoveryAction.retryAfterDelay,
    SyncErrorType.clientError => RecoveryAction.reportIssue,
    SyncErrorType.conflictError => RecoveryAction.resolveConflict,
    SyncErrorType.validationError => RecoveryAction.fixData,
    SyncErrorType.timeoutError => RecoveryAction.retryImmediately,
    SyncErrorType.unknownError => RecoveryAction.retryAfterDelay,
  };
  
  /// User-friendly error message.
  String get userMessage => switch (type) {
    SyncErrorType.networkError => '网络连接失败，请检查网络设置',
    SyncErrorType.authError => '认证失败，请重新登录',
    SyncErrorType.serverError => '服务器暂时不可用，稍后重试',
    SyncErrorType.clientError => '请求数据有误，请联系支持',
    SyncErrorType.conflictError => '数据冲突，需要手动解决',
    SyncErrorType.validationError => '数据验证失败，请修正数据',
    SyncErrorType.timeoutError => '请求超时，请重试',
    SyncErrorType.unknownError => '未知错误，请重试',
  };
}

/// Recovery actions for sync errors.
enum RecoveryAction {
  /// Retry immediately.
  retryImmediately,
  
  /// Retry after a delay.
  retryAfterDelay,
  
  /// Re-authenticate.
  reauthenticate,
  
  /// Resolve conflict manually.
  resolveConflict,
  
  /// Fix data locally.
  fixData,
  
  /// Report issue to support.
  reportIssue,
  
  /// No recovery possible.
  noRecovery,
}

/// Provider for recent sync errors.
final syncErrorsProvider = StateProvider<List<SyncError>>((ref) => []);

/// Provider for error count.
final syncErrorCountProvider = Provider<int>((ref) {
  return ref.watch(syncErrorsProvider).length;
});

/// Provider for unresolved errors (can be retried).
final unresolvedErrorsProvider = Provider<List<SyncError>>((ref) {
  return ref.watch(syncErrorsProvider).where((e) => e.canRetry).toList();
});

/// Notifier for managing sync error recovery.
class SyncErrorRecoveryNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  
  SyncErrorRecoveryNotifier(this._ref) : super(const AsyncValue.data(null));
  
  /// Records a sync error.
  void recordError(SyncError error) {
    final errors = _ref.read(syncErrorsProvider);
    _ref.read(syncErrorsProvider.notifier).state = [...errors, error];
    
    _log.warning('Sync error recorded: ${error.type} - ${error.message}');
  }
  
  /// Clears an error.
  void clearError(int index) {
    final errors = _ref.read(syncErrorsProvider);
    if (index >= 0 && index < errors.length) {
      final newErrors = List<SyncError>.from(errors);
      newErrors.removeAt(index);
      _ref.read(syncErrorsProvider.notifier).state = newErrors;
    }
  }
  
  /// Clears all errors.
  void clearAllErrors() {
    _ref.read(syncErrorsProvider.notifier).state = [];
    _log.info('All sync errors cleared');
  }
  
  /// Retries an error.
  Future<bool> retryError(int index) async {
    final errors = _ref.read(syncErrorsProvider);
    if (index >= 0 && index < errors.length) {
      final error = errors[index];
      
      if (!error.canRetry) {
        _log.warning('Error cannot be retried: ${error.type}');
        return false;
      }
      
      state = const AsyncValue.loading();
      
      try {
        // In a real implementation, this would retry the sync operation
        // based on the error context
        
        await Future.delayed(const Duration(seconds: 2)); // Simulate retry
        
        // Update retry count
        final newErrors = List<SyncError>.from(errors);
        newErrors[index] = SyncError(
          type: error.type,
          message: error.message,
          code: error.code,
          timestamp: error.timestamp,
          tableName: error.tableName,
          recordId: error.recordId,
          context: error.context,
          retryCount: error.retryCount + 1,
        );
        
        _ref.read(syncErrorsProvider.notifier).state = newErrors;
        state = const AsyncValue.data(null);
        
        _log.info('Error retry attempted: ${error.type}');
        return true;
      } catch (e, st) {
        state = AsyncValue.error(e, st);
        return false;
      }
    }
    
    return false;
  }
  
  /// Retries all unresolved errors.
  Future<int> retryAllUnresolved() async {
    final errors = _ref.read(unresolvedErrorsProvider);
    int successCount = 0;
    
    for (final error in errors) {
      if (await retryError(_ref.read(syncErrorsProvider).indexOf(error))) {
        successCount++;
      }
    }
    
    return successCount;
  }
  
  /// Gets recommended action for an error.
  RecoveryAction getRecommendedAction(SyncError error) {
    return error.recommendedAction;
  }
}

final syncErrorRecoveryNotifierProvider = 
    StateNotifierProvider<SyncErrorRecoveryNotifier, AsyncValue<void>>((ref) {
  return SyncErrorRecoveryNotifier(ref);
});