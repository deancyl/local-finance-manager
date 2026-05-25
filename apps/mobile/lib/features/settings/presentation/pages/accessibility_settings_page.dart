import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/accessibility_provider.dart';

/// Accessibility settings page for configuring accessibility features.
class AccessibilitySettingsPage extends ConsumerWidget {
  const AccessibilitySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(accessibilityProvider);
    final notifier = ref.read(accessibilityProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('无障碍设置'),
      ),
      body: ListView(
        children: [
          // Screen Reader Section
          _buildSectionHeader(context, '屏幕阅读器'),
          SwitchListTile(
            secondary: const Icon(Icons.record_voice_over),
            title: const Text('屏幕阅读器优化'),
            subtitle: const Text('为屏幕阅读器提供更好的支持'),
            value: settings.screenReaderEnabled,
            onChanged: (value) => notifier.setScreenReaderEnabled(value),
          ),
          const Divider(),

          // Visual Section
          _buildSectionHeader(context, '视觉'),
          SwitchListTile(
            secondary: const Icon(Icons.contrast),
            title: const Text('高对比度模式'),
            subtitle: const Text('使用高对比度颜色方案'),
            value: settings.highContrastEnabled,
            onChanged: (value) => notifier.setHighContrastEnabled(value),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.format_bold),
            title: const Text('粗体文本'),
            subtitle: const Text('使用粗体文本提高可读性'),
            value: settings.boldText,
            onChanged: (value) => notifier.setBoldText(value),
          ),
          const Divider(),

          // Text Scaling Section
          _buildSectionHeader(context, '文本大小'),
          SwitchListTile(
            secondary: const Icon(Icons.text_fields),
            title: const Text('使用系统文本大小'),
            subtitle: const Text('跟随系统文本缩放设置'),
            value: settings.useSystemTextScale,
            onChanged: (value) => notifier.setUseSystemTextScale(value),
          ),
          if (!settings.useSystemTextScale) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '文本缩放: ${(settings.textScaleFactor * 100).toInt()}%',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: settings.textScaleFactor,
                    min: 0.8,
                    max: 2.0,
                    divisions: 12,
                    label: '${(settings.textScaleFactor * 100).toInt()}%',
                    onChanged: (value) => notifier.setTextScaleFactor(value),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildPresetButton(
                        context,
                        '正常',
                        1.0,
                        settings.textScaleFactor,
                        notifier,
                      ),
                      _buildPresetButton(
                        context,
                        '大',
                        1.15,
                        settings.textScaleFactor,
                        notifier,
                      ),
                      _buildPresetButton(
                        context,
                        '特大',
                        1.3,
                        settings.textScaleFactor,
                        notifier,
                      ),
                      _buildPresetButton(
                        context,
                        '超大',
                        1.5,
                        settings.textScaleFactor,
                        notifier,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const Divider(),

          // Focus Indicators Section
          _buildSectionHeader(context, '焦点指示器'),
          SwitchListTile(
            secondary: const Icon(Icons.center_focus_strong),
            title: const Text('增强焦点指示器'),
            subtitle: const Text('显示更明显的焦点边框'),
            value: settings.enhancedFocusIndicators,
            onChanged: (value) => notifier.setEnhancedFocusIndicators(value),
          ),
          if (settings.enhancedFocusIndicators) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '焦点边框粗细: ${settings.focusIndicatorThickness.toInt()}px',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: settings.focusIndicatorThickness,
                    min: 2.0,
                    max: 6.0,
                    divisions: 4,
                    label: '${settings.focusIndicatorThickness.toInt()}px',
                    onChanged: (value) => notifier.setFocusIndicatorThickness(value),
                  ),
                ],
              ),
            ),
          ],
          const Divider(),

          // Touch Target Section
          _buildSectionHeader(context, '触摸目标'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '最小触摸目标大小: ${settings.minTouchTargetSize.toInt()}dp',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '建议至少48dp以满足无障碍要求',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Slider(
                  value: settings.minTouchTargetSize,
                  min: 44.0,
                  max: 56.0,
                  divisions: 6,
                  label: '${settings.minTouchTargetSize.toInt()}dp',
                  onChanged: (value) => notifier.setMinTouchTargetSize(value),
                ),
              ],
            ),
          ),
          const Divider(),

          // Motion Section
          _buildSectionHeader(context, '动画'),
          SwitchListTile(
            secondary: const Icon(Icons.motion_photos_off),
            title: const Text('减少动画'),
            subtitle: const Text('减少界面动画效果'),
            value: settings.reduceAnimations,
            onChanged: (value) => notifier.setReduceAnimations(value),
          ),
          const Divider(),

          // Reset Section
          _buildSectionHeader(context, '重置'),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('恢复默认设置'),
            subtitle: const Text('将所有无障碍设置恢复为默认值'),
            onTap: () => _showResetConfirmation(context, notifier),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildPresetButton(
    BuildContext context,
    String label,
    double value,
    double currentValue,
    AccessibilityNotifier notifier,
  ) {
    final isSelected = (currentValue - value).abs() < 0.01;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => notifier.setTextScaleFactor(value),
    );
  }

  void _showResetConfirmation(
    BuildContext context,
    AccessibilityNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认重置'),
        content: const Text('确定要将所有无障碍设置恢复为默认值吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              notifier.resetToDefaults();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已恢复默认设置')),
              );
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}
