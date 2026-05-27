import 'dart:convert';

/// Operation type for offline queue items.
enum QueueOperationType {
  create,
  update,
  delete,
}

/// Status of an offline queue item.
enum QueueItemStatus {
  pending,
  processing,
  failed,
  completed,
}

/// Entity type for offline queue items.
enum QueueEntityType {
  transaction,
  account,
  category,
  budget,
  tag,
}

/// Offline queue item representing a pending sync operation.
class OfflineQueueItem {
  final String id;
  final QueueOperationType operationType;
  final QueueEntityType entityType;
  final String entityId;
  final Map<String, dynamic> payload;
  final QueueItemStatus status;
  final int retryCount;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final DateTime? completedAt;

  const OfflineQueueItem({
    required this.id,
    required this.operationType,
    required this.entityType,
    required this.entityId,
    required this.payload,
    this.status = QueueItemStatus.pending,
    this.retryCount = 0,
    this.errorMessage,
    required this.createdAt,
    this.lastAttemptAt,
    this.completedAt,
  });

  /// Whether the item can be retried.
  bool get canRetry => status == QueueItemStatus.failed && retryCount < 3;

  /// Whether the item is currently being processed.
  bool get isProcessing => status == QueueItemStatus.processing;

  /// Whether the item has failed.
  bool get hasFailed => status == QueueItemStatus.failed;

  /// Display name for the operation type.
  String get operationDisplayName {
    switch (operationType) {
      case QueueOperationType.create:
        return '创建';
      case QueueOperationType.update:
        return '更新';
      case QueueOperationType.delete:
        return '删除';
    }
  }

  /// Display name for the entity type.
  String get entityDisplayName {
    switch (entityType) {
      case QueueEntityType.transaction:
        return '交易';
      case QueueEntityType.account:
        return '账户';
      case QueueEntityType.category:
        return '分类';
      case QueueEntityType.budget:
        return '预算';
      case QueueEntityType.tag:
        return '标签';
    }
  }

  /// Status display name.
  String get statusDisplayName {
    switch (status) {
      case QueueItemStatus.pending:
        return '待处理';
      case QueueItemStatus.processing:
        return '处理中';
      case QueueItemStatus.failed:
        return '失败';
      case QueueItemStatus.completed:
        return '已完成';
    }
  }

  /// Creates a copy with updated fields.
  OfflineQueueItem copyWith({
    String? id,
    QueueOperationType? operationType,
    QueueEntityType? entityType,
    String? entityId,
    Map<String, dynamic>? payload,
    QueueItemStatus? status,
    int? retryCount,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    DateTime? completedAt,
  }) {
    return OfflineQueueItem(
      id: id ?? this.id,
      operationType: operationType ?? this.operationType,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Serializes to JSON.
  Map<String, dynamic> toJson() => {
    'id': id,
    'operationType': operationType.name,
    'entityType': entityType.name,
    'entityId': entityId,
    'payload': payload,
    'status': status.name,
    'retryCount': retryCount,
    'errorMessage': errorMessage,
    'createdAt': createdAt.toIso8601String(),
    'lastAttemptAt': lastAttemptAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  /// Deserializes from JSON.
  factory OfflineQueueItem.fromJson(Map<String, dynamic> json) {
    return OfflineQueueItem(
      id: json['id'] as String,
      operationType: QueueOperationType.values.byName(json['operationType'] as String),
      entityType: QueueEntityType.values.byName(json['entityType'] as String),
      entityId: json['entityId'] as String,
      payload: json['payload'] as Map<String, dynamic>,
      status: QueueItemStatus.values.byName(json['status'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      errorMessage: json['errorMessage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastAttemptAt: json['lastAttemptAt'] != null 
          ? DateTime.parse(json['lastAttemptAt'] as String) 
          : null,
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt'] as String) 
          : null,
    );
  }

  /// Serializes payload to string for storage.
  String payloadToString() => jsonEncode(payload);

  /// Parses payload from string.
  static Map<String, dynamic> parsePayload(String payloadStr) => 
      jsonDecode(payloadStr) as Map<String, dynamic>;
}

/// Summary statistics for the offline queue.
class OfflineQueueSummary {
  final int totalCount;
  final int pendingCount;
  final int processingCount;
  final int failedCount;
  final int completedCount;

  const OfflineQueueSummary({
    required this.totalCount,
    required this.pendingCount,
    required this.processingCount,
    required this.failedCount,
    required this.completedCount,
  });

  /// Whether there are any pending items.
  bool get hasPendingItems => pendingCount > 0;

  /// Whether there are any failed items.
  bool get hasFailedItems => failedCount > 0;

  /// Whether the queue is empty.
  bool get isEmpty => totalCount == 0;

  /// Creates an empty summary.
  static const empty = OfflineQueueSummary(
    totalCount: 0,
    pendingCount: 0,
    processingCount: 0,
    failedCount: 0,
    completedCount: 0,
  );

  /// Creates from a list of items.
  factory OfflineQueueSummary.fromItems(List<OfflineQueueItem> items) {
    int pending = 0, processing = 0, failed = 0, completed = 0;

    for (final item in items) {
      switch (item.status) {
        case QueueItemStatus.pending:
          pending++;
          break;
        case QueueItemStatus.processing:
          processing++;
          break;
        case QueueItemStatus.failed:
          failed++;
          break;
        case QueueItemStatus.completed:
          completed++;
          break;
      }
    }

    return OfflineQueueSummary(
      totalCount: items.length,
      pendingCount: pending,
      processingCount: processing,
      failedCount: failed,
      completedCount: completed,
    );
  }
}