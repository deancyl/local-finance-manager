import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:database/database.dart';
import 'package:core/core.dart' show ImportBatchStatus;

import '../../../accounts/data/account_provider.dart';
import '../../../../core/theme/app_theme.dart';

import '../../../accounts/data/account_provider.dart';

/// Provider for all import batches.
final importBatchesProvider = StreamProvider<List<ImportBatch>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.importBatches)
      .watch()
      .map((batches) => batches..sort((a, b) => b.importedAt.compareTo(a.importedAt)));
});

/// Provider for import sources lookup.
final importSourcesMapProvider = FutureProvider<Map<String, ImportSource>>((ref) async {
  final db = ref.watch(databaseProvider);
  final sources = await db.select(db.importSources).get();
  return {for (final s in sources) s.id: s};
});

/// Import history page showing past import batches.
class ImportHistoryPage extends ConsumerWidget {
  const ImportHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(importBatchesProvider);
    final sourcesAsync = ref.watch(importSourcesMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('导入历史'),
      ),
      body: batchesAsync.when(
        data: (batches) {
          if (batches.isEmpty) {
            return _buildEmptyState(context);
          }
          return sourcesAsync.when(
            data: (sources) => _buildBatchList(context, ref, batches, sources),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text('加载来源失败: $error'),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text('加载失败: $error'),
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
            Icons.history,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无导入记录',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '导入账单后，记录将显示在这里',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/import'),
            icon: const Icon(Icons.upload_file),
            label: const Text('导入账单'),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchList(
    BuildContext context,
    WidgetRef ref,
    List<ImportBatch> batches,
    Map<String, ImportSource> sources,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: batches.length,
      itemBuilder: (context, index) {
        final batch = batches[index];
        final source = sources[batch.sourceId];
        return _ImportBatchCard(
          batch: batch,
          source: source,
          onTap: () => _showBatchDetails(context, ref, batch, source),
        );
      },
    );
  }

  void _showBatchDetails(
    BuildContext context,
    WidgetRef ref,
    ImportBatch batch,
    ImportSource? source,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _BatchDetailSheet(
        batch: batch,
        source: source,
      ),
    );
  }
}

/// Card widget for displaying a single import batch.
class _ImportBatchCard extends StatelessWidget {
  final ImportBatch batch;
  final ImportSource? source;
  final VoidCallback onTap;

  const _ImportBatchCard({
    required this.batch,
    required this.source,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final statusColor = _getStatusColor(context, batch.status);
    final statusLabel = _getStatusLabel(batch.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getSourceIcon(source?.sourceType),
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      source?.name ?? '未知来源',
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.insert_drive_file_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      batch.filename ?? '未知文件',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(DateTime.fromMillisecondsSinceEpoch(batch.importedAt)),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const Spacer(),
                  _buildCountChip(
                    context,
                    Icons.check_circle_outline,
                    '${batch.successCount}',
                    Theme.of(context).colorScheme.primary,
                  ),
                  if (batch.duplicateCount > 0)
                    _buildCountChip(
                      context,
                      Icons.content_copy,
                      '${batch.duplicateCount}',
                      Theme.of(context).colorScheme.tertiary,
                    ),
                  if (batch.errorCount > 0)
                    _buildCountChip(
                      context,
                      Icons.error_outline,
                      '${batch.errorCount}',
                      Theme.of(context).colorScheme.error,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountChip(BuildContext context, IconData icon, String count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 2),
          Text(
            count,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(BuildContext context, String statusCode) {
    switch (statusCode) {
      case 'SUCCESS':
        return AppTheme.successColor;
      case 'PARTIAL':
        return AppTheme.warningColor;
      case 'FAILED':
        return AppTheme.errorColor;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  String _getStatusLabel(String statusCode) {
    switch (statusCode) {
      case 'SUCCESS':
        return '成功';
      case 'PARTIAL':
        return '部分成功';
      case 'FAILED':
        return '失败';
      default:
        return '未知';
    }
  }

  IconData _getSourceIcon(String? sourceType) {
    if (sourceType == null) return Icons.insert_drive_file;
    switch (sourceType.toUpperCase()) {
      case 'ALIPAY':
        return Icons.account_balance_wallet;
      case 'WECHAT':
        return Icons.chat;
      case 'BANK':
        return Icons.account_balance;
      default:
        return Icons.insert_drive_file;
    }
  }
}

/// Bottom sheet showing batch details and transactions.
class _BatchDetailSheet extends ConsumerStatefulWidget {
  final ImportBatch batch;
  final ImportSource? source;

  const _BatchDetailSheet({
    required this.batch,
    required this.source,
  });

  @override
  ConsumerState<_BatchDetailSheet> createState() => _BatchDetailSheetState();
}

class _BatchDetailSheetState extends ConsumerState<_BatchDetailSheet> {
  late Future<List<Transaction>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _transactionsFuture = _loadTransactions();
  }

  Future<List<Transaction>> _loadTransactions() async {
    final db = ref.read(databaseProvider);
    return (db.select(db.transactions)
          ..where((t) => t.importBatchId.equals(widget.batch.id)))
        .get();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 2);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '导入详情',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      context,
                      Icons.insert_drive_file,
                      '文件名',
                      widget.batch.filename ?? '未知',
                    ),
                    _buildDetailRow(
                      context,
                      Icons.source,
                      '来源',
                      widget.source?.name ?? '未知',
                    ),
                    _buildDetailRow(
                      context,
                      Icons.access_time,
                      '导入时间',
                      dateFormat.format(
                          DateTime.fromMillisecondsSinceEpoch(widget.batch.importedAt)),
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        _buildStatCard(
                          context,
                          '总记录',
                          '${widget.batch.recordCount}',
                          Icons.list,
                          Theme.of(context).colorScheme.primary,
                        ),
                        _buildStatCard(
                          context,
                          '成功',
                          '${widget.batch.successCount}',
                          Icons.check_circle,
                          AppTheme.successColor,
                        ),
                        _buildStatCard(
                          context,
                          '重复',
                          '${widget.batch.duplicateCount}',
                          Icons.content_copy,
                          Theme.of(context).colorScheme.tertiary,
                        ),
                        _buildStatCard(
                          context,
                          '失败',
                          '${widget.batch.errorCount}',
                          Icons.error,
                          AppTheme.errorColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Transactions list
              Expanded(
                child: FutureBuilder<List<Transaction>>(
                  future: _transactionsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('加载失败: ${snapshot.error}'));
                    }
                    final transactions = snapshot.data ?? [];
                    if (transactions.isEmpty) {
                      return const Center(child: Text('无交易记录'));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        return ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: Text(tx.description),
                          subtitle: Text(
                            dateFormat.format(
                                DateTime.fromMillisecondsSinceEpoch(tx.postDate)),
                          ),
                          trailing: Text(
                            currencyFormat.format(
                                tx.valueNum.toDouble() / tx.valueDenom.toDouble()),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: tx.valueNum >= 0
                                      ? AppTheme.incomeColor
                                      : AppTheme.expenseColor,
                                ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
