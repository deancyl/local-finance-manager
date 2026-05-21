import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/export_provider.dart';

/// Import page for importing data from CSV and JSON files
class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  bool _skipDuplicates = true;
  bool _mergeAccounts = false;
  bool _mergeCategories = false;

  @override
  Widget build(BuildContext context) {
    final importState = ref.watch(importProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('导入数据'),
      ),
      body: ListView(
        children: [
          // Status card
          if (importState.status != ImportStatus.idle)
            _buildStatusCard(importState),

          // File selection
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '选择文件',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.file_open),
            title: const Text('选择导入文件'),
            subtitle: const Text('支持 CSV 和 JSON 格式'),
            trailing: const Icon(Icons.chevron_right),
            onTap: importState.status == ImportStatus.importing ||
                    importState.status == ImportStatus.validating ||
                    importState.status == ImportStatus.previewing
                ? null
                : () => _pickFile(),
          ),

          // Preview section
          if (importState.preview != null)
            _buildPreviewSection(importState),

          const Divider(),

          // Import options
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '导入选项',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),

          SwitchListTile(
            title: const Text('跳过重复记录'),
            subtitle: const Text('根据外部ID判断是否重复'),
            value: _skipDuplicates,
            onChanged: importState.status == ImportStatus.importing
                ? null
                : (value) {
                    setState(() {
                      _skipDuplicates = value;
                    });
                  },
          ),

          SwitchListTile(
            title: const Text('合并账户'),
            subtitle: const Text('更新已存在的账户信息'),
            value: _mergeAccounts,
            onChanged: importState.status == ImportStatus.importing
                ? null
                : (value) {
                    setState(() {
                      _mergeAccounts = value;
                    });
                  },
          ),

          SwitchListTile(
            title: const Text('合并分类'),
            subtitle: const Text('更新已存在的分类信息'),
            value: _mergeCategories,
            onChanged: importState.status == ImportStatus.importing
                ? null
                : (value) {
                    setState(() {
                      _mergeCategories = value;
                    });
                  },
          ),

          const Divider(),

          // Import button
          if (importState.preview != null && !importState.preview!.errors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: importState.status == ImportStatus.importing
                    ? null
                    : () => _startImport(importState),
                icon: importState.status == ImportStatus.importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download),
                label: Text(
                  importState.status == ImportStatus.importing
                      ? '正在导入...'
                      : '开始导入',
                ),
              ),
            ),

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
                  '• CSV文件需包含必需列：日期、描述、账户、金额\n'
                  '• JSON文件支持完整数据导入（交易、账户、分类）\n'
                  '• 导入前会显示预览，确认无误后再导入\n'
                  '• 建议导入前先备份现有数据',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Quick link to export
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => context.push('/settings/export'),
              icon: const Icon(Icons.upload),
              label: const Text('前往导出数据'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ImportState importState) {
    Color? cardColor;
    if (importState.status == ImportStatus.error) {
      cardColor = Colors.red.shade50;
    } else if (importState.status == ImportStatus.success) {
      cardColor = Colors.green.shade50;
    }

    return Card(
      margin: const EdgeInsets.all(16),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                if (importState.status == ImportStatus.validating ||
                    importState.status == ImportStatus.previewing ||
                    importState.status == ImportStatus.importing)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (importState.status == ImportStatus.success)
                  const Icon(Icons.check_circle, color: Colors.green)
                else if (importState.status == ImportStatus.error)
                  const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    importState.message ?? '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            if (importState.status == ImportStatus.success) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => ref.read(importProvider.notifier).reset(),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection(ImportState importState) {
    final preview = importState.preview!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '文件预览',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),

        // File info
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('格式', preview.format),
                if (preview.version != null)
                  _buildInfoRow('版本', preview.version!),
                if (preview.exportedAt != null)
                  _buildInfoRow(
                    '导出时间',
                    DateFormat('yyyy-MM-dd HH:mm').format(preview.exportedAt!),
                  ),
                if (preview.transactionCount > 0)
                  _buildInfoRow('交易记录', '${preview.transactionCount} 条'),
                if (preview.accountCount > 0)
                  _buildInfoRow('账户', '${preview.accountCount} 个'),
                if (preview.categoryCount > 0)
                  _buildInfoRow('分类', '${preview.categoryCount} 个'),
              ],
            ),
          ),
        ),

        // Warnings
        if (preview.warnings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '警告 (${preview.warnings.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...preview.warnings.take(5).map(
                          (w) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• $w'),
                          ),
                        ),
                    if (preview.warnings.length > 5)
                      Text('• 还有 ${preview.warnings.length - 5} 条警告...'),
                  ],
                ),
              ),
            ),
          ),

        // Errors
        if (preview.errors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          '错误 (${preview.errors.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...preview.errors.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• $e'),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    await ref.read(importProvider.notifier).pickAndValidateFile();
  }

  void _startImport(ImportState importState) {
    final preview = importState.preview;
    if (preview == null) return;

    final notifier = ref.read(importProvider.notifier);

    if (preview.format == 'CSV') {
      notifier.importFromCSV(skipDuplicates: _skipDuplicates);
    } else {
      notifier.importFromJSON(
        skipDuplicates: _skipDuplicates,
        mergeAccounts: _mergeAccounts,
        mergeCategories: _mergeCategories,
      );
    }
  }
}
