import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/backup_provider.dart';

/// Backup management page.
/// 
/// Features:
/// - Create manual backups
/// - Restore from backup
/// - View backup history
/// - Configure backup settings
/// - Auto-backup scheduling
class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backupsAsync = ref.watch(backupListProvider);
    final settings = ref.watch(backupSettingsProvider);
    final backupState = ref.watch(backupNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('数据备份'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context, ref),
            tooltip: '设置',
          ),
        ],
      ),
      body: Column(
        children: [
          // Auto-backup status card
          _buildAutoBackupCard(context, ref, settings),
          
          // Backup list
          Expanded(
            child: backupsAsync.when(
              data: (backups) {
                if (backups.isEmpty) {
                  return _buildEmptyState(context);
                }
                return _buildBackupList(context, ref, backups);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('加载失败: $error'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: backupState.isLoading
            ? null
            : () => _createBackup(context, ref),
        icon: backupState.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.backup),
        label: Text(backupState.isLoading ? '备份中...' : '立即备份'),
      ),
    );
  }

  Widget _buildAutoBackupCard(
    BuildContext context,
    WidgetRef ref,
    BackupSettings settings,
  ) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  settings.autoBackupEnabled
                      ? Icons.cloud_done
                      : Icons.cloud_off,
                  color: settings.autoBackupEnabled
                      ? Colors.green
                      : Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '自动备份',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        settings.autoBackupEnabled
                            ? '${settings.frequency.label}自动备份，保留最近 ${settings.retentionCount} 个'
                            : '未启用',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: settings.autoBackupEnabled,
                  onChanged: (value) {
                    ref.read(backupSettingsProvider.notifier).state =
                        settings.copyWith(autoBackupEnabled: value);
                  },
                ),
              ],
            ),
          ],
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
            Icons.backup_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无备份',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮创建备份',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupList(
    BuildContext context,
    WidgetRef ref,
    List<BackupMetadata> backups,
  ) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: backups.length,
      itemBuilder: (context, index) {
        final backup = backups[index];
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: backup.isVerified
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.errorContainer,
              child: Icon(
                backup.isVerified ? Icons.backup : Icons.warning,
                color: backup.isVerified
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            title: Text(
              dateFormat.format(backup.createdAt),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '大小: ${backup.formattedSize}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (backup.transactionCount > 0)
                  Text(
                    '交易: ${backup.transactionCount} 笔, 账户: ${backup.accountCount} 个',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleBackupAction(context, ref, backup, value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'restore',
                  child: ListTile(
                    leading: Icon(Icons.restore),
                    title: Text('恢复'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'verify',
                  child: ListTile(
                    leading: Icon(Icons.verified),
                    title: Text('验证'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('删除', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _createBackup(BuildContext context, WidgetRef ref) async {
    final metadata = await ref.read(backupNotifierProvider.notifier).createBackup();
    
    if (metadata != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('备份创建成功: ${metadata.formattedSize}'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: '查看',
            onPressed: () {
              // Navigate to backup details
            },
          ),
        ),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('备份创建失败'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleBackupAction(
    BuildContext context,
    WidgetRef ref,
    BackupMetadata backup,
    String action,
  ) {
    switch (action) {
      case 'restore':
        _confirmRestore(context, ref, backup);
        break;
      case 'verify':
        _verifyBackup(context, ref, backup);
        break;
      case 'delete':
        _confirmDelete(context, ref, backup);
        break;
    }
  }

  void _confirmRestore(BuildContext context, WidgetRef ref, BackupMetadata backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复备份'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('确定要恢复此备份吗？'),
            const SizedBox(height: 8),
            Text(
              '备份时间: ${DateFormat('yyyy-MM-dd HH:mm').format(backup.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '⚠️ 警告：当前数据将被替换，此操作不可撤销。建议先创建备份。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref
                  .read(backupNotifierProvider.notifier)
                  .restoreBackup(backup.filePath);
              
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('备份已恢复，请重启应用以生效'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('恢复失败'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('恢复'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyBackup(
    BuildContext context,
    WidgetRef ref,
    BackupMetadata backup,
  ) async {
    final isValid = await ref
        .read(backupNotifierProvider.notifier)
        .verifyBackup(backup.filePath);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isValid ? '备份验证通过' : '备份文件已损坏'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isValid ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, BackupMetadata backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除备份'),
        content: Text('确定要删除此备份吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(backupNotifierProvider.notifier).deleteBackup(backup.filePath);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, WidgetRef ref) {
    final settings = ref.read(backupSettingsProvider);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('备份设置'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('自动备份'),
                  value: settings.autoBackupEnabled,
                  onChanged: (value) {
                    setState(() {
                      ref.read(backupSettingsProvider.notifier).state =
                          settings.copyWith(autoBackupEnabled: value);
                    });
                  },
                ),
                ListTile(
                  title: const Text('备份频率'),
                  trailing: DropdownButton<BackupFrequency>(
                    value: settings.frequency,
                    items: BackupFrequency.values.map((f) {
                      return DropdownMenuItem(
                        value: f,
                        child: Text(f.label),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          ref.read(backupSettingsProvider.notifier).state =
                              settings.copyWith(frequency: value);
                        });
                      }
                    },
                  ),
                ),
                ListTile(
                  title: const Text('保留备份数量'),
                  trailing: DropdownButton<int>(
                    value: settings.retentionCount,
                    items: [5, 10, 20, 50].map((n) {
                      return DropdownMenuItem(
                        value: n,
                        child: Text('$n 个'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          ref.read(backupSettingsProvider.notifier).state =
                              settings.copyWith(retentionCount: value);
                        });
                      }
                    },
                  ),
                ),
                SwitchListTile(
                  title: const Text('包含附件'),
                  value: settings.includeAttachments,
                  onChanged: (value) {
                    setState(() {
                      ref.read(backupSettingsProvider.notifier).state =
                          settings.copyWith(includeAttachments: value);
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('压缩备份'),
                  value: settings.compressBackup,
                  onChanged: (value) {
                    setState(() {
                      ref.read(backupSettingsProvider.notifier).state =
                          settings.copyWith(compressBackup: value);
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          );
        },
      ),
    );
  }
}
