import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:importers/importers.dart' hide FileType;
import 'package:database/database.dart' hide Transaction, Split, Account, ImportBatch;
import 'package:core/core.dart' show ImportBatchStatus;
import 'package:importers/src/utils/encoding_detector.dart';

import '../../providers/import_providers.dart';
import '../../data/import_error_messages.dart';
import '../../../accounts/data/account_provider.dart';
import '../widgets/field_mapping_dialog.dart';
import 'package:finance_app/core/widgets/loading_state_widget.dart';
import 'package:finance_app/core/widgets/error_state_widget.dart';

/// Helper to check if running on Android.
bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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
  
  // New state for encoding detection
  EncodingDetectionResult? _encodingResult;
  String? _manualEncoding;
  
  // New state for validation
  ImportValidationResult? _validationResult;
  Set<int> _duplicateRowIndices = {};
  int _totalRowCount = 0;
  
  // New state for progress
  bool _isImporting = false;
  ImportProgress _importProgress = const ImportProgress();

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
      return const LoadingStateWidget(
        message: '正在解析文件...',
        indicatorSize: 48,
      );
    }

    if (_error != null) {
      return ErrorStateWidget(
        title: '解析失败',
        message: _error,
        onRetry: _pickFile,
        retryText: '选择其他文件',
      );
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
            const SizedBox(height: 16),
            
            // Export guide button
            TextButton.icon(
              onPressed: () => context.push('/import/guide'),
              icon: const Icon(Icons.help_outline),
              label: const Text('如何导出？'),
            ),
            const SizedBox(height: 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      '$_fileName • ${_previewRows.length} 条预览 (共 $_totalRowCount 条)',
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
          
          // Show encoding information
          if (_encodingResult != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.code,
                    size: 16,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _encodingResult!.userDescription,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                    ),
                  ),
                  if (!_encodingResult!.isHighConfidence)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: OutlinedButton(
                        onPressed: _showEncodingDialog,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('手动选择', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ),
          
          // Show validation warnings
          if (_validationResult != null && (_validationResult!.hasWarnings || _validationResult!.hasDuplicates))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    size: 16,
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '发现 ${_validationResult!.warningCount} 条警告，${_validationResult!.duplicateCount} 条重复交易',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Add field mapping button
          if (_fieldMapping.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
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
              final rowIndex = _previewRows.indexOf(row);
              final isDuplicate = _duplicateRowIndices.contains(rowIndex);
              
              return DataRow(
                color: WidgetStateProperty.all(
                  isDuplicate 
                      ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5)
                      : null,
                ),
                cells: headers.map((header) {
                  final value = row[header]?.toString() ?? '';
                  return DataCell(
                    Row(
                      children: [
                        if (isDuplicate)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.content_copy,
                              size: 14,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            value,
                            overflow: TextOverflow.ellipsis,
                            style: isDuplicate 
                                ? TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  );
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
    return ErrorStateWidget(
      title: '解析失败',
      message: _error,
      onRetry: _pickFile,
      retryText: '选择其他文件',
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
          _error = _isAndroid
              ? '无法读取文件内容。\n\n可能原因：\n1. 文件权限不足\n2. 文件被其他应用占用\n3. 文件路径不可访问\n\n建议：尝试将文件复制到下载目录后重试'
              : '无法读取文件内容';
        });
        return;
      }

      // Check file size for Android memory safety
      if (_isAndroid && file.bytes!.length > 10 * 1024 * 1024) {
        setState(() {
          _error = '文件过大 (${(file.bytes!.length / 1024 / 1024).toStringAsFixed(1)}MB)，\n建议分批导出较小的文件。\n\n最大支持：10MB';
          _isLoading = false;
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
      
      // Detect encoding
      final encodingResult = EncodingDetector.detectWithConfidence(file.bytes!);

      // Store for later import
      _importer = importer;
      _importPreview = preview;
      
      // Run validation on preview data
      final validationResult = _validatePreview(preview);

      setState(() {
        _fileContent = file.bytes;
        _fileName = file.name;
        _detectedSource = importer.name;
        _previewRows = preview.rows;
        _totalRowCount = preview.totalRowCount;
        _encodingResult = encodingResult;
        _validationResult = validationResult;
        _isLoading = false;
      });
    } catch (e) {
      // Provide more helpful error messages for Android
      String errorMessage = e.toString();
      if (_isAndroid) {
        if (errorMessage.contains('GBK') || errorMessage.contains('gbk')) {
          errorMessage = '文件编码解析失败。\n\n可能原因：\n1. 文件使用特殊编码\n2. 文件损坏\n\n建议：\n1. 尝试用Excel打开后另存为UTF-8格式\n2. 联系开发者反馈此问题\n\n错误详情：$errorMessage';
        } else if (errorMessage.contains('permission') || errorMessage.contains('Permission')) {
          errorMessage = '文件权限不足。\n\n请尝试：\n1. 将文件复制到"下载"目录\n2. 重新选择文件';
        }
      }
      
      setState(() {
        _error = errorMessage;
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
      _encodingResult = null;
      _manualEncoding = null;
      _validationResult = null;
      _duplicateRowIndices = {};
      _totalRowCount = 0;
      _isImporting = false;
      _importProgress = const ImportProgress();
    });
  }
  
  /// Validate preview data and return validation result.
  ImportValidationResult _validatePreview(ImportPreview preview) {
    final warnings = <ValidationWarning>[];
    var validRows = preview.rows.length;
    
    // Check for required fields
    for (var i = 0; i < preview.rows.length; i++) {
      final row = preview.rows[i];
      
      // Check for missing date
      if (row['date'] == null && row['日期'] == null && row['交易时间'] == null) {
        warnings.add(ValidationWarning(
          row: i + 1,
          messageZh: '缺少日期字段',
          messageEn: 'Missing date field',
        ));
      }
      
      // Check for missing amount
      if (row['amount'] == null && row['金额'] == null && row['交易金额'] == null) {
        warnings.add(ValidationWarning(
          row: i + 1,
          messageZh: '缺少金额字段',
          messageEn: 'Missing amount field',
        ));
      }
    }
    
    // Check for potential duplicates (simplified check based on row similarity)
    final seenSignatures = <String, int>{};
    for (var i = 0; i < preview.rows.length; i++) {
      final row = preview.rows[i];
      final signature = '${row['date']}_${row['amount']}_${row['description'] ?? ''}';
      if (seenSignatures.containsKey(signature)) {
        warnings.add(ValidationWarning(
          row: i + 1,
          messageZh: '可能为重复交易 (与第 ${seenSignatures[signature]} 行相似)',
          messageEn: 'Potential duplicate (similar to row ${seenSignatures[signature]})',
          isDuplicate: true,
        ));
        _duplicateRowIndices.add(i);
      } else {
        seenSignatures[signature] = i + 1;
      }
    }
    
    return ImportValidationResult(
      warnings: warnings,
      duplicateRowIndices: _duplicateRowIndices.toList(),
      totalRows: preview.totalRowCount,
      validRows: validRows,
      detectedEncoding: _encodingResult?.encoding ?? 'utf-8',
      encodingConfidence: _encodingResult?.confidence ?? 1.0,
    );
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
  
  /// Show encoding selection dialog.
  Future<void> _showEncodingDialog() async {
    final encodings = ['UTF-8', 'GBK', 'GB2312', 'UTF-16 LE', 'UTF-16 BE'];
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择编码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('检测到的编码: ${_encodingResult?.encodingDisplayName ?? "未知"}'),
            Text('置信度: ${((_encodingResult?.confidence ?? 0) * 100).toInt()}%'),
            const SizedBox(height: 16),
            ...encodings.map((enc) => RadioListTile<String>(
              title: Text(enc),
              value: enc.toLowerCase().replaceAll(' ', ''),
              groupValue: _manualEncoding,
              onChanged: (value) {
                Navigator.pop(context, value);
              },
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('使用自动检测'),
          ),
        ],
      ),
    );
    
    if (result != null) {
      setState(() {
        _manualEncoding = result;
      });
      // Re-parse with new encoding
      if (_fileContent != null) {
        await _reparseWithEncoding(result);
      }
    }
  }
  
  /// Re-parse file with new encoding.
  Future<void> _reparseWithEncoding(String encoding) async {
    if (_importer == null || _fileContent == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final preview = await _importer!.preview(
        content: _fileContent!,
        maxRows: 20,
        encoding: encoding,
      );
      
      setState(() {
        _previewRows = preview.rows;
        _totalRowCount = preview.totalRowCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '编码解析失败: $e';
        _isLoading = false;
      });
    }
  }
  
  /// Build progress indicator for large file import.
  Widget _buildImportProgress() {
    final progress = _importProgress;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Progress bar
            if (progress.totalRows > 0)
              SizedBox(
                width: 300,
                child: LinearProgressIndicator(
                  value: progress.progress,
                  minHeight: 8,
                ),
              )
            else
              const CircularProgressIndicator(),
            
            const SizedBox(height: 24),
            
            // Progress text
            Text(
              progress.statusMessage,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            
            if (progress.totalRows > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${progress.currentRow} / ${progress.totalRows} 条 (${progress.progressPercent}%)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            
            // Estimated time
            if (progress.estimatedSecondsRemaining != null && progress.estimatedSecondsRemaining! > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '预计剩余: ${_formatTime(progress.estimatedSecondsRemaining!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            
            // Stats
            if (progress.successCount > 0 || progress.duplicateCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (progress.successCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, size: 16, color: Colors.green),
                            const SizedBox(width: 4),
                            Text('成功: ${progress.successCount}'),
                          ],
                        ),
                      ),
                    if (progress.duplicateCount > 0)
                      Row(
                        children: [
                          Icon(Icons.content_copy, size: 16, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text('重复: ${progress.duplicateCount}'),
                        ],
                      ),
                  ],
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Cancel button
            OutlinedButton.icon(
              onPressed: _cancelImport,
              icon: const Icon(Icons.cancel),
              label: const Text('取消导入'),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Format time in seconds to readable format.
  String _formatTime(int seconds) {
    if (seconds < 60) return '$seconds 秒';
    final minutes = seconds / 60;
    if (minutes < 60) return '${minutes.toInt()} 分钟';
    final hours = minutes / 60;
    return '${hours.toInt()} 小时 ${minutes.toInt() % 60} 分钟';
  }
  
  /// Cancel ongoing import.
  void _cancelImport() {
    ref.read(importNotifierProvider.notifier).cancelImport();
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
        _error = ImportErrorMessages.missingAccountError().getFullMessage(true);
      });
      return;
    }

    // Show warning about validation before importing
    if (_validationResult != null && _validationResult!.hasWarnings) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('验证警告'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('发现 ${_validationResult!.warningCount} 条警告'),
              Text('${_validationResult!.duplicateCount} 条可能为重复交易'),
              const SizedBox(height: 8),
              Text(
                '警告的交易仍可导入，重复交易将被自动跳过。\n是否继续导入?',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('继续导入'),
            ),
          ],
        ),
      );
      
      if (shouldContinue != true) return;
    }

    setState(() {
      _isImporting = true;
      _importProgress = ImportProgress(
        startTime: DateTime.now(),
        statusMessage: '准备导入...',
      );
    });

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
        onProgress: (progress) {
          setState(() {
            _importProgress = progress;
          });
        },
      );

      setState(() {
        _isImporting = false;
        _isLoading = false;
      });

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
              const SizedBox(height: 8),
              Text('耗时: ${_importProgress.elapsedSeconds} 秒'),
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
      // Check if cancelled
      if (ref.read(importNotifierProvider.notifier).isCancelled) {
        setState(() {
          _isImporting = false;
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导入已取消')),
        );
      } else {
        final errorMsg = ImportErrorMessages.fromException(e);
        setState(() {
          _error = errorMsg.getFullMessage(true);
          _isImporting = false;
          _isLoading = false;
        });
      }
    }
  }
}