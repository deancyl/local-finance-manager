import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/audit_provider.dart';

/// Filter state for audit logs
class AuditLogFilter {
  final DateTimeRange? dateRange;
  final String? entityType;
  final String? operation;

  const AuditLogFilter({
    this.dateRange,
    this.entityType,
    this.operation,
  });

  bool get hasActiveFilters =>
      dateRange != null || entityType != null || operation != null;

  AuditLogFilter copyWith({
    DateTimeRange? dateRange,
    String? entityType,
    String? operation,
    bool clearDateRange = false,
    bool clearEntityType = false,
    bool clearOperation = false,
  }) {
    return AuditLogFilter(
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      entityType: clearEntityType ? null : (entityType ?? this.entityType),
      operation: clearOperation ? null : (operation ?? this.operation),
    );
  }

  AuditLogFilter clear() => const AuditLogFilter();
}

/// Provider for audit log filter state
final auditLogFilterProvider = StateProvider<AuditLogFilter>((ref) {
  return const AuditLogFilter();
});

/// Provider for filtered audit logs
final filteredAuditLogsProvider = FutureProvider<List<AuditLogEntry>>((ref) async {
  final filter = ref.watch(auditLogFilterProvider);
  final auditService = ref.watch(auditServiceProvider);

  // Start with all logs
  List<AuditLogEntry> logs = await auditService.getRecentLogs(limit: 1000);

  // Apply date range filter
  if (filter.dateRange != null) {
    logs = logs.where((log) {
      final logDate = DateTime(
        log.changedAt.year,
        log.changedAt.month,
        log.changedAt.day,
      );
      final startDate = DateTime(
        filter.dateRange!.start.year,
        filter.dateRange!.start.month,
        filter.dateRange!.start.day,
      );
      final endDate = DateTime(
        filter.dateRange!.end.year,
        filter.dateRange!.end.month,
        filter.dateRange!.end.day,
      );
      return !logDate.isBefore(startDate) && !logDate.isAfter(endDate);
    }).toList();
  }

  // Apply entity type filter
  if (filter.entityType != null) {
    logs = logs.where((log) => log.entityType == filter.entityType).toList();
  }

  // Apply operation filter
  if (filter.operation != null) {
    logs = logs.where((log) => log.operation == filter.operation).toList();
  }

  // Return top 100 after filtering
  return logs.take(100).toList();
});

/// Audit log list page
class AuditLogPage extends ConsumerStatefulWidget {
  const AuditLogPage({super.key});

  @override
  ConsumerState<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends ConsumerState<AuditLogPage> {
  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(auditLogFilterProvider);
    final logsAsync = ref.watch(filteredAuditLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('审计日志'),
        actions: [
          if (filter.hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () => _clearFilters(ref),
              tooltip: '清除筛选',
            ),
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
      body: Column(
        children: [
          if (filter.hasActiveFilters) _buildActiveFiltersBar(filter, ref),
          Expanded(
            child: logsAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('暂无审计日志'),
                        if (filter.hasActiveFilters) ...[
                          const SizedBox(height: 16),
                          FilledButton.tonal(
                            onPressed: () => _clearFilters(ref),
                            child: const Text('清除筛选'),
                          ),
                        ],
                      ],
                    ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersBar(AuditLogFilter filter, WidgetRef ref) {
    final chips = <Widget>[];

    if (filter.dateRange != null) {
      final startStr = DateFormat('MM/dd').format(filter.dateRange!.start);
      final endStr = DateFormat('MM/dd').format(filter.dateRange!.end);
      chips.add(_buildFilterChip(
        label: '$startStr - $endStr',
        onClear: () {
          ref.read(auditLogFilterProvider.notifier).state =
              filter.copyWith(clearDateRange: true);
        },
      ));
    }

    if (filter.entityType != null) {
      final label = _getEntityTypeLabel(filter.entityType!);
      chips.add(_buildFilterChip(
        label: label,
        onClear: () {
          ref.read(auditLogFilterProvider.notifier).state =
              filter.copyWith(clearEntityType: true);
        },
      ));
    }

    if (filter.operation != null) {
      final label = _getOperationLabel(filter.operation!);
      chips.add(_buildFilterChip(
        label: label,
        onClear: () {
          ref.read(auditLogFilterProvider.notifier).state =
              filter.copyWith(clearOperation: true);
        },
      ));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: chips,
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onClear,
  }) {
    return InputChip(
      label: Text(label),
      onDeleted: onClear,
      deleteIcon: const Icon(Icons.close, size: 18),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  void _clearFilters(WidgetRef ref) {
    ref.read(auditLogFilterProvider.notifier).state = const AuditLogFilter();
  }

  String _getEntityTypeLabel(String entityType) {
    switch (entityType) {
      case 'account': return '账户';
      case 'transaction': return '交易';
      case 'split': return '分录';
      case 'category': return '分类';
      case 'budget': return '预算';
      default: return entityType;
    }
  }

  String _getOperationLabel(String operation) {
    switch (operation) {
      case 'CREATE': return '创建';
      case 'UPDATE': return '更新';
      case 'DELETE': return '删除';
      default: return operation;
    }
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

  void _showDateRangeFilter(BuildContext context, WidgetRef ref) async {
    final filter = ref.read(auditLogFilterProvider);
    final initialDateRange = filter.dateRange ?? DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: initialDateRange,
      builder: (context, child) {
        return child!;
      },
    );

    if (picked != null && context.mounted) {
      ref.read(auditLogFilterProvider.notifier).state =
          filter.copyWith(dateRange: picked);
    }
  }

  void _showEntityTypeFilter(BuildContext context, WidgetRef ref) {
    final filter = ref.read(auditLogFilterProvider);
    final entityTypes = [
      ('account', '账户'),
      ('transaction', '交易'),
      ('split', '分录'),
      ('category', '分类'),
      ('budget', '预算'),
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择实体类型'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: entityTypes.map((type) {
            final isSelected = filter.entityType == type.$1;
            return ListTile(
              title: Text(type.$2),
              leading: Radio<String>(
                value: type.$1,
                groupValue: filter.entityType,
                onChanged: (value) {
                  Navigator.pop(context);
                  if (value != null) {
                    ref.read(auditLogFilterProvider.notifier).state =
                        filter.copyWith(entityType: value);
                  }
                },
              ),
              trailing: isSelected
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                Navigator.pop(context);
                ref.read(auditLogFilterProvider.notifier).state =
                    filter.copyWith(entityType: type.$1);
              },
            );
          }).toList(),
        ),
        actions: [
          if (filter.entityType != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ref.read(auditLogFilterProvider.notifier).state =
                    filter.copyWith(clearEntityType: true);
              },
              child: const Text('清除'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showOperationFilter(BuildContext context, WidgetRef ref) {
    final filter = ref.read(auditLogFilterProvider);
    final operations = [
      ('CREATE', '创建'),
      ('UPDATE', '更新'),
      ('DELETE', '删除'),
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择操作类型'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: operations.map((op) {
            final isSelected = filter.operation == op.$1;
            return ListTile(
              title: Text(op.$2),
              leading: Radio<String>(
                value: op.$1,
                groupValue: filter.operation,
                onChanged: (value) {
                  Navigator.pop(context);
                  if (value != null) {
                    ref.read(auditLogFilterProvider.notifier).state =
                        filter.copyWith(operation: value);
                  }
                },
              ),
              trailing: isSelected
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                Navigator.pop(context);
                ref.read(auditLogFilterProvider.notifier).state =
                    filter.copyWith(operation: op.$1);
              },
            );
          }).toList(),
        ),
        actions: [
          if (filter.operation != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ref.read(auditLogFilterProvider.notifier).state =
                    filter.copyWith(clearOperation: true);
              },
              child: const Text('清除'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
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
