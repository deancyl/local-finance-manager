import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:importers/importers.dart';
import 'package:database/database.dart' hide Transaction, Split, Account, ImportBatch;
import 'package:core/core.dart' show ImportBatchStatus;

import '../../providers/import_providers.dart';
import '../../../accounts/data/account_provider.dart';
import '../widgets/field_mapping_dialog.dart';

/// Import page for importing transactions from financial institutions.
class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  Uint8List? _fileContent;
  String? _fileName;
  String? _detectedSource;
  List<Map<String, dynamic>> _previewRows = [];
  bool _isLoading = false;
  String? _error;
  
  // New state for real import
  ImporterBase? _importer;
  ImportPreview? _importPreview;
  String? _selectedAccountId;
  Map<String, String> _fieldMapping = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入账单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/import/history'),
            tooltip: '导入历史',
          ),
          if (_fileContent != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _clearFile,
              tooltip: '清除',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在解析文件...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return _buildError();
    }

    if (_fileContent == null) {
      return _buildSelectFile();
    }

    return _buildPreview();
  }

  Widget _buildSelectFile() {
    final accountsAsync = ref.watch(accountsProvider);
    final defaultAccount = ref.watch(defaultAssetAccountProvider);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.upload_file_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              '导入金融机构账单',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
Text(
               '支持支付宝、微信支付、工商银行、建设银行、中国银行等导出的CSV、XLS、XLSX文件',
               textAlign: TextAlign.center,
               style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                     color: Theme.of(context).colorScheme.onSurfaceVariant,
                   ),
             ),
            const SizedBox(height: 24),
            
            // Account selector
            accountsAsync.when(
              data: (accounts) {
                if (accounts.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: '导入到账户',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance_wallet),
                    ),
                    value: _selectedAccountId ?? defaultAccount?.id,
                    items: accounts.map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.name} (${a.accountType})'),
                    )).toList(),
                    onChanged: (value) {
                      setState(() => _selectedAccountId = value);
                    },
                  ),
                );
              },
              loading: () => const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
            
            FilledButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('选择文件'),
            ),
            const SizedBox(height: 24),
            _buildSupportedFormats(),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportedFormats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '支持的来源',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildSourceList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceList() {
    final sources = [
      ('支付宝', 'Alipay', Icons.account_balance_wallet),
      ('微信支付', 'WeChat Pay', Icons.chat),
      ('工商银行', 'ICBC', Icons.account_balance),
      ('建设银行', 'CCB', Icons.account_balance),
      ('中国银行', 'BOC', Icons.account_balance),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sources.map((source) {
        return Chip(
          avatar: Icon(source.$3, size: 18),
          label: Text(source.$1),
        );
      }).toList(),
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        _buildPreviewHeader(),
        Expanded(
          child: _buildPreviewTable(),
        ),
        _buildPreviewActions(),
      ],
    );
  }

  Widget _buildPreviewHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '文件已解析',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
                Text(
                  '$_fileName • ${_previewRows.length} 条记录',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
          if (_detectedSource != null)
            Chip(
              label: Text(_detectedSource!),
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
          // Add field mapping button
          if (_fieldMapping.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Chip(
                label: const Text('已映射'),
                avatar: const Icon(Icons.map, size: 16),
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewTable() {
    if (_previewRows.isEmpty) {
      return const Center(
        child: Text('没有可导入的数据'),
      );
    }

    final headers = _previewRows.first.keys.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            columns: headers.map((header) {
              return DataColumn(
                label: Text(
                  header,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
            rows: _previewRows.take(20).map((row) {
              return DataRow(
                cells: headers.map((header) {
                  return DataCell(Text(
                    row[header]?.toString() ?? '',
                    overflow: TextOverflow.ellipsis,
                  ));
                }).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Field mapping button (show when auto-detection might have failed)
          if (_previewRows.isNotEmpty && _importPreview?.headers.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: _showFieldMappingDialog,
                icon: Icon(
                  _fieldMapping.isEmpty ? Icons.map_outlined : Icons.edit,
                ),
                label: Text(
                  _fieldMapping.isEmpty ? '字段映射' : '编辑字段映射',
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新选择'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _importTransactions,
                  icon: const Icon(Icons.check),
                  label: Text('导入 ${_previewRows.length} 条'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '解析失败',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.refresh),
              label: const Text('选择其他文件'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xls', 'xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        setState(() {
          _error = '无法读取文件内容';
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Use real importer registry
      final registry = ref.read(importerRegistryProvider);
      final importer = registry.detectImporter(
        filename: file.name,
        content: file.bytes!,
      );

      if (importer == null) {
setState(() {
           _error = '不支持的文件格式。\n支持：支付宝、微信支付、工商银行、建设银行、中国银行的CSV、XLS、XLSX文件';
           _isLoading = false;
         });
        return;
      }

      // Get preview from importer
      final preview = await importer.preview(
        content: file.bytes!,
        maxRows: 20,
      );

      if (!preview.hasData) {
        setState(() {
          _error = '文件中没有可导入的数据';
          _isLoading = false;
        });
        return;
      }

      // Store for later import
      _importer = importer;
      _importPreview = preview;

      setState(() {
        _fileContent = file.bytes;
        _fileName = file.name;
        _detectedSource = importer.name;
        _previewRows = preview.rows;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _clearFile() {
    setState(() {
      _fileContent = null;
      _fileName = null;
      _detectedSource = null;
      _previewRows = [];
      _error = null;
      _importer = null;
      _importPreview = null;
      _fieldMapping = {};
    });
  }
  
  /// Show field mapping dialog for manual column mapping.
  Future<void> _showFieldMappingDialog() async {
    if (_importPreview == null) return;
    
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => FieldMappingDialog(
        columns: _importPreview!.headers,
        previewRows: _previewRows,
        initialMapping: _fieldMapping,
      ),
    );
    
    if (result != null) {
      setState(() {
        _fieldMapping = result;
      });
    }
  }

  Future<void> _importTransactions() async {
    if (_importer == null || _fileContent == null) {
      return;
    }

    // Get account ID (user selection or default)
    final accountId = _selectedAccountId ?? 
        ref.read(defaultAssetAccountProvider)?.id;
    
    if (accountId == null) {
      setState(() {
        _error = '请先创建一个账户';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(importNotifierProvider.notifier);
      
      // Build ImportConfig with field mapping if provided
      final config = ImportConfig(
        targetAccountId: accountId,
        defaultCurrencyId: 'CNY',
        fieldMapping: _fieldMapping,
        skipDuplicates: true,
        autoCategorize: true,
      );
      
      final batch = await notifier.performImportWithConfig(
        importer: _importer!,
        content: _fileContent!,
        config: config,
        filename: _fileName ?? 'unknown.csv',
      );

      setState(() => _isLoading = false);

      // Show result dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(batch.status == ImportBatchStatus.success 
              ? '导入成功' : '导入完成'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✓ 成功导入: ${batch.successCount} 条'),
              if (batch.duplicateCount > 0)
                Text('⊗ 跳过重复: ${batch.duplicateCount} 条'),
              if (batch.errorCount > 0)
                Text('✗ 导入失败: ${batch.errorCount} 条'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('完成'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _error = '导入失败: $e';
        _isLoading = false;
      });
    }
  }
}