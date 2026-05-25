import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/theme_provider.dart';

class ThemeSettingsPage extends ConsumerWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('主题设置'),
      ),
      body: ListView(
        children: [
          _buildThemeModeSection(context, ref, themeSettings),
          const Divider(),
          _buildAccentColorSection(context, ref, themeSettings),
          const Divider(),
          _buildScheduledDarkModeSection(context, ref, themeSettings),
          const Divider(),
          _buildThemePreviewSection(context, ref, themeSettings),
        ],
      ),
    );
  }

  Widget _buildThemeModeSection(
    BuildContext context,
    WidgetRef ref,
    ThemeSettings settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '主题模式',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        RadioListTile<AppThemeMode>(
          title: const Text('跟随系统'),
          subtitle: const Text('根据系统设置自动切换'),
          value: AppThemeMode.system,
          groupValue: settings.mode,
          onChanged: (mode) {
            if (mode != null) {
              ref.read(themeProvider.notifier).setThemeMode(mode);
            }
          },
        ),
        RadioListTile<AppThemeMode>(
          title: const Text('浅色模式'),
          subtitle: const Text('始终使用浅色主题'),
          value: AppThemeMode.light,
          groupValue: settings.mode,
          onChanged: (mode) {
            if (mode != null) {
              ref.read(themeProvider.notifier).setThemeMode(mode);
            }
          },
        ),
        RadioListTile<AppThemeMode>(
          title: const Text('深色模式'),
          subtitle: const Text('始终使用深色主题'),
          value: AppThemeMode.dark,
          groupValue: settings.mode,
          onChanged: (mode) {
            if (mode != null) {
              ref.read(themeProvider.notifier).setThemeMode(mode);
            }
          },
        ),
        RadioListTile<AppThemeMode>(
          title: const Text('AMOLED 黑色'),
          subtitle: const Text('纯黑背景，适合 AMOLED 屏幕'),
          value: AppThemeMode.amoledBlack,
          groupValue: settings.mode,
          onChanged: (mode) {
            if (mode != null) {
              ref.read(themeProvider.notifier).setThemeMode(mode);
            }
          },
        ),
      ],
    );
  }

  Widget _buildAccentColorSection(
    BuildContext context,
    WidgetRef ref,
    ThemeSettings settings,
  ) {
    final predefinedColors = [
      const Color(0xFF2196F3), // Blue
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFF9800), // Orange
      const Color(0xFF9C27B0), // Purple
      const Color(0xFFF44336), // Red
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFFFFEB3B), // Yellow
      const Color(0xFF795548), // Brown
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '强调色',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: predefinedColors.map((color) {
              final isSelected = settings.accentColor.value == color.value;
              return GestureDetector(
                onTap: () {
                  ref.read(themeProvider.notifier).setAccentColor(color);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                            width: 3,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 24,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        ListTile(
          leading: Icon(
            Icons.palette,
            color: settings.accentColor,
          ),
          title: const Text('自定义颜色'),
          subtitle: Text(
            '当前: #${settings.accentColor.value.toRadixString(16).toUpperCase().padLeft(8, '0')}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showCustomColorPicker(context, ref, settings.accentColor),
        ),
      ],
    );
  }

  void _showCustomColorPicker(
    BuildContext context,
    WidgetRef ref,
    Color currentColor,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        Color selectedColor = currentColor;
        return AlertDialog(
          title: const Text('选择自定义颜色'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (color) {
                selectedColor = color;
              },
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                ref.read(themeProvider.notifier).setAccentColor(selectedColor);
                Navigator.pop(context);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScheduledDarkModeSection(
    BuildContext context,
    WidgetRef ref,
    ThemeSettings settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '定时深色模式',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        SwitchListTile(
          title: const Text('启用定时切换'),
          subtitle: const Text('在指定时间自动切换深色模式'),
          value: settings.useScheduledDarkMode,
          onChanged: (enabled) {
            ref.read(themeProvider.notifier).setScheduledDarkMode(enabled);
          },
        ),
        if (settings.useScheduledDarkMode) ...[
          ListTile(
            leading: const Icon(Icons.wb_twilight),
            title: const Text('开始时间'),
            subtitle: Text(
              '${settings.darkModeStartTime.hour.toString().padLeft(2, '0')}:${settings.darkModeStartTime.minute.toString().padLeft(2, '0')}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showTimePicker(
              context,
              ref,
              settings.darkModeStartTime,
              true,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.wb_sunny),
            title: const Text('结束时间'),
            subtitle: Text(
              '${settings.darkModeEndTime.hour.toString().padLeft(2, '0')}:${settings.darkModeEndTime.minute.toString().padLeft(2, '0')}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showTimePicker(
              context,
              ref,
              settings.darkModeEndTime,
              false,
            ),
          ),
        ],
      ],
    );
  }

  void _showTimePicker(
    BuildContext context,
    WidgetRef ref,
    TimeOfDay currentTime,
    bool isStartTime,
  ) async {
    final time = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );
    if (time != null) {
      final settings = ref.read(themeProvider);
      if (isStartTime) {
        ref.read(themeProvider.notifier).setDarkModeSchedule(
              startTime: time,
              endTime: settings.darkModeEndTime,
            );
      } else {
        ref.read(themeProvider.notifier).setDarkModeSchedule(
              startTime: settings.darkModeStartTime,
              endTime: time,
            );
      }
    }
  }

  Widget _buildThemePreviewSection(
    BuildContext context,
    WidgetRef ref,
    ThemeSettings settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '主题预览',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.preview),
          title: const Text('预览当前主题'),
          subtitle: Text('当前: ${_getThemeName(settings.mode)}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showThemePreview(context, settings),
        ),
      ],
    );
  }

  void _showThemePreview(BuildContext context, ThemeSettings settings) {
    showDialog(
      context: context,
      builder: (context) {
        return ThemePreviewDialog(settings: settings);
      },
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
      case AppThemeMode.amoledBlack:
        return 'AMOLED 黑色';
    }
  }
}

/// Simple color picker widget
class ColorPicker extends StatefulWidget {
  final Color pickerColor;
  final ValueChanged<Color> onColorChanged;
  final double pickerAreaHeightPercent;

  const ColorPicker({
    super.key,
    required this.pickerColor,
    required this.onColorChanged,
    this.pickerAreaHeightPercent = 0.8,
  });

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  late double _hue;
  late double _saturation;
  late double _value;

  @override
  void initState() {
    super.initState();
    final hsl = HSLColor.fromColor(widget.pickerColor);
    _hue = hsl.hue;
    _saturation = hsl.saturation;
    _value = hsl.lightness;
  }

  Color get currentColor {
    return HSLColor.fromAHSL(1.0, _hue, _saturation, _value).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                HSLColor.fromAHSL(1.0, _hue, 1.0, 0.5).toColor(),
                HSLColor.fromAHSL(1.0, _hue, 0.0, 0.5).toColor(),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: GestureDetector(
            onPanUpdate: (details) {
              final RenderBox box = context.findRenderObject() as RenderBox;
              final localPosition = box.globalToLocal(details.globalPosition);
              final saturation = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
              final lightness = (1.0 - localPosition.dy / box.size.height).clamp(0.0, 1.0);
              setState(() {
                _saturation = saturation;
                _value = lightness;
              });
              widget.onColorChanged(currentColor);
            },
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 24,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF0000),
                const Color(0xFFFFFF00),
                const Color(0xFF00FF00),
                const Color(0xFF00FFFF),
                const Color(0xFF0000FF),
                const Color(0xFFFF00FF),
                const Color(0xFFFF0000),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Slider(
            value: _hue,
            min: 0,
            max: 360,
            onChanged: (value) {
              setState(() {
                _hue = value;
              });
              widget.onColorChanged(currentColor);
            },
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: currentColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey, width: 2),
          ),
        ),
      ],
    );
  }
}

/// Theme preview dialog
class ThemePreviewDialog extends StatelessWidget {
  final ThemeSettings settings;

  const ThemePreviewDialog({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final isDark = settings.mode == AppThemeMode.dark ||
        settings.mode == AppThemeMode.amoledBlack;
    final backgroundColor = settings.mode == AppThemeMode.amoledBlack
        ? Colors.black
        : isDark
            ? const Color(0xFF121212)
            : const Color(0xFFFAFAFA);
    final cardColor = settings.mode == AppThemeMode.amoledBlack
        ? const Color(0xFF1A1A1A)
        : isDark
            ? const Color(0xFF1E1E1E)
            : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Dialog(
      child: Container(
        width: 320,
        height: 480,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: settings.accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: textColor),
                  const SizedBox(width: 8),
                  Text(
                    '金融管家',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '本月支出',
                            style: TextStyle(color: textColor.withOpacity(0.7)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '¥ 3,256.80',
                            style: TextStyle(
                              color: settings.accentColor,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.restaurant, color: settings.accentColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '餐饮',
                                  style: TextStyle(color: textColor),
                                ),
                                Text(
                                  '¥ 856.00',
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 60,
                            height: 6,
                            decoration: BoxDecoration(
                              color: textColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: 0.65,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: settings.accentColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPreviewNavButton(Icons.home, '首页', settings.accentColor),
                  _buildPreviewNavButton(Icons.bar_chart, '统计', textColor.withOpacity(0.5)),
                  _buildPreviewNavButton(Icons.add_circle, '', settings.accentColor, isLarge: true),
                  _buildPreviewNavButton(Icons.account_balance, '账户', textColor.withOpacity(0.5)),
                  _buildPreviewNavButton(Icons.settings, '设置', textColor.withOpacity(0.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewNavButton(
    IconData icon,
    String label,
    Color color, {
    bool isLarge = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color,
          size: isLarge ? 32 : 24,
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }
}
