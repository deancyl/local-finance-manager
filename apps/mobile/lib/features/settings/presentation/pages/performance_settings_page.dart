import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'data/performance_provider.dart';
import '../../../database/database.dart';

/// Performance optimization settings page.
class PerformanceSettingsPage extends ConsumerStatefulWidget {
  const PerformanceSettingsPage({super.key});

  @override
  ConsumerState<PerformanceSettingsPage> createState() => _PerformanceSettingsPageState();
}

class _PerformanceSettingsPageState extends ConsumerState<PerformanceSettingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dbPerformanceProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = ref.watch(dbPerformanceProvider);
    final cacheStats = ref.watch(cacheStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('性能优化'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(dbPerformanceProvider.notifier).refresh(),
            tooltip: '刷新',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Database metrics section
            _SectionCard(
              title: '数据库统计',
              icon: Icons.storage,
              children: [
                _MetricRow(
                  label: '交易记录数',
                  value: metrics.totalTransactions.toString(),
                ),
                _MetricRow(
                  label: '账户数',
                  value: metrics.totalAccounts.toString(),
                ),
                _MetricRow(
                  label: '分类数',
                  value: metrics.totalCategories.toString(),
                ),
                _MetricRow(
                  label: '分录数',
                  value: metrics.totalSplits.toString(),
                ),
                if (metrics.dbSizeKB > 0)
                  _MetricRow(
                    label: '数据库大小',
                    value: '${metrics.dbSizeKB} KB',
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Query performance section
            _SectionCard(
              title: '查询性能',
              icon: Icons.speed,
              children: [
                _MetricRow(
                  label: '平均查询时间',
                  value: '${metrics.avgQueryTimeMs.toStringAsFixed(2)} ms',
                  valueColor: metrics.avgQueryTimeMs < 100
                      ? Colors.green
                      : metrics.avgQueryTimeMs < 500
                          ? Colors.orange
                          : Colors.red,
                ),
                _MetricRow(
                  label: '上次更新',
                  value: DateFormat('HH:mm:ss').format(metrics.lastUpdated),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Cache section
            _SectionCard(
              title: '缓存状态',
              icon: Icons.cached,
              children: [
                _MetricRow(
                  label: '已失效的 Provider',
                  value: cacheStats.invalidatedProviders.toString(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Optimization actions
            Text(
              '优化操作',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _ActionCard(
              icon: Icons.cleaning_services,
              title: '清理缓存',
              subtitle: '清除所有缓存数据，释放内存',
              onTap: () => _showClearCacheDialog(context),
            ),

            const SizedBox(height: 12),

            _ActionCard(
              icon: Icons.compress,
              title: '数据库优化',
              subtitle: '执行 VACUUM 操作，压缩数据库',
              onTap: () => _showOptimizeDbDialog(context),
            ),

            const SizedBox(height: 12),

            _ActionCard(
              icon: Icons.delete_sweep,
              title: '清理已删除记录',
              subtitle: '永久删除已标记为删除的记录',
              onTap: () => _showCleanupDeletedDialog(context),
            ),

            const SizedBox(height: 24),

            // Performance tips
            _PerformanceTipsCard(),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理缓存'),
        content: const Text('确定要清除所有缓存数据吗？这不会删除您的数据，但会暂时降低应用响应速度。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Invalidate all providers
              ref.invalidate(dbPerformanceProvider);
              ref.invalidate(cacheStatsProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('缓存已清理')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showOptimizeDbDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('数据库优化'),
        content: const Text('确定要优化数据库吗？这将在后台执行 VACUUM 操作，可能需要几秒钟。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final db = ref.read(databaseProvider);
                await db.customStatement('VACUUM');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('数据库优化完成')),
                  );
                  ref.read(dbPerformanceProvider.notifier).refresh();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('优化失败: $e')),
                  );
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showCleanupDeletedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理已删除记录'),
        content: const Text('确定要永久删除所有已标记为删除的记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final db = ref.read(databaseProvider);
                // Delete soft-deleted records
                await db.delete(db.transactions).where((t) => t.deletedAt.isNotNull()).go();
                await db.delete(db.accounts).where((a) => a.deletedAt.isNotNull()).go();
                await db.delete(db.categories).where((c) => c.deletedAt.isNotNull()).go();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('清理完成')),
                  );
                  ref.read(dbPerformanceProvider.notifier).refresh();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('清理失败: $e')),
                  );
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

/// Section card widget.
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Metric row widget.
class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MetricRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Action card widget.
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Performance tips card.
class _PerformanceTipsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tips_and_updates, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '性能提示',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('• 定期清理已删除记录以减少数据库大小'),
            const SizedBox(height: 4),
            const Text('• 使用日期范围筛选减少查询数据量'),
            const SizedBox(height: 4),
            const Text('• 大量数据导入后执行数据库优化'),
            const SizedBox(height: 4),
            const Text('• 定期备份数据保持数据健康'),
          ],
        ),
      ),
    );
  }
}
