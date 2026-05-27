import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../data/sync_providers.dart';
import '../../data/sync_feature_flag.dart';
import '../../data/websocket_provider.dart';
import '../../data/offline_queue_service.dart';
import '../../data/offline_queue_model.dart';
import '../../data/sync_error_recovery.dart';

final _log = Logger('SyncDiagnostics');

/// Sync diagnostics page for troubleshooting sync issues.
class SyncDiagnosticsPage extends ConsumerWidget {
  const SyncDiagnosticsPage({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncEnabled = ref.watch(syncFeatureFlagProvider);
    final syncState = ref.watch(syncStateProvider);
    final websocketAvailable = ref.watch(isWebsocketAvailableProvider);
    final websocketConnected = ref.watch(websocketConnectedProvider);
    final queueSummary = ref.watch(queueSummaryProvider);
    final errorCount = ref.watch(syncErrorCountProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('同步诊断'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _runDiagnostics(context, ref),
            tooltip: '运行诊断',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Overall status
          _buildOverallStatusCard(
            context,
            isSyncEnabled,
            syncState,
            websocketConnected,
            queueSummary,
            errorCount,
          ),
          
          const SizedBox(height: 16),
          
          // Component checks
          _buildSectionHeader(context, '组件检查'),
          Card(
            child: Column(
              children: [
                _buildCheckItem(
                  context,
                  '同步功能',
                  isSyncEnabled ? '已启用' : '已禁用',
                  isSyncEnabled,
                ),
                const Divider(height: 1),
                _buildCheckItem(
                  context,
                  '服务器连接',
                  syncState == SyncState.connected ? '已连接' : '未连接',
                  syncState == SyncState.connected,
                ),
                const Divider(height: 1),
                _buildCheckItem(
                  context,
                  'WebSocket',
                  websocketConnected ? '已连接' : (websocketAvailable ? '可用' : '未配置'),
                  websocketConnected,
                ),
                const Divider(height: 1),
                _buildCheckItem(
                  context,
                  '离线队列',
                  '${queueSummary.totalCount} 项目',
                  queueSummary.totalCount == 0,
                ),
                const Divider(height: 1),
                _buildCheckItem(
                  context,
                  '错误状态',
                  errorCount == 0 ? '无错误' : '$errorCount 个错误',
                  errorCount == 0,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Quick actions
          _buildSectionHeader(context, '快速操作'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('立即同步'),
                  subtitle: const Text('触发一次完整同步'),
                  onTap: () => _triggerSync(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cleaning_services),
                  title: const Text('清除离线队列'),
                  subtitle: const Text('移除所有待同步项目'),
                  onTap: () => _clearQueue(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: const Text('清除错误'),
                  subtitle: const Text('清除所有同步错误'),
                  onTap: () => _clearErrors(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.replay),
                  title: const Text('重置同步'),
                  subtitle: const Text('断开并重新连接同步服务'),
                  onTap: () => _resetSync(context, ref),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Logs
          _buildSectionHeader(context, '日志'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.article_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '同步日志',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '最近的同步活动将显示在这里。此功能需要进一步实现以显示实际日志。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildOverallStatusCard(
    BuildContext context,
    bool isSyncEnabled,
    SyncState syncState,
    bool websocketConnected,
    OfflineQueueSummary queueSummary,
    int errorCount,
  ) {
    final isHealthy = isSyncEnabled &&
        syncState == SyncState.connected &&
        websocketConnected &&
        queueSummary.totalCount == 0 &&
        errorCount == 0;
    
    return Card(
      color: isHealthy
          ? Colors.green.withOpacity(0.1)
          : Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isHealthy ? Icons.check_circle : Icons.warning,
              color: isHealthy ? Colors.green : Theme.of(context).colorScheme.error,
              size: 40,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isHealthy ? '同步状态良好' : '存在问题需要处理',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isHealthy
                        ? '所有组件运行正常'
                        : '请检查下方的问题项',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  
  Widget _buildCheckItem(
    BuildContext context,
    String title,
    String status,
    bool isOk,
  ) {
    return ListTile(
      leading: Icon(
        isOk ? Icons.check_circle : Icons.error_outline,
        color: isOk ? Colors.green : Colors.red,
      ),
      title: Text(title),
      trailing: Text(
        status,
        style: TextStyle(
          color: isOk ? Colors.green : Colors.red,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  void _runDiagnostics(BuildContext context, WidgetRef ref) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在运行诊断...')),
    );
    
    // Refresh all providers
    ref.invalidate(syncStatusProvider);
    ref.invalidate(queueSummaryProvider);
    ref.invalidate(syncErrorsProvider);
    
    Future.delayed(const Duration(seconds: 1), () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('诊断完成'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }
  
  void _triggerSync(BuildContext context, WidgetRef ref) {
    ref.read(syncNotifierProvider.notifier).sync();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('同步已触发')),
    );
  }
  
  void _clearQueue(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除离线队列'),
        content: const Text('确定要清除所有待同步项目吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(offlineQueueNotifierProvider.notifier).clearQueue();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('离线队列已清除')),
              );
            },
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }
  
  void _clearErrors(BuildContext context, WidgetRef ref) {
    ref.read(syncErrorRecoveryNotifierProvider.notifier).clearAllErrors();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('错误已清除')),
    );
  }
  
  void _resetSync(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置同步'),
        content: const Text('将断开并重新连接同步服务。此操作可能需要重新登录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Disconnect
              await ref.read(syncNotifierProvider.notifier).disconnect();
              
              // Wait a moment
              await Future.delayed(const Duration(seconds: 1));
              
              // Reconnect
              await ref.read(syncNotifierProvider.notifier).connect();
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('同步已重置')),
                );
              }
            },
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }
}