import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
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
          // Security settings
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('安全设置'),
            subtitle: const Text('密码、生物识别'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Implement security settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('安全设置功能开发中')),
              );
            },
          ),
          // Backup settings
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('数据备份'),
            subtitle: const Text('导出、导入数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Implement backup settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('数据备份功能开发中')),
              );
            },
          ),
          const Divider(),
          // About
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('关于'),
            subtitle: const Text('版本 0.3.11'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/about'),
          ),
        ],
      ),
    );
  }
}
