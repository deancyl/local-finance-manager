import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/pending_operations_provider.dart';

/// Offline queue page showing pending sync operations.
class OfflineQueuePage extends ConsumerWidget {
  const OfflineQueuePage({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operations = ref.watch(pendingOperationsProvider);
    final notifier = ref.read(pendingOperationsNotifierProvider.notifier);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('离线队列'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: '全部同步',
            onPressed: () async {
              await notifier.retryAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('同步完成')),
                );
              }
            },
          ),
        ],
      ),
      body: operations.when(
        data: (ops) => ops.isEmpty
          ? _buildEmptyState(context)
          : _buildOperationsList(context, ref, ops),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                '加载失败: ${e.toString()}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(pendingOperationsProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
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
  
  Widget _buildOperationsList(
    BuildContext context,
    WidgetRef ref,
    List<PendingOperation> ops,
  ) {
    final grouped = ref.watch(pendingOperationsByTableProvider);
    final notifier = ref.read(pendingOperationsNotifierProvider.notifier);
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final tableName = grouped.keys.elementAt(index);
        final tableOps = grouped[tableName]!;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(_getTableDisplayName(tableName)),
            subtitle: Text(
              '${tableOps.length} 条待同步',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            leading: Icon(
              _getTableIcon(tableName),
              color: Theme.of(context).colorScheme.primary,
            ),
            children: tableOps
                .map((op) => _buildOperationTile(
                      context,
                      op,
                      () async {
                        await notifier.retryOperation(op.id);
                        ref.refresh(pendingOperationsProvider);
                      },
                      () async {
                        await notifier.discardOperation(op.id);
                        ref.refresh(pendingOperationsProvider);
                      },
                    ))
                .toList(),
          ),
        );
      },
    );
  }
  
  Widget _buildOperationTile(
    BuildContext context,
    PendingOperation op,
    VoidCallback onRetry,
    VoidCallback onDiscard,
  ) {
    return ListTile(
      leading: Icon(
        _getOperationIcon(op.operation),
        color: _getOperationColor(context, op.operation),
      ),
      title: Text(
        '${op.displayName} - ${op.tableDisplayName}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      subtitle: Text(
        'ID: ${op.recordId}\n'
        '创建时间: ${_formatTime(op.createdAt)}\n'
        '重试次数: ${op.retryCount}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重试',
            onPressed: onRetry,
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            tooltip: '丢弃',
            onPressed: onDiscard,
          ),
        ],
      ),
    );
  }
  
  String _getTableDisplayName(String tableName) {
    return switch (tableName) {
      'accounts' => '账户',
      'transactions' => '交易',
      'categories' => '分类',
      'budgets' => '预算',
      'splits' => '分录',
      _ => tableName,
    };
  }

  IconData _getTableIcon(String tableName) {
    return switch (tableName) {
      'accounts' => Icons.account_balance_wallet,
      'transactions' => Icons.receipt_long,
      'categories' => Icons.category,
      'budgets' => Icons.account_balance,
      'splits' => Icons.call_split,
      _ => Icons.table_chart,
    };
  }

  IconData _getOperationIcon(String operation) {
    return switch (operation) {
      'INSERT' => Icons.add_circle_outline,
      'UPDATE' => Icons.edit_outlined,
      'DELETE' => Icons.remove_circle_outline,
      _ => Icons.sync,
    };
  }

  Color _getOperationColor(BuildContext context, String operation) {
    return switch (operation) {
      'INSERT' => Colors.green,
      'UPDATE' => Theme.of(context).colorScheme.primary,
      'DELETE' => Theme.of(context).colorScheme.error,
      _ => Theme.of(context).colorScheme.outline,
    };
  }
  
  String _formatTime(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
           '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
