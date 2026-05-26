import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../sync/data/sync_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncEnabled = ref.watch(syncFeatureFlagProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
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
            subtitle: const Text('版本 0.3.121'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/about'),
          ),
        ],
      ),
    );
  }
}
