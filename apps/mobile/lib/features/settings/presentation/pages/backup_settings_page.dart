import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/backup_provider.dart';

class BackupSettingsPage extends ConsumerWidget {
  const BackupSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backupState = ref.watch(backupProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('数据备份'),
      ),
      body: ListView(
        children: [
          // Status card
          if (backupState.status != BackupStatus.idle)
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (backupState.status == BackupStatus.exporting ||
                        backupState.status == BackupStatus.importing)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (backupState.status == BackupStatus.success)
                      const Icon(Icons.check_circle, color: Colors.green)
                    else if (backupState.status == BackupStatus.error)
                      const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        backupState.message ?? '',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Export section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '导出数据',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('导出为JSON'),
            subtitle: const Text('导出所有账户、交易、分类和预算数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: backupState.status == BackupStatus.exporting
                ? null
                : () => _showExportDialog(context, ref),
          ),
          const Divider(),

          // Import section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '导入数据',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('从JSON导入'),
            subtitle: const Text('从备份文件恢复数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: backupState.status == BackupStatus.importing
                ? null
                : () => _importData(context, ref),
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
                const Text(
                  '• 导出的JSON文件包含所有用户数据\n'
                  '• 导入时会覆盖现有数据\n'
                  '• 建议定期备份重要数据\n'
                  '• 备份文件不包含加密密钥',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出数据'),
        content: const Text('确定要导出所有数据吗？\n导出的文件将包含账户、交易、分类和预算信息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _exportData(context, ref);
            },
            child: const Text('导出'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    // TODO: Get actual data from database
    // For now, export sample data structure
    final data = {
      'version': '0.3.12',
      'exportedAt': DateTime.now().toIso8601String(),
      'accounts': <Map<String, dynamic>>[],
      'transactions': <Map<String, dynamic>>[],
      'categories': <Map<String, dynamic>>[],
      'budgets': <Map<String, dynamic>>[],
    };

    await ref.read(backupProvider.notifier).exportData(data);
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    final data = await ref.read(backupProvider.notifier).importData();

    if (data != null && context.mounted) {
      // Show confirmation dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认导入'),
          content: Text(
            '即将导入备份文件中的数据。\n'
            '导出时间: ${data['exportedAt'] ?? '未知'}\n'
            '版本: ${data['version'] ?? '未知'}\n\n'
            '注意：导入将覆盖现有数据！',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: Implement actual import
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('导入功能开发中')),
                );
              },
              child: const Text('导入'),
            ),
          ],
        ),
      );
    }
  }
}
