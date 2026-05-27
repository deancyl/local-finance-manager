import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'offline_queue_model.dart';
import 'sync_feature_flag.dart';

final _log = Logger('OfflineQueueService');

/// Storage key for offline queue items.
const _queueStorageKey = 'offline_queue_items';

/// Maximum number of retries for a queue item.
const maxRetries = 3;

/// Service for managing offline sync queue.
/// 
/// Handles:
/// - Adding operations to the queue when offline
/// - Processing queued items when online
/// - Retrying failed operations
/// - Removing completed/failed items
class OfflineQueueService {
  final SharedPreferences _prefs;
  
  OfflineQueueService(this._prefs);
  
  /// Gets all queue items.
  List<OfflineQueueItem> getAllItems() {
    try {
      final itemsStr = _prefs.getString(_queueStorageKey);
      if (itemsStr == null) return [];
      
      final itemsList = jsonDecode(itemsStr) as List;
      return itemsList
          .map((item) => OfflineQueueItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log.warning('Failed to load queue items: $e');
      return [];
    }
  }
  
  /// Gets pending items (waiting to be processed).
  List<OfflineQueueItem> getPendingItems() {
    return getAllItems()
        .where((item) => item.status == QueueItemStatus.pending)
        .toList();
  }
  
  /// Gets failed items (can be retried).
  List<OfflineQueueItem> getFailedItems() {
    return getAllItems()
        .where((item) => item.status == QueueItemStatus.failed && item.canRetry)
        .toList();
  }
  
  /// Gets the queue summary.
  OfflineQueueSummary getSummary() {
    return OfflineQueueSummary.fromItems(getAllItems());
  }
  
  /// Adds a new item to the queue.
  OfflineQueueItem addItem({
    required QueueOperationType operationType,
    required QueueEntityType entityType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) {
    final item = OfflineQueueItem(
      id: const Uuid().v4(),
      operationType: operationType,
      entityType: entityType,
      entityId: entityId,
      payload: payload,
      createdAt: DateTime.now(),
    );
    
    _saveItems([...getAllItems(), item]);
    _log.info('Added queue item: ${item.id} - ${item.operationDisplayName} ${item.entityDisplayName}');
    
    return item;
  }
  
  /// Updates a queue item's status.
  void updateItemStatus(
    String itemId,
    QueueItemStatus status,
    String? errorMessage,
  ) {
    final items = getAllItems();
    final index = items.indexWhere((item) => item.id == itemId);
    
    if (index == -1) {
      _log.warning('Queue item not found: $itemId');
      return;
    }
    
    final updatedItem = items[index].copyWith(
      status: status,
      errorMessage: errorMessage,
      lastAttemptAt: DateTime.now(),
      retryCount: status == QueueItemStatus.failed 
          ? items[index].retryCount + 1 
          : items[index].retryCount,
      completedAt: status == QueueItemStatus.completed 
          ? DateTime.now() 
          : null,
    );
    
    items[index] = updatedItem;
    _saveItems(items);
    
    _log.info('Updated queue item $itemId: status=$status, retries=${updatedItem.retryCount}');
  }
  
  /// Marks an item as processing.
  void markProcessing(String itemId) {
    updateItemStatus(itemId, QueueItemStatus.processing, null);
  }
  
  /// Marks an item as completed.
  void markCompleted(String itemId) {
    updateItemStatus(itemId, QueueItemStatus.completed, null);
  }
  
  /// Marks an item as failed.
  void markFailed(String itemId, String errorMessage) {
    updateItemStatus(itemId, QueueItemStatus.failed, errorMessage);
  }
  
  /// Removes a queue item.
  void removeItem(String itemId) {
    final items = getAllItems();
    final filteredItems = items.where((item) => item.id != itemId).toList();
    
    _saveItems(filteredItems);
    _log.info('Removed queue item: $itemId');
  }
  
  /// Removes all completed items.
  void removeCompletedItems() {
    final items = getAllItems();
    final filteredItems = items
        .where((item) => item.status != QueueItemStatus.completed)
        .toList();
    
    _saveItems(filteredItems);
    _log.info('Removed ${items.length - filteredItems.length} completed items');
  }
  
  /// Removes all failed items that cannot be retried.
  void removeFailedItems() {
    final items = getAllItems();
    final filteredItems = items
        .where((item) => item.status != QueueItemStatus.failed || item.canRetry)
        .toList();
    
    _saveItems(filteredItems);
    _log.info('Removed ${items.length - filteredItems.length} failed items');
  }
  
  /// Clears all items from the queue.
  void clearQueue() {
    _prefs.remove(_queueStorageKey);
    _log.info('Queue cleared');
  }
  
  /// Retries a failed item.
  void retryItem(String itemId) {
    final items = getAllItems();
    final index = items.indexWhere((item) => item.id == itemId);
    
    if (index == -1) {
      _log.warning('Queue item not found for retry: $itemId');
      return;
    }
    
    final item = items[index];
    if (!item.canRetry) {
      _log.warning('Queue item cannot be retried: $itemId (retries: ${item.retryCount})');
      return;
    }
    
    final updatedItem = item.copyWith(
      status: QueueItemStatus.pending,
      errorMessage: null,
    );
    
    items[index] = updatedItem;
    _saveItems(items);
    
    _log.info('Retrying queue item: $itemId');
  }
  
  /// Retries all failed items.
  void retryAllFailed() {
    final items = getAllItems();
    final updatedItems = items.map((item) {
      if (item.status == QueueItemStatus.failed && item.canRetry) {
        return item.copyWith(
          status: QueueItemStatus.pending,
          errorMessage: null,
        );
      }
      return item;
    }).toList();
    
    _saveItems(updatedItems);
    _log.info('Retrying all failed items');
  }
  
  /// Saves items to SharedPreferences.
  void _saveItems(List<OfflineQueueItem> items) {
    final itemsJson = items.map((item) => item.toJson()).toList();
    _prefs.setString(_queueStorageKey, jsonEncode(itemsJson));
  }
}

/// Provider for OfflineQueueService.
final offlineQueueServiceProvider = Provider<OfflineQueueService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return OfflineQueueService(prefs);
});

/// Provider for all queue items.
final allQueueItemsProvider = Provider<List<OfflineQueueItem>>((ref) {
  final service = ref.watch(offlineQueueServiceProvider);
  return service.getAllItems();
});

/// Provider for pending queue items.
final pendingQueueItemsProvider = Provider<List<OfflineQueueItem>>((ref) {
  final service = ref.watch(offlineQueueServiceProvider);
  return service.getPendingItems();
});

/// Provider for failed queue items.
final failedQueueItemsProvider = Provider<List<OfflineQueueItem>>((ref) {
  final service = ref.watch(offlineQueueServiceProvider);
  return service.getFailedItems();
});

/// Provider for queue summary.
final queueSummaryProvider = Provider<OfflineQueueSummary>((ref) {
  final service = ref.watch(offlineQueueServiceProvider);
  return service.getSummary();
});

/// Notifier for managing queue operations.
class OfflineQueueNotifier extends StateNotifier<List<OfflineQueueItem>> {
  final OfflineQueueService _service;
  final Ref _ref;
  
  OfflineQueueNotifier(this._service, this._ref) : super(_service.getAllItems());
  
  /// Refreshes the queue state.
  void refresh() {
    state = _service.getAllItems();
  }
  
  /// Adds a new item to the queue.
  OfflineQueueItem addItem({
    required QueueOperationType operationType,
    required QueueEntityType entityType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) {
    final item = _service.addItem(
      operationType: operationType,
      entityType: entityType,
      entityId: entityId,
      payload: payload,
    );
    
    refresh();
    return item;
  }
  
  /// Removes an item from the queue.
  void removeItem(String itemId) {
    _service.removeItem(itemId);
    refresh();
  }
  
  /// Retries a failed item.
  void retryItem(String itemId) {
    _service.retryItem(itemId);
    refresh();
  }
  
  /// Retries all failed items.
  void retryAllFailed() {
    _service.retryAllFailed();
    refresh();
  }
  
  /// Removes all completed items.
  void removeCompletedItems() {
    _service.removeCompletedItems();
    refresh();
  }
  
  /// Removes all failed items.
  void removeFailedItems() {
    _service.removeFailedItems();
    refresh();
  }
  
  /// Clears the entire queue.
  void clearQueue() {
    _service.clearQueue();
    refresh();
  }
}

final offlineQueueNotifierProvider = 
    StateNotifierProvider<OfflineQueueNotifier, List<OfflineQueueItem>>((ref) {
  final service = ref.watch(offlineQueueServiceProvider);
  return OfflineQueueNotifier(service, ref);
});