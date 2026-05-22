import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/audit_provider.dart';

/// Audit log list page
class AuditLogPage extends ConsumerWidget {
  const AuditLogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(recentAuditLogsProvider(100));

    return Scaffold(
      appBar: AppBar(
        title: const Text('审计日志'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context, ref),
            tooltip: '筛选',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showCleanupDialog(context, ref),
            tooltip: '清理旧日志',
          ),
        ],
      ),
      body: logsAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(
              child: Text('暂无审计日志'),
            );
          }

          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return AuditLogTile(log: log);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text('加载失败: $e'),
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('筛选审计日志'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('按日期范围'),
              leading: const Icon(Icons.date_range),
              onTap: () {
                Navigator.pop(context);
                _showDateRangeFilter(context, ref);
              },
            ),
            ListTile(
              title: const Text('按实体类型'),
              leading: const Icon(Icons.category),
              onTap: () {
                Navigator.pop(context);
                _showEntityTypeFilter(context, ref);
              },
            ),
            ListTile(
              title: const Text('按操作类型'),
              leading: const Icon(Icons.edit),
              onTap: () {
                Navigator.pop(context);
                _showOperationFilter(context, ref);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showDateRangeFilter(BuildContext context, WidgetRef ref) {
    // TODO: Implement date range picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('日期范围筛选功能开发中')),
    );
  }

  void _showEntityTypeFilter(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择实体类型'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['账户', '交易', '分录', '分类', '预算'].map((type) {
            return ListTile(
              title: Text(type),
              onTap: () {
                Navigator.pop(context);
                // TODO: Filter by entity type
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showOperationFilter(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择操作类型'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['创建', '更新', '删除'].map((op) {
            return ListTile(
              title: Text(op),
              onTap: () {
                Navigator.pop(context);
                // TODO: Filter by operation
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showCleanupDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理旧日志'),
        content: const Text('删除超过一年的审计日志？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final count = await ref.read(auditNotifierProvider.notifier).cleanupOldLogs();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已删除 $count 条日志')),
                );
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// Audit log tile for list display
class AuditLogTile extends StatelessWidget {
  final AuditLogEntry log;

  const AuditLogTile({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('MM-dd HH:mm:ss').format(log.changedAt);

    return ListTile(
      leading: _buildIcon(),
      title: Text(log.summary),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ID: ${log.entityId.substring(0, 8)}...'),
          if (log.description != null)
            Text(
              log.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (log.changedFields != null && log.changedFields!.isNotEmpty)
            Text(
              '变更字段: ${log.changedFields!.join(", ")}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
        ],
      ),
      trailing: Text(
        timeStr,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
      onTap: () => _showDetails(context),
    );
  }

  Widget _buildIcon() {
    IconData iconData;
    Color color;

    switch (log.operation) {
      case 'CREATE':
        iconData = Icons.add_circle;
        color = Colors.green;
        break;
      case 'UPDATE':
        iconData = Icons.edit;
        color = Colors.blue;
        break;
      case 'DELETE':
        iconData = Icons.delete;
        color = Colors.red;
        break;
      default:
        iconData = Icons.info;
        color = Colors.grey;
    }

    return Icon(iconData, color: color);
  }

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(log.summary),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('实体类型', log.entityTypeLabel),
              _buildDetailRow('实体ID', log.entityId),
              _buildDetailRow('操作', log.operationLabel),
              _buildDetailRow(
                '时间',
                DateFormat('yyyy-MM-dd HH:mm:ss').format(log.changedAt),
              ),
              if (log.changedBy != null)
                _buildDetailRow('操作者', log.changedBy!),
              if (log.sessionId != null)
                _buildDetailRow('会话ID', log.sessionId!),
              if (log.description != null)
                _buildDetailRow('描述', log.description!),
              if (log.changedFields != null && log.changedFields!.isNotEmpty)
                _buildDetailRow('变更字段', log.changedFields!.join(', ')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }
}

/// Audit log statistics widget
class AuditLogStats extends ConsumerWidget {
  const AuditLogStats({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(recentAuditLogsProvider(1000));

    return logsAsync.when(
      data: (logs) {
        final createCount = logs.where((l) => l.operation == 'CREATE').length;
        final updateCount = logs.where((l) => l.operation == 'UPDATE').length;
        final deleteCount = logs.where((l) => l.operation == 'DELETE').length;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '审计统计',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat('创建', createCount, Colors.green),
                    _buildStat('更新', updateCount, Colors.blue),
                    _buildStat('删除', deleteCount, Colors.red),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label),
      ],
    );
  }
}
