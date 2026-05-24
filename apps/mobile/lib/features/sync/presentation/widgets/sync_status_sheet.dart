// DISABLED: sync package is temporarily disabled due to PowerSync compatibility issues
/*
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/sync_provider.dart';
import 'package:sync/sync.dart';

/// Sync status bottom sheet with detailed info.
class SyncStatusSheet extends ConsumerWidget {
  const SyncStatusSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final progress = ref.watch(syncProgressProvider);
    final syncNotifier = ref.read(syncNotifierProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getIcon(status),
                color: _getColor(status, context),
              ),
              const SizedBox(width: 8),
              Text(
                '同步状态',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Status text
          Text(
            _getStatusText(status),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),

          // Progress info
          progress.when(
            data: (p) => _buildProgressInfo(context, p),
            loading: () => const Text('加载中...'),
            error: (_, __) => const Text('无法获取进度'),
          ),
          const SizedBox(height: 16),

          // Last sync time
          if (progress.hasValue && progress.value!.lastSyncTime != null)
            Text(
              '上次同步: ${_formatTime(progress.value!.lastSyncTime!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 16),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (status.hasValue && status.value != SyncStatus.connected)
                ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_sync),
                  label: const Text('连接'),
                  onPressed: () async {
                    await syncNotifier.connect();
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              if (status.hasValue && status.value == SyncStatus.connected)
                ElevatedButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text('立即同步'),
                  onPressed: () async {
                    await syncNotifier.sync();
                  },
                ),
              if (status.hasValue && status.value == SyncStatus.connected)
                OutlinedButton.icon(
                  icon: const Icon(Icons.cloud_off),
                  label: const Text('断开'),
                  onPressed: () async {
                    await syncNotifier.disconnect();
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressInfo(BuildContext context, SyncProgress progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (progress.pendingUploads > 0)
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('待上传'),
            trailing: Text('${progress.pendingUploads} 条'),
            dense: true,
          ),
        if (progress.pendingDownloads > 0)
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('待下载'),
            trailing: Text('${progress.pendingDownloads} 条'),
            dense: true,
          ),
        if (progress.pendingUploads == 0 && progress.pendingDownloads == 0)
          const Text('无待同步数据'),
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

  Color _getColor(AsyncValue<SyncStatus> status, BuildContext context) {
    return status.when(
      data: (s) => switch (s) {
        SyncStatus.connected => Colors.green,
        SyncStatus.connecting => Colors.orange,
        SyncStatus.disconnected => Theme.of(context).colorScheme.outline,
        SyncStatus.notInitialized => Theme.of(context).colorScheme.outline,
        SyncStatus.error => Theme.of(context).colorScheme.error,
      },
      loading: () => Theme.of(context).colorScheme.outline,
      error: (_, __) => Theme.of(context).colorScheme.error,
    );
  }

  String _getStatusText(AsyncValue<SyncStatus> status) {
    return status.when(
      data: (s) => switch (s) {
        SyncStatus.connected => '已连接到同步服务器',
        SyncStatus.connecting => '正在连接...',
        SyncStatus.disconnected => '未连接到同步服务器',
        SyncStatus.notInitialized => '同步未配置',
        SyncStatus.error => '同步连接出错',
      },
      loading: () => '加载状态...',
      error: (e, __) => '错误: ${e.toString()}',
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }
}
*/
