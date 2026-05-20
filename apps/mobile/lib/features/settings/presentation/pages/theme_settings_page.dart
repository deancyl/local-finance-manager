import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/theme_provider.dart';

class ThemeSettingsPage extends ConsumerWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('主题设置'),
      ),
      body: ListView(
        children: [
          RadioListTile<AppThemeMode>(
            title: const Text('跟随系统'),
            subtitle: const Text('根据系统设置自动切换'),
            value: AppThemeMode.system,
            groupValue: currentTheme,
            onChanged: (mode) {
              if (mode != null) {
                ref.read(themeProvider.notifier).setTheme(mode);
              }
            },
          ),
          RadioListTile<AppThemeMode>(
            title: const Text('浅色模式'),
            subtitle: const Text('始终使用浅色主题'),
            value: AppThemeMode.light,
            groupValue: currentTheme,
            onChanged: (mode) {
              if (mode != null) {
                ref.read(themeProvider.notifier).setTheme(mode);
              }
            },
          ),
          RadioListTile<AppThemeMode>(
            title: const Text('深色模式'),
            subtitle: const Text('始终使用深色主题'),
            value: AppThemeMode.dark,
            groupValue: currentTheme,
            onChanged: (mode) {
              if (mode != null) {
                ref.read(themeProvider.notifier).setTheme(mode);
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('主题预览'),
            subtitle: Text(
              '当前: ${_getThemeName(currentTheme)}',
            ),
          ),
        ],
      ),
    );
  }

  String _getThemeName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return '跟随系统';
      case AppThemeMode.light:
        return '浅色模式';
      case AppThemeMode.dark:
        return '深色模式';
    }
  }
}
