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
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('安全设置'),
            subtitle: const Text('密码、生物识别'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('数据备份'),
            subtitle: const Text('导出、导入数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('同步设置'),
            subtitle: const Text('多设备同步'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/sync'),
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('主题设置'),
            subtitle: const Text('深色模式、主题色'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('语言'),
            subtitle: const Text('中文简体'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('关于'),
            subtitle: const Text('版本 1.0.0'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}