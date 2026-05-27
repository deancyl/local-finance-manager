import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/offline_queue_service.dart';
import '../../data/offline_queue_model.dart';
import '../../data/sync_feature_flag.dart';

/// Offline queue page showing pending sync operations.
class OfflineQueuePage extends ConsumerWidget {
  const OfflineQueuePage({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncEnabled = ref.watch(syncFeatureFlagProvider);
    final queueItems = ref.watch(offlineQueueNotifierProvider);
    final summary = OfflineQueueSummary.fromItems(queueItems);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('离线队列'),
        actions: [
          if (summary.hasPendingItems)
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: '全部同步',
              onPressed: () => _syncAll(context, ref),
            ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, ref, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_completed',
                child: ListTile(
                  leading: Icon(Icons.cleaning_services),
                  title: Text('清除已完成'),
                ),
              ),
              const PopupMenuItem(
                value: 'clear_failed',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep),
                  title: Text('清除失败项'),
                ),
              ),
              const PopupMenuItem(
                value: 'retry_all',
                enabled: summary.hasFailedItems,
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('重试所有失败项'),
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: ListTile(
                  leading: Icon(Icons.delete_forever, color: Colors.red),
                  title: Text('清空队列', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ],
      ),
      body: isSyncEnabled 
          ? _buildContent(context, ref, queueItems, summary)
          : _buildSyncDisabled(context),
    );
  }
  
  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<OfflineQueueItem> items,
    OfflineQueueSummary summary,
  ) {
    if (items.isEmpty) {
      return _buildEmptyState(context);
    }
    
    return Column(
      children: [
        // Summary card
        _buildSummaryCard(context, summary),
        
        // Items list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) => _buildQueueItemCard(context, ref, items[index]),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSummaryCard(BuildContext context, OfflineQueueSummary summary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSummaryItem(
            context,
            Icons.pending,
            '待处理',
            summary.pendingCount,
            Colors.blue,
          ),
          _buildSummaryItem(
            context,
            Icons.error_outline,
            '失败',
            summary.failedCount,
            summary.hasFailedItems ? Colors.red : Colors.grey,
          ),
          _buildSummaryItem(
            context,
            Icons.check_circle_outline,
            '已完成',
            summary.completedCount,
            Colors.green,
          ),
          _buildSummaryItem(
            context,
            Icons.list,
            '总计',
            summary.totalCount,
            Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryItem(
    BuildContext context,
    IconData icon,
    String label,
    int count,
    Color color,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
  
  Widget _buildQueueItemCard(
    BuildContext context,
    WidgetRef ref,
    OfflineQueueItem item,
  ) {
    final dateFormat = DateFormat('MM-dd HH:mm');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _buildStatusIcon(item),
        title: Text('${item.operationDisplayName} ${item.entityDisplayName}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${item.entityId.substring(0, 8)}...'),
            Text(
              '创建时间: ${dateFormat.format(item.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (item.hasFailed && item.errorMessage != null)
              Text(
                '错误: ${item.errorMessage}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: _buildTrailingActions(context, ref, item),
        isThreeLine: item.hasFailed,
      ),
    );
  }
  
  Widget _buildStatusIcon(OfflineQueueItem item) {
    IconData icon;
    Color color;
    
    switch (item.status) {
      case QueueItemStatus.pending:
        icon = Icons.pending;
        color = Colors.blue;
        break;
      case QueueItemStatus.processing:
        icon = Icons.sync;
        color = Colors.orange;
        break;
      case QueueItemStatus.failed:
        icon = Icons.error_outline;
        color = Colors.red;
        break;
      case QueueItemStatus.completed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color),
    );
  }
  
  Widget _buildTrailingActions(
    BuildContext context,
    WidgetRef ref,
    OfflineQueueItem item,
  ) {
    if (item.status == QueueItemStatus.completed) {
      return IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _removeItem(context, ref, item.id),
        tooltip: '删除',
      );
    }
    
    if (item.canRetry) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _retryItem(context, ref, item.id),
            tooltip: '重试',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _removeItem(context, ref, item.id),
            tooltip: '删除',
          ),
        ],
      );
    }
    
    return IconButton(
      icon: const Icon(Icons.delete_outline),
      onPressed: () => _removeItem(context, ref, item.id),
      tooltip: '删除',
    );
  }
  
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_done,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            '无待同步数据',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '所有数据已同步完成',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSyncDisabled(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sync_disabled,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '同步功能未启用',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '启用同步后，离线操作将自动排队',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  void _syncAll(BuildContext context, WidgetRef ref) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在同步...')),
    );
  }
  
  void _retryItem(BuildContext context, WidgetRef ref, String itemId) {
    ref.read(offlineQueueNotifierProvider.notifier).retryItem(itemId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已重新加入队列')),
    );
  }
  
  void _removeItem(BuildContext context, WidgetRef ref, String itemId) {
    ref.read(offlineQueueNotifierProvider.notifier).removeItem(itemId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已从队列中移除')),
    );
  }
  
  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    final notifier = ref.read(offlineQueueNotifierProvider.notifier);
    
    switch (action) {
      case 'clear_completed':
        notifier.removeCompletedItems();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已清除已完成项')),
        );
        break;
      case 'clear_failed':
        notifier.removeFailedItems();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已清除失败项')),
        );
        break;
      case 'retry_all':
        notifier.retryAllFailed();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('正在重试所有失败项')),
        );
        break;
      case 'clear_all':
        _showClearAllConfirmation(context, notifier);
        break;
    }
  }
  
  void _showClearAllConfirmation(
    BuildContext context,
    OfflineQueueNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空队列'),
        content: const Text('确定要清空所有待同步数据吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              notifier.clearQueue();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('队列已清空')),
              );
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}