import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/export_provider.dart';
import '../../data/export_service.dart';
import '../../data/custom_csv_export_service.dart';
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
                  '• QIF格式适合导入到Quicken、GnuCash等软件\n'
                  '• OFX格式适合导入到Microsoft Money、QuickBooks等软件\n'
                  '• Excel格式包含多工作表（交易、汇总、分类、趋势）\n'
                  '• PDF格式生成完整的财务报告\n'
                  '• 自定义CSV支持自定义列和模板\n'
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primary formats
          SegmentedButton<ExportFormat>(
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
              ButtonSegment(
                value: ExportFormat.xlsx,
                label: Text('Excel'),
                icon: Icon(Icons.table_bar),
              ),
              ButtonSegment(
                value: ExportFormat.pdf,
                label: Text('PDF'),
                icon: Icon(Icons.picture_as_pdf),
              ),
            ],
            selected: {_selectedFormat},
            onSelectionChanged: (Set<ExportFormat> selection) {
              setState(() {
                _selectedFormat = selection.first;
              });
            },
          ),
          const SizedBox(height: 12),
          // Additional formats
          SegmentedButton<ExportFormat>(
            segments: const [
              ButtonSegment(
                value: ExportFormat.qif,
                label: Text('QIF'),
                icon: Icon(Icons.description),
              ),
              ButtonSegment(
                value: ExportFormat.ofx,
                label: Text('OFX'),
                icon: Icon(Icons.account_balance),
              ),
              ButtonSegment(
                value: ExportFormat.customCsv,
                label: Text('自定义CSV'),
                icon: Icon(Icons.tune),
              ),
            ],
            selected: {_selectedFormat},
            onSelectionChanged: (Set<ExportFormat> selection) {
              setState(() {
                _selectedFormat = selection.first;
              });
            },
          ),
        ],
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

    switch (_selectedFormat) {
      case ExportFormat.csv:
        notifier.exportTransactionsToCSV(_filters);
        break;
      case ExportFormat.json:
        notifier.exportTransactionsToJSON(_filters);
        break;
      case ExportFormat.qif:
        notifier.exportTransactionsToQIF(_filters);
        break;
      case ExportFormat.ofx:
        notifier.exportTransactionsToOFX(_filters);
        break;
      case ExportFormat.xlsx:
        notifier.exportTransactionsToXLSX(_filters);
        break;
      case ExportFormat.pdf:
        notifier.exportTransactionsToPDF(_filters);
        break;
      case ExportFormat.customCsv:
        _showCustomCsvDialog();
        break;
    }
  }

  void _showCustomCsvDialog() async {
    final templates = ref.read(exportProvider.notifier).getCsvTemplates();
    final columns = ref.read(exportProvider.notifier).getAvailableCsvColumns();

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => _CustomCsvDialog(
        templates: templates,
        columns: columns,
      ),
    );

    if (result != null && mounted) {
      ref.read(exportProvider.notifier).exportCustomCSV(
        _filters,
        columnIds: result,
      );
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
  qif,
  ofx,
  xlsx,
  pdf,
  customCsv,
}

/// Custom CSV column selection dialog
class _CustomCsvDialog extends StatefulWidget {
  final List<CsvColumnTemplate> templates;
  final List<CsvColumnDefinition> columns;

  const _CustomCsvDialog({
    required this.templates,
    required this.columns,
  });

  @override
  State<_CustomCsvDialog> createState() => _CustomCsvDialogState();
}

class _CustomCsvDialogState extends State<_CustomCsvDialog> {
  List<String> _selectedColumns = [];
  int? _selectedTemplateIndex;

  @override
  void initState() {
    super.initState();
    // Default to standard template
    if (widget.templates.isNotEmpty) {
      _selectedTemplateIndex = 0;
      _selectedColumns = List.from(widget.templates.first.columnIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('自定义CSV导出'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Templates section
            const Text(
              '预设模板',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: widget.templates.asMap().entries.map((entry) {
                final index = entry.key;
                final template = entry.value;
                final isSelected = _selectedTemplateIndex == index;

                return ChoiceChip(
                  label: Text(template.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedTemplateIndex = index;
                        _selectedColumns = List.from(template.columnIds);
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Column selection
            const Text(
              '选择列',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                shrinkWrap: true,
                children: widget.columns.map((column) {
                  final isSelected = _selectedColumns.contains(column.id);

                  return CheckboxListTile(
                    title: Text(column.displayName),
                    subtitle: Text(column.id),
                    value: isSelected,
                    onChanged: (checked) {
                      setState(() {
                        _selectedTemplateIndex = null; // Deselect template
                        if (checked == true) {
                          _selectedColumns.add(column.id);
                        } else {
                          _selectedColumns.remove(column.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _selectedColumns.isEmpty
              ? null
              : () => Navigator.pop(context, _selectedColumns),
          child: const Text('导出'),
        ),
      ],
    );
  }
}
