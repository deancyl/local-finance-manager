import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'sync_feature_flag.dart';

final _log = Logger('PendingOperations');

/// Pending sync operation.
class PendingOperation {
  final String id;
  final String tableName;
  final String recordId;
  final String operation; // INSERT, UPDATE, DELETE
  final DateTime createdAt;
  final int retryCount;
  final String? errorMessage;
  final Map<String, dynamic>? data;
  
  const PendingOperation({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.operation,
    required this.createdAt,
    this.retryCount = 0,
    this.errorMessage,
    this.data,
  });
  
  /// Copy with new values.
  PendingOperation copyWith({
    String? id,
    String? tableName,
    String? recordId,
    String? operation,
    DateTime? createdAt,
    int? retryCount,
    String? errorMessage,
    Map<String, dynamic>? data,
  }) {
    return PendingOperation(
      id: id ?? this.id,
      tableName: tableName ?? this.tableName,
      recordId: recordId ?? this.recordId,
      operation: operation ?? this.operation,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      data: data ?? this.data,
    );
  }
  
  String get displayName => switch (operation) {
    'INSERT' => '新增',
    'UPDATE' => '更新',
    'DELETE' => '删除',
    _ => operation,
  };
  
  String get tableDisplayName => switch (tableName) {
    'accounts' => '账户',
    'transactions' => '交易',
    'categories' => '分类',
    'budgets' => '预算',
    'splits' => '分录',
    'tags' => '标签',
    'templates' => '模板',
    _ => tableName,
  };
  
  /// Whether this operation has failed.
  bool get hasFailed => errorMessage != null;
  
  /// Whether this operation should be retried.
  bool get shouldRetry => retryCount < 3;
  
  /// Priority based on creation time.
  int get priority => createdAt.millisecondsSinceEpoch;
}

/// Provider for pending sync operations.
/// 
/// Returns list of operations that are queued for sync
/// but haven't been synced yet.
final pendingOperationsProvider = FutureProvider<List<PendingOperation>>((ref) async {
  final isSyncEnabled = ref.watch(syncFeatureFlagProvider);
  
  if (!isSyncEnabled) {
    return [];
  }
  
  // When sync is properly integrated, this would query the local database
  // for pending changes in the PowerSync upload queue.
  // For now, return empty list as PowerSync is disabled.
  _log.fine('Pending operations requested, returning empty list (PowerSync disabled)');
  return [];
});

/// Provider for pending operations count.
final pendingOperationsCountProvider = Provider<int>((ref) {
  final operations = ref.watch(pendingOperationsProvider);
  return operations.when(
    data: (ops) => ops.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Provider for pending operations grouped by table.
final pendingOperationsByTableProvider = Provider<Map<String, List<PendingOperation>>>((ref) {
  final operations = ref.watch(pendingOperationsProvider);
  return operations.when(
    data: (ops) {
      final grouped = <String, List<PendingOperation>>{};
      for (final op in ops) {
        grouped.putIfAbsent(op.tableName, () => []);
        grouped[op.tableName]!.add(op);
      }
      return grouped;
    },
    loading: () => {},
    error: (_, __) => {},
  );
});

/// Provider for pending operations grouped by operation type.
final pendingOperationsByTypeProvider = Provider<Map<String, List<PendingOperation>>>((ref) {
  final operations = ref.watch(pendingOperationsProvider);
  return operations.when(
    data: (ops) {
      final grouped = <String, List<PendingOperation>>{};
      for (final op in ops) {
        grouped.putIfAbsent(op.operation, () => []);
        grouped[op.operation]!.add(op);
      }
      return grouped;
    },
    loading: () => {},
    error: (_, __) => {},
  );
});

/// Provider for failed operations count.
final failedOperationsCountProvider = Provider<int>((ref) {
  final operations = ref.watch(pendingOperationsProvider);
  return operations.when(
    data: (ops) => ops.where((op) => op.hasFailed).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Notifier for managing pending operations.
class PendingOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  
  PendingOperationsNotifier(this._ref) : super(const AsyncValue.data(null));
  
  /// Retry a specific operation.
  Future<void> retryOperation(String operationId) async {
    state = const AsyncValue.loading();
    
    try {
      _log.info('Retrying operation: $operationId');
      
      // When sync is integrated, this would:
      // 1. Find the operation in the queue
      // 2. Clear any error state
      // 3. Trigger re-upload
      
      // For now, just refresh the list
      _ref.invalidate(pendingOperationsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      _log.warning('Failed to retry operation: $e');
      state = AsyncValue.error(e, st);
    }
  }
  
  /// Retry all pending operations.
  Future<void> retryAll() async {
    state = const AsyncValue.loading();
    
    try {
      _log.info('Retrying all pending operations');
      
      // When sync is integrated, this would trigger a full sync
      _ref.invalidate(pendingOperationsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      _log.warning('Failed to retry all operations: $e');
      state = AsyncValue.error(e, st);
    }
  }
  
  /// Discard a pending operation.
  Future<void> discardOperation(String operationId) async {
    state = const AsyncValue.loading();
    
    try {
      _log.info('Discarding operation: $operationId');
      
      // When sync is integrated, this would:
      // 1. Remove the operation from the queue
      // 2. Handle any cleanup needed
      
      _ref.invalidate(pendingOperationsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      _log.warning('Failed to discard operation: $e');
      state = AsyncValue.error(e, st);
    }
  }
  
  /// Discard all pending operations.
  Future<void> discardAll() async {
    state = const AsyncValue.loading();
    
    try {
      _log.info('Discarding all pending operations');
      
      _ref.invalidate(pendingOperationsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      _log.warning('Failed to discard all operations: $e');
      state = AsyncValue.error(e, st);
    }
  }
  
  /// Clear failed operations.
  Future<void> clearFailed() async {
    state = const AsyncValue.loading();
    
    try {
      _log.info('Clearing failed operations');
      
      _ref.invalidate(pendingOperationsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      _log.warning('Failed to clear failed operations: $e');
      state = AsyncValue.error(e, st);
    }
  }
}

final pendingOperationsNotifierProvider = 
    StateNotifierProvider<PendingOperationsNotifier, AsyncValue<void>>((ref) {
  return PendingOperationsNotifier(ref);
});