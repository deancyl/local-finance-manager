import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/export_provider.dart';
import '../../data/export_service.dart';
import '../widgets/export_filter_dialog.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';
import 'package:finance_app/features/categories/data/category_provider.dart';

/// Export page for exporting data to CSV and JSON formats
class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  ExportFilters _filters = const ExportFilters();
  ExportFormat _selectedFormat = ExportFormat.csv;

  @override
  Widget build(BuildContext context) {
    final exportState = ref.watch(exportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('导出数据'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: '筛选条件',
            onPressed: exportState.status == ExportStatus.exporting
                ? null
                : () => _showFilterDialog(),
          ),
        ],
      ),
      body: ListView(
        children: [
          // Status card
          if (exportState.status != ExportStatus.idle)
            _buildStatusCard(exportState),

          // Format selection
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '导出格式',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          _buildFormatSelector(),

          const Divider(),

          // Export options
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '导出内容',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),

          // Transaction export
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('交易记录'),
            subtitle: Text(
              _filters.hasFilters
                  ? '已设置筛选条件'
                  : '导出所有交易记录',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: exportState.status == ExportStatus.exporting
                ? null
                : () => _exportTransactions(),
          ),

          // Account export
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: const Text('账户列表'),
            subtitle: const Text('导出所有账户信息'),
            trailing: const Icon(Icons.chevron_right),
            onTap: exportState.status == ExportStatus.exporting
                ? null
                : () => _exportAccounts(),
          ),

          // Category export
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('分类列表'),
            subtitle: const Text('导出所有分类信息'),
            trailing: const Icon(Icons.chevron_right),
            onTap: exportState.status == ExportStatus.exporting
                ? null
                : () => _exportCategories(),
          ),

          const Divider(),

          // Full backup
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '完整备份',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.backup, color: Colors.blue),
            title: const Text('完整数据备份'),
            subtitle: const Text('导出所有数据（交易、账户、分类、预算）'),
            trailing: const Icon(Icons.chevron_right),
            onTap: exportState.status == ExportStatus.exporting
                ? null
                : () => _exportFullBackup(),
          ),

          const Divider(),

          // Info section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '说明',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• CSV格式适合在Excel中查看和编辑\n'
                  '• JSON格式适合数据迁移和备份\n'
                  '• CSV文件使用UTF-8编码，兼容Excel\n'
                  '• 可通过筛选条件导出特定范围的数据',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Quick link to import
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => context.push('/settings/import'),
              icon: const Icon(Icons.download),
              label: const Text('前往导入数据'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ExportState exportState) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: exportState.status == ExportStatus.error
          ? Colors.red.shade50
          : exportState.status == ExportStatus.success
              ? Colors.green.shade50
              : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                if (exportState.status == ExportStatus.exporting)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (exportState.status == ExportStatus.success)
                  const Icon(Icons.check_circle, color: Colors.green)
                else if (exportState.status == ExportStatus.error)
                  const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    exportState.message ?? '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            if (exportState.status == ExportStatus.success &&
                exportState.result != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => ref.read(exportProvider.notifier).reset(),
                    child: const Text('关闭'),
                  ),
                  const SizedBox(width: 8),
                  if (Platform.isAndroid || Platform.isIOS)
                    ElevatedButton.icon(
                      onPressed: () =>
                          ref.read(exportProvider.notifier).shareResult(),
                      icon: const Icon(Icons.share),
                      label: const Text('分享文件'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormatSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<ExportFormat>(
        segments: const [
          ButtonSegment(
            value: ExportFormat.csv,
            label: Text('CSV'),
            icon: Icon(Icons.table_chart),
          ),
          ButtonSegment(
            value: ExportFormat.json,
            label: Text('JSON'),
            icon: Icon(Icons.code),
          ),
        ],
        selected: {_selectedFormat},
        onSelectionChanged: (Set<ExportFormat> selection) {
          setState(() {
            _selectedFormat = selection.first;
          });
        },
      ),
    );
  }

  void _showFilterDialog() async {
    final accounts = ref.read(accountsProvider);
    final categories = ref.read(categoriesProvider);

    final result = await showDialog<ExportFilters>(
      context: context,
      builder: (context) => ExportFilterDialog(
        initialFilters: _filters,
        accounts: accounts.when(
          data: (list) => list,
          loading: () => [],
          error: (_, __) => [],
        ),
        categories: categories.when(
          data: (list) => list,
          loading: () => [],
          error: (_, __) => [],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _filters = result;
      });
    }
  }

  void _exportTransactions() {
    final notifier = ref.read(exportProvider.notifier);

    if (_selectedFormat == ExportFormat.csv) {
      notifier.exportTransactionsToCSV(_filters);
    } else {
      notifier.exportTransactionsToJSON(_filters);
    }
  }

  void _exportAccounts() {
    ref.read(exportProvider.notifier).exportAccountsToJSON();
  }

  void _exportCategories() {
    ref.read(exportProvider.notifier).exportCategoriesToJSON();
  }

  void _exportFullBackup() {
    ref.read(exportProvider.notifier).exportFullBackup();
  }
}

/// Export format enum
enum ExportFormat {
  csv,
  json,
}
