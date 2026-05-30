import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../sync/data/sync_providers.dart';
import '../../../transactions/data/transaction_provider.dart';
import '../../../reports/data/report_cache.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncEnabled = ref.watch(syncFeatureFlagProvider);
    final pageSize = ref.watch(pageSizePreferenceProvider);
    final cacheStats = ref.watch(cacheStatsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // Performance & Display Section (v0.3.199)
          _buildSectionHeader(context, '性能与显示'),
          ListTile(
            leading: const Icon(Icons.view_list),
            title: const Text('分页大小'),
            subtitle: Text('每页显示 $pageSize 条交易'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showPageSizeDialog(context, ref, pageSize),
          ),
          ListTile(
            leading: const Icon(Icons.memory),
            title: const Text('缓存状态'),
            subtitle: Text(_getCacheStatusText(cacheStats)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCacheInfoDialog(context, ref, cacheStats),
          ),
          ListTile(
            leading: Icon(
              Icons.cleaning_services,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text('清除缓存'),
            subtitle: const Text('清除报表缓存数据'),
            onTap: () => _showClearCacheDialog(context, ref),
          ),
          const Divider(),
          
          // Theme settings
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('主题设置'),
            subtitle: const Text('深色模式、主题色'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/theme'),
          ),
          // Language settings
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('语言'),
            subtitle: const Text('中文简体'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/language'),
          ),
          const Divider(),
          // Sync settings (with feature flag toggle)
          ListTile(
            leading: Icon(
              Icons.sync,
              color: isSyncEnabled 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
            ),
            title: const Text('同步设置'),
            subtitle: Text(
              isSyncEnabled ? '同步功能已启用' : '同步功能已禁用',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/sync'),
          ),
          // Security settings
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('安全设置'),
            subtitle: const Text('密码、PIN、生物识别'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/security'),
          ),
          // Backup settings
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('数据备份'),
            subtitle: const Text('导出、导入数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/backup'),
          ),
          // Export data
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('导出数据'),
            subtitle: const Text('导出交易、账户、分类'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/export'),
          ),
          // Import data
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('导入数据'),
            subtitle: const Text('从CSV或JSON导入'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/import'),
          ),
          // Tags management
          ListTile(
            leading: const Icon(Icons.label),
            title: const Text('标签管理'),
            subtitle: const Text('管理交易标签'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/tags'),
          ),
          // Currency & Exchange Rates
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text('货币与汇率'),
            subtitle: const Text('管理货币和汇率'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/currency'),
          ),
          // Import history
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('导入历史'),
            subtitle: const Text('查看历史导入记录'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/import/history'),
          ),
          const Divider(),
          // Period Closing
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('期间结账'),
            subtitle: const Text('管理会计期间结账'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/closing'),
          ),
          const Divider(),
          // Accessibility settings
          ListTile(
            leading: const Icon(Icons.accessibility_new),
            title: const Text('无障碍设置'),
            subtitle: const Text('屏幕阅读器、高对比度、文本大小'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/accessibility'),
          ),
          const Divider(),
          // About
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('关于'),
            subtitle: const Text('版本 0.3.199'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/about'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getCacheStatusText(Map<String, dynamic> stats) {
    if (stats['status'] == 'loading') {
      return '加载中...';
    }
    if (stats['status'] == 'error') {
      return '获取失败';
    }
    
    final memoryCacheSize = stats['memoryCacheSize'] as int? ?? 0;
    final maxCacheSize = stats['maxCacheSize'] as int? ?? 100;
    return '$memoryCacheSize / $maxCacheSize 条缓存';
  }

  void _showPageSizeDialog(BuildContext context, WidgetRef ref, int currentSize) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择分页大小'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: kPageSizeOptions.map((size) {
            return RadioListTile<int>(
              title: Text('$size 条/页'),
              subtitle: Text(_getPageSizeDescription(size)),
              value: size,
              groupValue: currentSize,
              onChanged: (value) {
                if (value != null) {
                  ref.read(pageSizePreferenceProvider.notifier).setPageSize(value);
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  String _getPageSizeDescription(int size) {
    switch (size) {
      case 25:
        return '适合低端设备';
      case 50:
        return '推荐 (默认)';
      case 100:
        return '适合高性能设备';
      case 200:
        return '适合大量数据浏览';
      default:
        return '';
    }
  }

  void _showCacheInfoDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> stats) {
    if (stats['status'] != null) {
      // Loading or error state
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('缓存状态'),
          content: const Text('无法获取缓存信息'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return;
    }

    final memoryCacheSize = stats['memoryCacheSize'] as int? ?? 0;
    final trialBalanceEntries = stats['trialBalanceEntries'] as int? ?? 0;
    final balanceSheetEntries = stats['balanceSheetEntries'] as int? ?? 0;
    final incomeStatementEntries = stats['incomeStatementEntries'] as int? ?? 0;
    final maxCacheSize = stats['maxCacheSize'] as int? ?? 100;
    final lastInvalidation = stats['lastInvalidation'] as String?;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('缓存状态'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('内存缓存: $memoryCacheSize / $maxCacheSize 条'),
            const SizedBox(height: 8),
            const Text('报表缓存详情:'),
            Text('  • 试算平衡表: $trialBalanceEntries 条'),
            Text('  • 资产负债表: $balanceSheetEntries 条'),
            Text('  • 利润表: $incomeStatementEntries 条'),
            const SizedBox(height: 8),
            if (lastInvalidation != null)
              Text('上次清理: $lastInvalidation')
            else
              const Text('缓存未被清理过'),
            const SizedBox(height: 16),
            Text(
              '提示: 缓存会在交易变更后自动失效，5分钟后过期。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除所有报表缓存吗？这不会影响您的交易数据，只是清除临时缓存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(cacheInvalidationNotifierProvider.notifier).clearCache();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('缓存已清除')),
              );
            },
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }
}
