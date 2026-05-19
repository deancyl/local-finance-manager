import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入账单'),
        actions: [
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
              '支持支付宝、微信支付、工商银行、建设银行、中国银行等导出的CSV文件',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 32),
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
      child: Row(
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

      // TODO: Parse file using importers package
      // For now, just show a placeholder
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _fileContent = file.bytes;
        _fileName = file.name;
        _detectedSource = '支付宝'; // Placeholder
        _previewRows = [
          {'日期': '2026-05-19', '金额': '-35.50', '描述': '美团外卖', '分类': '餐饮'},
          {'日期': '2026-05-18', '金额': '+5000.00', '描述': '工资', '分类': '收入'},
        ]; // Placeholder
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
    });
  }

  Future<void> _importTransactions() async {
    // TODO: Implement actual import
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入成功'),
        content: Text('已成功导入 ${_previewRows.length} 条交易记录'),
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
  }
}