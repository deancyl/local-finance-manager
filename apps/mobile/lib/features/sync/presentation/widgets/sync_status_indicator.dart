import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync/sync.dart';

import '../../data/sync_providers.dart';
import '../../data/websocket_provider.dart';
import '../../data/offline_queue_service.dart';

/// Sync status indicator for AppBar.
/// 
/// Shows sync status icon with WebSocket connection status.
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final progress = ref.watch(syncProgressProvider);
    final websocketConnected = ref.watch(websocketConnectedProvider);
    final websocketAvailable = ref.watch(isWebsocketAvailableProvider);
    final queueSummary = ref.watch(queueSummaryProvider);
    
    final pendingCount = queueSummary.pendingCount + queueSummary.failedCount;
    
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(
            _getIcon(status, websocketConnected, websocketAvailable),
            color: _getColor(status, websocketConnected),
          ),
          onPressed: () => _showStatusSheet(context, ref),
          tooltip: _getTooltip(status, websocketConnected, websocketAvailable, pendingCount),
        ),
        if (pendingCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: queueSummary.hasFailedItems 
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$pendingCount',
                style: const TextStyle(fontSize: 10, color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
  
  IconData _getIcon(AsyncValue<SyncStatus> status, bool websocketConnected, bool websocketAvailable) {
    // If WebSocket is available and connected, show real-time sync indicator
    if (websocketAvailable && websocketConnected) {
      return Icons.sync;
    }
    
    return status.when(
      data: (s) => switch (s) {
        SyncStatus.connected => Icons.cloud_done_outlined,
        SyncStatus.connecting => Icons.cloud_sync_outlined,
        SyncStatus.disconnected => Icons.cloud_off_outlined,
        SyncStatus.notInitialized => Icons.cloud_off_outlined,
        SyncStatus.error => Icons.error_outline,
      },
      loading: () => Icons.cloud_off_outlined,
      error: (_, __) => Icons.error_outline,
    );
  }
  
  Color _getColor(AsyncValue<SyncStatus> status, bool websocketConnected) {
    if (websocketConnected) {
      return Colors.green;
    }
    
    return status.when(
      data: (s) => switch (s) {
        SyncStatus.connected => Colors.green,
        SyncStatus.connecting => Colors.orange,
        SyncStatus.disconnected => Colors.grey,
        SyncStatus.notInitialized => Colors.grey,
        SyncStatus.error => Colors.red,
      },
      loading: () => Colors.grey,
      error: (_, __) => Colors.red,
    );
  }
  
  String _getTooltip(AsyncValue<SyncStatus> status, bool websocketConnected, bool websocketAvailable, int pendingCount) {
    final baseTooltip = status.when(
      data: (s) => switch (s) {
        SyncStatus.connected => '已连接',
        SyncStatus.connecting => '正在连接...',
        SyncStatus.disconnected => '未连接',
        SyncStatus.notInitialized => '未配置',
        SyncStatus.error => '同步错误',
      },
      loading: () => '未连接',
      error: (_, __) => '同步错误',
    );
    
    final List<String> parts = [baseTooltip];
    
    if (websocketAvailable) {
      parts.add('实时同步: ${websocketConnected ? "已连接" : "未连接"}');
    }
    
    if (pendingCount > 0) {
      parts.add('待同步: $pendingCount 项');
    }
    
    return parts.join('\n');
  }
  
  bool _hasPending(AsyncValue<SyncProgress> progress) {
    return progress.when(
      data: (p) => p.pendingUploads > 0 || p.pendingDownloads > 0,
      loading: () => false,
      error: (_, __) => false,
    );
  }
  
  int _getPendingCount(AsyncValue<SyncProgress> progress) {
    return progress.when(
      data: (p) => p.pendingUploads + p.pendingDownloads,
      loading: () => 0,
      error: (_, __) => 0,
    );
  }
  
  void _showStatusSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const SyncStatusSheet(),
    );
  }
}

/// Sync status bottom sheet.
/// 
/// Shows detailed sync status including WebSocket connection state and offline queue.
class SyncStatusSheet extends ConsumerWidget {
  const SyncStatusSheet({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final progress = ref.watch(syncProgressProvider);
    final websocketConnected = ref.watch(websocketConnectedProvider);
    final websocketAvailable = ref.watch(isWebsocketAvailableProvider);
    final websocketStatus = ref.watch(websocketStatusDisplayProvider);
    final queueSummary = ref.watch(queueSummaryProvider);
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '同步状态',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          status.when(
            data: (s) => _buildStatusInfo(context, ref, s, progress, websocketAvailable, websocketConnected, websocketStatus, queueSummary),
            loading: () => const Text('加载中...'),
            error: (e, __) => Text('错误: $e'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
              ),
              if (queueSummary.hasPendingItems || queueSummary.hasFailedItems) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Navigate to offline queue page
                    },
                    child: Text('查看队列 (${queueSummary.totalCount})'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusInfo(
    BuildContext context, 
    WidgetRef ref,
    SyncStatus status, 
    AsyncValue<SyncProgress> progress,
    bool websocketAvailable,
    bool websocketConnected,
    String websocketStatus,
    OfflineQueueSummary queueSummary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _getStatusIcon(status, websocketConnected),
              color: _getStatusColor(status, websocketConnected),
            ),
            const SizedBox(width: 8),
            Text(
              status.displayName,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
        if (websocketAvailable) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                websocketConnected ? Icons.sync : Icons.sync_disabled,
                color: websocketConnected ? Colors.green : Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                '实时同步: $websocketStatus',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],
        // Offline queue status
        if (queueSummary.totalCount > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: queueSummary.hasFailedItems 
                  ? Theme.of(context).colorScheme.errorContainer.withOpacity(0.3)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  queueSummary.hasFailedItems ? Icons.error_outline : Icons.pending_actions,
                  size: 16,
                  color: queueSummary.hasFailedItems 
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '离线队列: ${queueSummary.pendingCount} 待处理, ${queueSummary.failedCount} 失败',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (status == SyncStatus.connected) ...[
          const SizedBox(height: 8),
          progress.when(
            data: (p) => Text(
              '待上传: ${p.pendingUploads} | 待下载: ${p.pendingDownloads}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            loading: () => const Text('加载进度...'),
            error: (_, __) => const Text('无法加载进度'),
          ),
        ],
      ],
    );
  }
  
  IconData _getStatusIcon(SyncStatus status, bool websocketConnected) {
    if (websocketConnected) {
      return Icons.sync;
    }
    
    return switch (status) {
      SyncStatus.connected => Icons.cloud_done_outlined,
      SyncStatus.connecting => Icons.cloud_sync_outlined,
      SyncStatus.disconnected => Icons.cloud_off_outlined,
      SyncStatus.notInitialized => Icons.cloud_off_outlined,
      SyncStatus.error => Icons.error_outline,
    };
  }
  
  Color _getStatusColor(SyncStatus status, bool websocketConnected) {
    if (websocketConnected) {
      return Colors.green;
    }
    
    return switch (status) {
      SyncStatus.connected => Colors.green,
      SyncStatus.connecting => Colors.orange,
      SyncStatus.disconnected => Colors.grey,
      SyncStatus.notInitialized => Colors.grey,
      SyncStatus.error => Colors.red,
    };
  }
}