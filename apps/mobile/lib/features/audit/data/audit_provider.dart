import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart' as uuid_pkg;

import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

// ============================================================
// AUDIT SERVICE
// ============================================================

/// Operation types for audit logging
enum AuditOperation {
  create,
  update,
  delete;

  String get value {
    switch (this) {
      case AuditOperation.create: return 'CREATE';
      case AuditOperation.update: return 'UPDATE';
      case AuditOperation.delete: return 'DELETE';
    }
  }
}

/// Service for recording and querying audit logs
class AuditService {
  final LocalFinanceDatabase _db;
  final uuid_pkg.Uuid _uuid = const uuid_pkg.Uuid();
  
  /// Current session ID for grouping related changes
  String? _currentSessionId;
  
  /// Current user/device ID
  String? _currentUserId;

  AuditService(this._db);

  /// Set the current session ID
  void setSessionId(String? sessionId) {
    _currentSessionId = sessionId;
  }

  /// Set the current user/device ID
  void setUserId(String? userId) {
    _currentUserId = userId;
  }

  /// Start a new session
  String startSession() {
    _currentSessionId = _uuid.v4();
    return _currentSessionId!;
  }

  /// End the current session
  void endSession() {
    _currentSessionId = null;
  }

  /// Log an account change
  Future<void> logAccountChange({
    required AuditOperation operation,
    required String entityId,
    Account? before,
    Account? after,
    List<String>? changedFields,
    String? description,
  }) async {
    await _log(
      entityType: 'account',
      operation: operation,
      entityId: entityId,
      beforeData: before != null ? _accountToJson(before) : null,
      afterData: after != null ? _accountToJson(after) : null,
      changedFields: changedFields,
      description: description,
    );
  }

  /// Log a transaction change
  Future<void> logTransactionChange({
    required AuditOperation operation,
    required String entityId,
    Transaction? before,
    Transaction? after,
    List<String>? changedFields,
    String? description,
  }) async {
    await _log(
      entityType: 'transaction',
      operation: operation,
      entityId: entityId,
      beforeData: before != null ? _transactionToJson(before) : null,
      afterData: after != null ? _transactionToJson(after) : null,
      changedFields: changedFields,
      description: description,
    );
  }

  /// Log a split change
  Future<void> logSplitChange({
    required AuditOperation operation,
    required String entityId,
    Split? before,
    Split? after,
    List<String>? changedFields,
    String? description,
  }) async {
    await _log(
      entityType: 'split',
      operation: operation,
      entityId: entityId,
      beforeData: before != null ? _splitToJson(before) : null,
      afterData: after != null ? _splitToJson(after) : null,
      changedFields: changedFields,
      description: description,
    );
  }

  /// Log a category change
  Future<void> logCategoryChange({
    required AuditOperation operation,
    required String entityId,
    Category? before,
    Category? after,
    List<String>? changedFields,
    String? description,
  }) async {
    await _log(
      entityType: 'category',
      operation: operation,
      entityId: entityId,
      beforeData: before != null ? _categoryToJson(before) : null,
      afterData: after != null ? _categoryToJson(after) : null,
      changedFields: changedFields,
      description: description,
    );
  }

  /// Log a budget change
  Future<void> logBudgetChange({
    required AuditOperation operation,
    required String entityId,
    Budget? before,
    Budget? after,
    List<String>? changedFields,
    String? description,
  }) async {
    await _log(
      entityType: 'budget',
      operation: operation,
      entityId: entityId,
      beforeData: before != null ? _budgetToJson(before) : null,
      afterData: after != null ? _budgetToJson(after) : null,
      changedFields: changedFields,
      description: description,
    );
  }

  /// Core logging method
  Future<void> _log({
    required String entityType,
    required AuditOperation operation,
    required String entityId,
    String? beforeData,
    String? afterData,
    List<String>? changedFields,
    String? description,
  }) async {
    final log = AuditLogsCompanion.insert(
      id: _uuid.v4(),
      entityType: entityType,
      entityId: entityId,
      operation: operation.value,
      beforeData: drift.Value(beforeData),
      afterData: drift.Value(afterData),
      changedFields: drift.Value(
        changedFields != null ? jsonEncode(changedFields) : null,
      ),
      changedBy: drift.Value(_currentUserId),
      changedAt: DateTime.now(),
      description: drift.Value(description),
      sessionId: drift.Value(_currentSessionId),
    );

    await _db.auditLogsDao.insertLog(log);
  }

  /// Get audit logs for display
  Future<List<AuditLogEntry>> getRecentLogs({int limit = 100}) async {
    final logs = await _db.auditLogsDao.getRecent(limit: limit);
    return logs.map(_toEntry).toList();
  }

  /// Get audit logs for a specific entity
  Future<List<AuditLogEntry>> getEntityHistory(
    String entityType,
    String entityId,
  ) async {
    final logs = await _db.auditLogsDao.getByEntity(entityType, entityId);
    return logs.map(_toEntry).toList();
  }

  /// Get audit logs within a date range
  Future<List<AuditLogEntry>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final logs = await _db.auditLogsDao.getByDateRange(start, end);
    return logs.map(_toEntry).toList();
  }

  /// Search audit logs
  Future<List<AuditLogEntry>> search(String query) async {
    final logs = await _db.auditLogsDao.search(query);
    return logs.map(_toEntry).toList();
  }

  /// Clean up old audit logs
  Future<int> cleanupOldLogs({int retentionDays = 365}) async {
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    return _db.auditLogsDao.deleteOlderThan(cutoff);
  }

  /// Convert database log to display entry
  AuditLogEntry _toEntry(AuditLog log) {
    return AuditLogEntry(
      id: log.id,
      entityType: log.entityType,
      entityId: log.entityId,
      operation: log.operation,
      changedAt: log.changedAt,
      changedBy: log.changedBy,
      description: log.description,
      sessionId: log.sessionId,
      changedFields: log.changedFields != null
          ? List<String>.from(jsonDecode(log.changedFields!))
          : null,
    );
  }

  // JSON serialization helpers
  String _accountToJson(Account a) => jsonEncode({
    'id': a.id,
    'name': a.name,
    'accountType': a.accountType,
    'commodityId': a.commodityId,
    'parentId': a.parentId,
    'code': a.code,
    'description': a.description,
    'isPlaceholder': a.isPlaceholder,
    'isHidden': a.isHidden,
    'sortOrder': a.sortOrder,
    'version': a.version,
  });

  String _transactionToJson(Transaction t) => jsonEncode({
    'id': t.id,
    'postDate': t.postDate,
    'enterDate': t.enterDate,
    'currencyId': t.currencyId,
    'description': t.description,
    'notes': t.notes,
    'version': t.version,
  });

  String _splitToJson(Split s) => jsonEncode({
    'id': s.id,
    'transactionId': s.transactionId,
    'accountId': s.accountId,
    'categoryId': s.categoryId,
    'costCenterId': s.costCenterId,
    'valueNum': s.valueNum,
    'valueDenom': s.valueDenom,
    'quantityNum': s.quantityNum,
    'quantityDenom': s.quantityDenom,
    'memo': s.memo,
    'reconcileState': s.reconcileState,
  });

  String _categoryToJson(Category c) => jsonEncode({
    'id': c.id,
    'name': c.name,
    'parentId': c.parentId,
    'isIncome': c.isIncome,
    'icon': c.icon,
    'color': c.color,
    'sortOrder': c.sortOrder,
  });

  String _budgetToJson(Budget b) => jsonEncode({
    'id': b.id,
    'name': b.name,
    'categoryId': b.categoryId,
    'period': b.period,
    'amountNum': b.amountNum,
    'amountDenom': b.amountDenom,
    'startDate': b.startDate,
    'endDate': b.endDate,
    'isActive': b.isActive,
  });
}

/// Display model for audit log entries
class AuditLogEntry {
  final String id;
  final String entityType;
  final String entityId;
  final String operation;
  final DateTime changedAt;
  final String? changedBy;
  final String? description;
  final String? sessionId;
  final List<String>? changedFields;

  const AuditLogEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.changedAt,
    this.changedBy,
    this.description,
    this.sessionId,
    this.changedFields,
  });

  String get operationLabel {
    switch (operation) {
      case 'CREATE': return '创建';
      case 'UPDATE': return '更新';
      case 'DELETE': return '删除';
      default: return operation;
    }
  }

  String get entityTypeLabel {
    switch (entityType) {
      case 'account': return '账户';
      case 'transaction': return '交易';
      case 'split': return '分录';
      case 'category': return '分类';
      case 'budget': return '预算';
      default: return entityType;
    }
  }

  String get summary {
    return '$operationLabel$entityTypeLabel';
  }
}

// ============================================================
// PROVIDERS
// ============================================================

/// Provider for audit service
final auditServiceProvider = Provider<AuditService>((ref) {
  final db = ref.watch(databaseProvider);
  return AuditService(db);
});

/// Provider for recent audit logs
final recentAuditLogsProvider = FutureProvider.family<List<AuditLogEntry>, int>((ref, limit) async {
  final auditService = ref.watch(auditServiceProvider);
  return auditService.getRecentLogs(limit: limit);
});

/// Provider for entity audit history
final entityAuditHistoryProvider = FutureProvider.family<List<AuditLogEntry>, (String, String)>((ref, params) async {
  final auditService = ref.watch(auditServiceProvider);
  return auditService.getEntityHistory(params.$1, params.$2);
});

/// Provider for audit logs in date range
final auditLogsByDateRangeProvider = FutureProvider.family<List<AuditLogEntry>, (DateTime, DateTime)>((ref, params) async {
  final auditService = ref.watch(auditServiceProvider);
  return auditService.getByDateRange(params.$1, params.$2);
});

/// Notifier for audit operations
class AuditNotifier extends StateNotifier<AsyncValue<void>> {
  final AuditService _service;
  final Ref _ref;

  AuditNotifier(this._service, this._ref) : super(const AsyncValue.data(null));

  /// Start a new audit session
  String startSession() {
    return _service.startSession();
  }

  /// End the current audit session
  void endSession() {
    _service.endSession();
  }

  /// Set the current user ID
  void setUserId(String? userId) {
    _service.setUserId(userId);
  }

  /// Clean up old audit logs
  Future<int> cleanupOldLogs({int retentionDays = 365}) async {
    return _service.cleanupOldLogs(retentionDays: retentionDays);
  }

  /// Refresh audit logs
  void refresh() {
    _ref.invalidate(recentAuditLogsProvider);
  }
}

final auditNotifierProvider = StateNotifierProvider<AuditNotifier, AsyncValue<void>>((ref) {
  final service = ref.watch(auditServiceProvider);
  return AuditNotifier(service, ref);
});
