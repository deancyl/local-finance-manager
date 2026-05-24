// DISABLED: sync package is temporarily disabled due to PowerSync compatibility issues
// Original content commented out below

/*
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync/sync.dart';
import 'sync_provider.dart';

/// Pending sync operation.
class PendingOperation {
  final String id;
  final String tableName;
  final String recordId;
  final String operation; // INSERT, UPDATE, DELETE
  final DateTime createdAt;
  final int retryCount;
  
  PendingOperation({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.operation,
    required this.createdAt,
    this.retryCount = 0,
  });
  
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
    _ => tableName,
  };
}

/// Provider for pending sync operations.
final pendingOperationsProvider = FutureProvider<List<PendingOperation>>((ref) async {
  final client = ref.watch(syncClientProvider);
  if (client == null) return [];
  
  // Get pending operations from PowerSync CRUD queue
  // This would query the local database for pending changes
  // Placeholder implementation - actual implementation would use PowerSync API
  
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

/// Notifier for managing pending operations.
class PendingOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final SyncClient _client;
  
  PendingOperationsNotifier(this._client) : super(const AsyncValue.data(null));
  
  /// Retry a specific operation.
  Future<void> retryOperation(String operationId) async {
    state = const AsyncValue.loading();
    try {
      // Retry logic would use PowerSync API
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  /// Retry all pending operations.
  Future<void> retryAll() async {
    state = const AsyncValue.loading();
    try {
      await _client.sync();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  /// Discard a pending operation.
  Future<void> discardOperation(String operationId) async {
    state = const AsyncValue.loading();
    try {
      // Discard logic would remove from PowerSync queue
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final pendingOperationsNotifierProvider = StateNotifierProvider<PendingOperationsNotifier, AsyncValue<void>>((ref) {
  final client = ref.watch(syncClientProvider);
  return PendingOperationsNotifier(client!);
});
*/
