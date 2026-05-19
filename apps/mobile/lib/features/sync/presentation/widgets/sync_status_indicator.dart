import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/sync_provider.dart';
import 'package:sync/sync.dart';

/// Sync status indicator for AppBar.
/// 
/// Shows sync status icon with pending operations badge.
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final progress = ref.watch(syncProgressProvider);
    
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(
            _getIcon(status),
            color: _getColor(status),
          ),
          onPressed: () => _showStatusSheet(context, ref),
          tooltip: _getTooltip(status),
        ),
        if (_hasPending(progress))
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '${_getPendingCount(progress)}',
                style: const TextStyle(fontSize: 10, color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
  
  IconData _getIcon(AsyncValue<SyncStatus> status) {
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
  
  Color _getColor(AsyncValue<SyncStatus> status) {
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
  
  String _getTooltip(AsyncValue<SyncStatus> status) {
    return status.when(
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

/// Placeholder for sync status bottom sheet.
/// 
/// TODO: Implement full status sheet with sync details.
class SyncStatusSheet extends ConsumerWidget {
  const SyncStatusSheet({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final progress = ref.watch(syncProgressProvider);
    
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
            data: (s) => _buildStatusInfo(context, s, progress),
            loading: () => const Text('加载中...'),
            error: (e, __) => Text('错误: $e'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusInfo(BuildContext context, SyncStatus status, AsyncValue<SyncProgress> progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _getStatusIcon(status),
              color: _getStatusColor(status),
            ),
            const SizedBox(width: 8),
            Text(
              status.displayName,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
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
  
  IconData _getStatusIcon(SyncStatus status) {
    return switch (status) {
      SyncStatus.connected => Icons.cloud_done_outlined,
      SyncStatus.connecting => Icons.cloud_sync_outlined,
      SyncStatus.disconnected => Icons.cloud_off_outlined,
      SyncStatus.notInitialized => Icons.cloud_off_outlined,
      SyncStatus.error => Icons.error_outline,
    };
  }
  
  Color _getStatusColor(SyncStatus status) {
    return switch (status) {
      SyncStatus.connected => Colors.green,
      SyncStatus.connecting => Colors.orange,
      SyncStatus.disconnected => Colors.grey,
      SyncStatus.notInitialized => Colors.grey,
      SyncStatus.error => Colors.red,
    };
  }
}
