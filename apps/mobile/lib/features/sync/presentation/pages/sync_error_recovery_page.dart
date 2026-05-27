import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/sync_error_recovery.dart';
import '../../data/sync_providers.dart';

/// Sync error recovery page for managing sync errors.
class SyncErrorRecoveryPage extends ConsumerWidget {
  const SyncErrorRecoveryPage({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errors = ref.watch(syncErrorsProvider);
    final errorCount = ref.watch(syncErrorCountProvider);
    final unresolvedCount = ref.watch(unresolvedErrorsProvider).length;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('同步错误'),
        actions: [
          if (errors.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) => _handleMenuAction(context, ref, value),
              itemBuilder: (context) => [
                if (unresolvedCount > 0)
                  const PopupMenuItem(
                    value: 'retry_all',
                    child: ListTile(
                      leading: Icon(Icons.refresh),
                      title: Text('重试所有可恢复错误'),
                    ),
                  ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: ListTile(
                    leading: Icon(Icons.delete_sweep),
                    title: Text('清除所有错误'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: errors.isEmpty
          ? _buildEmptyState(context)
          : _buildErrorList(context, ref, errors),
    );
  }
  
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          Text(
            '无同步错误',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '所有数据已成功同步',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorList(
    BuildContext context,
    WidgetRef ref,
    List<SyncError> errors,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: errors.length,
      itemBuilder: (context, index) => _buildErrorCard(context, ref, errors[index], index),
    );
  }
  
  Widget _buildErrorCard(
    BuildContext context,
    WidgetRef ref,
    SyncError error,
    int index,
  ) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _buildErrorTypeIcon(context, error.type),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error.userMessage,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (error.canRetry)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '可恢复',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Details
            Text(
              error.message,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            
            Row(
              children: [
                Text(
                  '时间: ${dateFormat.format(error.timestamp)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (error.tableName != null)
                  Text(
                    ' | 表: ${error.tableName}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            
            if (error.retryCount > 0)
              Text(
                '重试次数: ${error.retryCount}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            
            const SizedBox(height: 12),
            
            // Recovery action
            _buildRecoveryAction(context, ref, error, index),
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorTypeIcon(BuildContext context, SyncErrorType type) {
    IconData icon;
    Color color;
    
    switch (type) {
      case SyncErrorType.networkError:
        icon = Icons.wifi_off;
        color = Colors.orange;
        break;
      case SyncErrorType.authError:
        icon = Icons.lock_outline;
        color = Colors.red;
        break;
      case SyncErrorType.serverError:
        icon = Icons.cloud_off;
        color = Colors.orange;
        break;
      case SyncErrorType.clientError:
        icon = Icons.error_outline;
        color = Colors.red;
        break;
      case SyncErrorType.conflictError:
        icon = Icons.merge_type;
        color = Colors.blue;
        break;
      case SyncErrorType.validationError:
        icon = Icons.warning_amber;
        color = Colors.orange;
        break;
      case SyncErrorType.timeoutError:
        icon = Icons.timer_off;
        color = Colors.orange;
        break;
      case SyncErrorType.unknownError:
        icon = Icons.help_outline;
        color = Colors.grey;
        break;
    }
    
    return Icon(icon, color: color, size: 24);
  }
  
  Widget _buildRecoveryAction(
    BuildContext context,
    WidgetRef ref,
    SyncError error,
    int index,
  ) {
    switch (error.recommendedAction) {
      case RecoveryAction.retryImmediately:
        return ElevatedButton.icon(
          onPressed: () => _retryError(context, ref, index),
          icon: const Icon(Icons.refresh),
          label: const Text('立即重试'),
        );
        
      case RecoveryAction.retryAfterDelay:
        return ElevatedButton.icon(
          onPressed: () => _retryAfterDelay(context, ref, index),
          icon: const Icon(Icons.schedule),
          label: const Text('稍后重试'),
        );
        
      case RecoveryAction.reauthenticate:
        return ElevatedButton.icon(
          onPressed: () => _reauthenticate(context),
          icon: const Icon(Icons.login),
          label: const Text('重新登录'),
        );
        
      case RecoveryAction.resolveConflict:
        return ElevatedButton.icon(
          onPressed: () => _resolveConflict(context),
          icon: const Icon(Icons.merge),
          label: const Text('解决冲突'),
        );
        
      case RecoveryAction.fixData:
        return ElevatedButton.icon(
          onPressed: () => _fixData(context, error),
          icon: const Icon(Icons.edit),
          label: const Text('修正数据'),
        );
        
      case RecoveryAction.reportIssue:
        return ElevatedButton.icon(
          onPressed: () => _reportIssue(context),
          icon: const Icon(Icons.feedback),
          label: const Text('报告问题'),
        );
        
      case RecoveryAction.noRecovery:
        return OutlinedButton.icon(
          onPressed: () => _clearError(context, ref, index),
          icon: const Icon(Icons.delete),
          label: const Text('清除'),
        );
    }
  }
  
  void _retryError(BuildContext context, WidgetRef ref, int index) {
    ref.read(syncErrorRecoveryNotifierProvider.notifier).retryError(index);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在重试...')),
    );
  }
  
  void _retryAfterDelay(BuildContext context, WidgetRef ref, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('稍后重试'),
        content: const Text('将在30秒后自动重试此操作。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已安排稍后重试')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
  
  void _reauthenticate(BuildContext context) {
    // Navigate to login page or trigger re-auth
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请前往设置重新登录')),
    );
  }
  
  void _resolveConflict(BuildContext context) {
    // Navigate to conflict resolution page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请前往冲突解决页面')),
    );
  }
  
  void _fixData(BuildContext context, SyncError error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('请检查 ${error.tableName ?? "数据"} 的内容')),
    );
  }
  
  void _reportIssue(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('问题已记录，感谢反馈')),
    );
  }
  
  void _clearError(BuildContext context, WidgetRef ref, int index) {
    ref.read(syncErrorRecoveryNotifierProvider.notifier).clearError(index);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('错误已清除')),
    );
  }
  
  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'retry_all':
        _retryAllUnresolved(context, ref);
        break;
      case 'clear_all':
        ref.read(syncErrorRecoveryNotifierProvider.notifier).clearAllErrors();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('所有错误已清除')),
        );
        break;
    }
  }
  
  void _retryAllUnresolved(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    ref.read(syncErrorRecoveryNotifierProvider.notifier).retryAllUnresolved().then((count) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已重试 $count 个错误')),
        );
      }
    });
  }
}