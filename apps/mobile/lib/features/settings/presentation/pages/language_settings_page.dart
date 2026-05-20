import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/locale_provider.dart';

class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('语言设置'),
      ),
      body: ListView(
        children: [
          RadioListTile<AppLocale>(
            title: const Text('跟随系统'),
            subtitle: const Text('根据系统语言自动选择'),
            value: AppLocale.system,
            groupValue: currentLocale,
            onChanged: (locale) {
              if (locale != null) {
                ref.read(localeProvider.notifier).setLocale(locale);
              }
            },
          ),
          RadioListTile<AppLocale>(
            title: const Text('中文简体'),
            subtitle: const Text('简体中文'),
            value: AppLocale.zhCN,
            groupValue: currentLocale,
            onChanged: (locale) {
              if (locale != null) {
                ref.read(localeProvider.notifier).setLocale(locale);
              }
            },
          ),
          RadioListTile<AppLocale>(
            title: const Text('中文繁體'),
            subtitle: const Text('繁體中文'),
            value: AppLocale.zhTW,
            groupValue: currentLocale,
            onChanged: (locale) {
              if (locale != null) {
                ref.read(localeProvider.notifier).setLocale(locale);
              }
            },
          ),
          RadioListTile<AppLocale>(
            title: const Text('English'),
            subtitle: const Text('English (US)'),
            value: AppLocale.enUS,
            groupValue: currentLocale,
            onChanged: (locale) {
              if (locale != null) {
                ref.read(localeProvider.notifier).setLocale(locale);
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('当前语言'),
            subtitle: Text(currentLocale.displayName),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '注意：部分页面可能需要重启应用才能完全切换语言。',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}