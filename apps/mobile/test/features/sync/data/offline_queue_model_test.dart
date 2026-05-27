import 'package:flutter_test/flutter_test.dart';
import 'package:finance_app/features/sync/data/offline_queue_model.dart';

void main() {
  group('OfflineQueueItem', () {
    test('creates item with all required fields', () {
      final item = OfflineQueueItem(
        id: 'item-123',
        operationType: QueueOperationType.create,
        entityType: QueueEntityType.transaction,
        entityId: 'tx-456',
        payload: {'amount': 100.0, 'category': 'food'},
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );
      
      expect(item.id, equals('item-123'));
      expect(item.operationType, equals(QueueOperationType.create));
      expect(item.entityType, equals(QueueEntityType.transaction));
      expect(item.status, equals(QueueItemStatus.pending));
      expect(item.retryCount, equals(0));
    });

    test('serializes to JSON correctly', () {
      final item = OfflineQueueItem(
        id: 'item-456',
        operationType: QueueOperationType.update,
        entityType: QueueEntityType.account,
        entityId: 'acc-789',
        payload: {'name': 'New Account'},
        status: QueueItemStatus.failed,
        retryCount: 2,
        errorMessage: 'Network error',
        createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
        lastAttemptAt: DateTime.parse('2024-01-01T12:30:00Z'),
      );
      
      final json = item.toJson();
      
      expect(json['id'], equals('item-456'));
      expect(json['operationType'], equals('update'));
      expect(json['entityType'], equals('account'));
      expect(json['status'], equals('failed'));
      expect(json['retryCount'], equals(2));
      expect(json['errorMessage'], equals('Network error'));
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'id': 'item-789',
        'operationType': 'delete',
        'entityType': 'category',
        'entityId': 'cat-123',
        'payload': {'id': 'cat-123'},
        'status': 'completed',
        'retryCount': 1,
        'errorMessage': null,
        'createdAt': '2024-01-01T08:00:00Z',
        'lastAttemptAt': null,
        'completedAt': '2024-01-01T08:30:00Z',
      };
      
      final item = OfflineQueueItem.fromJson(json);
      
      expect(item.id, equals('item-789'));
      expect(item.operationType, equals(QueueOperationType.delete));
      expect(item.entityType, equals(QueueEntityType.category));
      expect(item.status, equals(QueueItemStatus.completed));
      expect(item.completedAt, isNotNull);
    });

    test('canRetry returns correct value based on status and retryCount', () {
      // Pending item can't retry (not failed)
      final pendingItem = OfflineQueueItem(
        id: 'pending',
        operationType: QueueOperationType.create,
        entityType: QueueEntityType.transaction,
        entityId: 'tx-1',
        payload: {},
        status: QueueItemStatus.pending,
        createdAt: DateTime.now(),
      );
      expect(pendingItem.canRetry, isFalse);
      
      // Failed item with 0 retries can retry
      final failedItem0 = OfflineQueueItem(
        id: 'failed0',
        operationType: QueueOperationType.create,
        entityType: QueueEntityType.transaction,
        entityId: 'tx-2',
        payload: {},
        status: QueueItemStatus.failed,
        retryCount: 0,
        createdAt: DateTime.now(),
      );
      expect(failedItem0.canRetry, isTrue);
      
      // Failed item with 2 retries can retry
      final failedItem2 = OfflineQueueItem(
        id: 'failed2',
        operationType: QueueOperationType.create,
        entityType: QueueEntityType.transaction,
        entityId: 'tx-3',
        payload: {},
        status: QueueItemStatus.failed,
        retryCount: 2,
        createdAt: DateTime.now(),
      );
      expect(failedItem2.canRetry, isTrue);
      
      // Failed item with 3 retries cannot retry
      final failedItem3 = OfflineQueueItem(
        id: 'failed3',
        operationType: QueueOperationType.create,
        entityType: QueueEntityType.transaction,
        entityId: 'tx-4',
        payload: {},
        status: QueueItemStatus.failed,
        retryCount: 3,
        createdAt: DateTime.now(),
      );
      expect(failedItem3.canRetry, isFalse);
    });

    test('copyWith updates specified fields only', () {
      final original = OfflineQueueItem(
        id: 'original',
        operationType: QueueOperationType.create,
        entityType: QueueEntityType.transaction,
        entityId: 'tx-1',
        payload: {'amount': 100},
        status: QueueItemStatus.pending,
        createdAt: DateTime.now(),
      );
      
      final updated = original.copyWith(
        status: QueueItemStatus.processing,
        lastAttemptAt: DateTime.now(),
      );
      
      expect(updated.id, equals('original'));
      expect(updated.operationType, equals(QueueOperationType.create));
      expect(updated.status, equals(QueueItemStatus.processing));
      expect(updated.lastAttemptAt, isNotNull);
      expect(updated.payload, equals({'amount': 100}));
    });

    test('display names are correct', () {
      final createItem = OfflineQueueItem(
        id: 'create',
        operationType: QueueOperationType.create,
        entityType: QueueEntityType.transaction,
        entityId: 'tx-1',
        payload: {},
        createdAt: DateTime.now(),
      );
      
      expect(createItem.operationDisplayName, equals('创建'));
      expect(createItem.entityDisplayName, equals('交易'));
      expect(createItem.statusDisplayName, equals('待处理'));
    });
  });

  group('OfflineQueueSummary', () {
    test('creates from items correctly', () {
      final items = [
        OfflineQueueItem(
          id: 'pending1',
          operationType: QueueOperationType.create,
          entityType: QueueEntityType.transaction,
          entityId: 'tx-1',
          payload: {},
          status: QueueItemStatus.pending,
          createdAt: DateTime.now(),
        ),
        OfflineQueueItem(
          id: 'pending2',
          operationType: QueueOperationType.update,
          entityType: QueueEntityType.account,
          entityId: 'acc-1',
          payload: {},
          status: QueueItemStatus.pending,
          createdAt: DateTime.now(),
        ),
        OfflineQueueItem(
          id: 'failed1',
          operationType: QueueOperationType.delete,
          entityType: QueueEntityType.category,
          entityId: 'cat-1',
          payload: {},
          status: QueueItemStatus.failed,
          createdAt: DateTime.now(),
        ),
        OfflineQueueItem(
          id: 'completed1',
          operationType: QueueOperationType.create,
          entityType: QueueEntityType.transaction,
          entityId: 'tx-2',
          payload: {},
          status: QueueItemStatus.completed,
          createdAt: DateTime.now(),
        ),
      ];
      
      final summary = OfflineQueueSummary.fromItems(items);
      
      expect(summary.totalCount, equals(4));
      expect(summary.pendingCount, equals(2));
      expect(summary.failedCount, equals(1));
      expect(summary.completedCount, equals(1));
    });

    test('empty summary has zero counts', () {
      expect(OfflineQueueSummary.empty.totalCount, equals(0));
      expect(OfflineQueueSummary.empty.pendingCount, equals(0));
      expect(OfflineQueueSummary.empty.failedCount, equals(0));
      expect(OfflineQueueSummary.empty.isEmpty, isTrue);
    });

    test('helper methods work correctly', () {
      final pendingSummary = OfflineQueueSummary(
        totalCount: 5,
        pendingCount: 3,
        processingCount: 0,
        failedCount: 2,
        completedCount: 0,
      );
      
      expect(pendingSummary.hasPendingItems, isTrue);
      expect(pendingSummary.hasFailedItems, isTrue);
      expect(pendingSummary.isEmpty, isFalse);
      
      final emptySummary = OfflineQueueSummary.empty;
      expect(emptySummary.hasPendingItems, isFalse);
      expect(emptySummary.hasFailedItems, isFalse);
    });
  });

  group('QueueOperationType', () {
    test('contains all expected types', () {
      expect(QueueOperationType.values, contains(QueueOperationType.create));
      expect(QueueOperationType.values, contains(QueueOperationType.update));
      expect(QueueOperationType.values, contains(QueueOperationType.delete));
    });
  });

  group('QueueItemStatus', () {
    test('contains all expected statuses', () {
      expect(QueueItemStatus.values, contains(QueueItemStatus.pending));
      expect(QueueItemStatus.values, contains(QueueItemStatus.processing));
      expect(QueueItemStatus.values, contains(QueueItemStatus.failed));
      expect(QueueItemStatus.values, contains(QueueItemStatus.completed));
    });
  });

  group('QueueEntityType', () {
    test('contains all expected entity types', () {
      expect(QueueEntityType.values, contains(QueueEntityType.transaction));
      expect(QueueEntityType.values, contains(QueueEntityType.account));
      expect(QueueEntityType.values, contains(QueueEntityType.category));
      expect(QueueEntityType.values, contains(QueueEntityType.budget));
      expect(QueueEntityType.values, contains(QueueEntityType.tag));
    });
  });
}