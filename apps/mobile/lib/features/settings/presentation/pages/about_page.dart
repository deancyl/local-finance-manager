import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 32),
          // App icon
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                size: 50,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // App name
          Center(
            child: Text(
              '本地金融管家',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          // Version
          Center(
            child: Text(
              '版本 0.3.9',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          // Description
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '简介',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '本地优先的个人金融资产管理软件，支持多平台、多设备同步、最高隐私保护。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Text(
                  '主要功能',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                const Text('• 多机构导入（支付宝、微信、银行等）'),
                const Text('• 本地加密存储'),
                const Text('• 多设备同步'),
                const Text('• 智能分析'),
                const Text('• 预算管理'),
                const Text('• 复式记账'),
              ],
            ),
          ),
          const Divider(),
          // Links
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('源代码'),
            subtitle: const Text('GitHub'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              // Could open GitHub URL
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('开源许可'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: '本地金融管家',
                applicationVersion: '0.3.9',
              );
            },
          ),
        ],
      ),
    );
  }
}
