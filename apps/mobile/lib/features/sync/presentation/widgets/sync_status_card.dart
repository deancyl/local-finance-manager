import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sync/sync.dart';
import '../../data/websocket_provider.dart';
import '../../data/offline_queue_service.dart';
import '../../data/offline_queue_model.dart';

/// Card widget displaying sync status and progress.
/// 
/// Shows current connection status, last sync time,
/// pending upload/download counts, and WebSocket status.
class SyncStatusCard extends ConsumerWidget {
  /// Current sync status.
  final AsyncValue<SyncStatus> status;
  
  /// Sync progress information.
  final AsyncValue<SyncProgress> progress;

  const SyncStatusCard({
    super.key,
    required this.status,
    required this.progress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final websocketConnected = ref.watch(websocketConnectedProvider);
    final websocketAvailable = ref.watch(isWebsocketAvailableProvider);
    final queueSummary = ref.watch(queueSummaryProvider);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '同步状态',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            status.when(
              data: (syncStatus) => _buildStatusContent(
                context, 
                syncStatus, 
                websocketAvailable,
                websocketConnected,
                queueSummary,
              ),
              loading: () => _buildLoadingContent(context),
              error: (error, _) => _buildErrorContent(context, error),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusContent(
    BuildContext context, 
    SyncStatus syncStatus,
    bool websocketAvailable,
    bool websocketConnected,
    OfflineQueueSummary queueSummary,
  ) {
    final progressData = progress.when(
      data: (p) => p,
      loading: () => null,
      error: (_, __) => null,
    );

    return Column(
      children: [
        // Status indicator
        _buildStatusIndicator(context, syncStatus),
        
        const SizedBox(height: 12),
        
        // WebSocket status
        if (websocketAvailable)
          _buildWebSocketStatus(context, websocketConnected),
        
        // Queue status
        if (queueSummary.totalCount > 0)
          _buildQueueStatus(context, queueSummary),
        
        const SizedBox(height: 16),
        
        // Progress details
        if (progressData != null) _buildProgressDetails(context, progressData),
      ],
    );
  }
  
  Widget _buildWebSocketStatus(BuildContext context, bool connected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (connected ? Colors.green : Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            connected ? Icons.sync : Icons.sync_disabled,
            size: 16,
            color: connected ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            connected ? '实时同步已连接' : '实时同步未连接',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: connected ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQueueStatus(BuildContext context, OfflineQueueSummary summary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: (summary.hasFailedItems ? Colors.red : Colors.blue).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            summary.hasFailedItems ? Icons.error_outline : Icons.pending_actions,
            size: 16,
            color: summary.hasFailedItems ? Colors.red : Colors.blue,
          ),
          const SizedBox(width: 8),
          Text(
            '离线队列: ${summary.pendingCount} 待处理, ${summary.failedCount} 失败',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: summary.hasFailedItems ? Colors.red : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context, SyncStatus syncStatus) {
    final (icon, color, text) = _getStatusDisplay(context, syncStatus);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (syncStatus == SyncStatus.connecting)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            ),
        ],
      ),
    );
  }

  (IconData, Color, String) _getStatusDisplay(
    BuildContext context,
    SyncStatus syncStatus,
  ) {
    switch (syncStatus) {
      case SyncStatus.notInitialized:
        return (
          Icons.cloud_off,
          Theme.of(context).colorScheme.outline,
          '未初始化',
        );
      case SyncStatus.disconnected:
        return (
          Icons.cloud_off,
          Theme.of(context).colorScheme.outline,
          '未连接',
        );
      case SyncStatus.connecting:
        return (
          Icons.cloud_sync,
          Theme.of(context).colorScheme.tertiary,
          '正在连接...',
        );
      case SyncStatus.connected:
        return (
          Icons.cloud_done,
          Colors.green,
          '已连接',
        );
      case SyncStatus.error:
        return (
          Icons.error_outline,
          Theme.of(context).colorScheme.error,
          '连接错误',
        );
    }
  }

  Widget _buildProgressDetails(BuildContext context, SyncProgress progress) {
    return Column(
      children: [
        // Last sync time
        if (progress.lastSyncTime != null)
          _buildDetailRow(
            context,
            Icons.history,
            '上次同步',
            _formatDateTime(progress.lastSyncTime!),
          ),
        
        const SizedBox(height: 8),
        
        // Pending uploads
        if (progress.pendingUploads > 0)
          _buildDetailRow(
            context,
            Icons.upload,
            '待上传',
            '${progress.pendingUploads} 项',
          ),
        
        // Pending downloads
        if (progress.pendingDownloads > 0) ...[
          const SizedBox(height: 8),
          _buildDetailRow(
            context,
            Icons.download,
            '待下载',
            '${progress.pendingDownloads} 项',
          ),
        ],
        
        // Error message
        if (progress.errorMessage != null) ...[
          const SizedBox(height: 8),
          _buildDetailRow(
            context,
            Icons.error_outline,
            '错误',
            progress.errorMessage!,
            isWarning: true,
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool isWarning = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isWarning
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isWarning
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingContent(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorContent(BuildContext context, Object error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '加载状态失败: $error',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} 分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} 小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} 天前';
    } else {
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    }
  }
}
