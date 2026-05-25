import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/presentation/widgets/gesture_controls.dart';
import '../../../../core/presentation/widgets/gesture_config_provider.dart';

class GestureSettingsPage extends ConsumerWidget {
  const GestureSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(gestureConfigProvider);
    final notifier = ref.read(gestureConfigProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('手势设置'),
        actions: [
          TextButton(
            onPressed: () {
              notifier.resetToDefaults();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已重置为默认设置')),
              );
            },
            child: const Text('重置'),
          ),
        ],
      ),
      body: ListView(
        children: [
          // Swipe Actions Section
          _buildSectionHeader(context, '滑动动作'),
          _buildActionTile(
            context,
            title: '左滑动作',
            subtitle: '在交易记录上向左滑动的动作',
            currentAction: config.swipeLeft,
            onChanged: (action) => notifier.updateSwipeLeft(action),
          ),
          _buildActionTile(
            context,
            title: '右滑动作',
            subtitle: '在交易记录上向右滑动的动作',
            currentAction: config.swipeRight,
            onChanged: (action) => notifier.updateSwipeRight(action),
          ),
          const Divider(),
          
          // Press Actions Section
          _buildSectionHeader(context, '按压动作'),
          _buildActionTile(
            context,
            title: '长按动作',
            subtitle: '长按交易记录时显示菜单',
            currentAction: config.longPress,
            onChanged: (action) => notifier.updateLongPress(action),
          ),
          _buildActionTile(
            context,
            title: '双击动作',
            subtitle: '双击交易记录的动作',
            currentAction: config.doubleTap,
            onChanged: (action) => notifier.updateDoubleTap(action),
          ),
          const Divider(),
          
          // Gesture Settings Section
          _buildSectionHeader(context, '手势参数'),
          SwitchListTile(
            title: const Text('触觉反馈'),
            subtitle: const Text('执行手势时震动反馈'),
            value: config.enableHapticFeedback,
            onChanged: (value) => notifier.updateHapticFeedback(value),
          ),
          ListTile(
            title: const Text('滑动阈值'),
            subtitle: Text('触发动作的滑动距离：${(config.swipeThreshold * 100).toInt()}%'),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: config.swipeThreshold,
                min: 0.15,
                max: 0.5,
                divisions: 7,
                onChanged: (value) => notifier.updateSwipeThreshold(value),
              ),
            ),
          ),
          ListTile(
            title: const Text('长按时长'),
            subtitle: Text('触发长按的时长：${config.longPressDuration.inMilliseconds}毫秒'),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: config.longPressDuration.inMilliseconds.toDouble(),
                min: 200,
                max: 1000,
                divisions: 8,
                onChanged: (value) => notifier.updateLongPressDuration(
                  Duration(milliseconds: value.toInt()),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Preview Section
          _buildSectionHeader(context, '手势预览'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      '尝试以下手势：',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    _buildPreviewItem(
                      context,
                      '← 左滑',
                      config.swipeLeft,
                    ),
                    const SizedBox(height: 8),
                    _buildPreviewItem(
                      context,
                      '右滑 →',
                      config.swipeRight,
                    ),
                    const SizedBox(height: 8),
                    _buildPreviewItem(
                      context,
                      '长按',
                      config.longPress,
                    ),
                    const SizedBox(height: 8),
                    _buildPreviewItem(
                      context,
                      '双击',
                      config.doubleTap,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
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
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required GestureAction currentAction,
    required void Function(GestureAction) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: _buildActionChip(context, currentAction),
      onTap: () => _showActionPicker(
        context,
        currentAction: currentAction,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildActionChip(BuildContext context, GestureAction action) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getActionColor(action).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getActionColor(action)),
      ),
      child: Text(
        _getActionName(action),
        style: TextStyle(
          color: _getActionColor(action),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPreviewItem(BuildContext context, String gesture, GestureAction action) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(gesture, style: Theme.of(context).textTheme.bodyMedium),
        _buildActionChip(context, action),
      ],
    );
  }

  void _showActionPicker(
    BuildContext context, {
    required GestureAction currentAction,
    required void Function(GestureAction) onChanged,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '选择动作',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(),
            ...GestureAction.values.map((action) => ListTile(
                  leading: Icon(_getActionIcon(action), color: _getActionColor(action)),
                  title: Text(_getActionName(action)),
                  trailing: action == currentAction
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    onChanged(action);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _getActionName(GestureAction action) {
    switch (action) {
      case GestureAction.delete:
        return '删除';
      case GestureAction.edit:
        return '编辑';
      case GestureAction.duplicate:
        return '复制';
      case GestureAction.archive:
        return '归档';
      case GestureAction.categorize:
        return '分类';
      case GestureAction.addNote:
        return '添加备注';
      case GestureAction.transfer:
        return '转账';
      case GestureAction.none:
        return '无';
    }
  }

  Color _getActionColor(GestureAction action) {
    switch (action) {
      case GestureAction.delete:
        return Colors.red;
      case GestureAction.edit:
        return Colors.blue;
      case GestureAction.duplicate:
        return Colors.green;
      case GestureAction.archive:
        return Colors.orange;
      case GestureAction.categorize:
        return Colors.purple;
      case GestureAction.addNote:
        return Colors.teal;
      case GestureAction.transfer:
        return Colors.indigo;
      case GestureAction.none:
        return Colors.grey;
    }
  }

  IconData _getActionIcon(GestureAction action) {
    switch (action) {
      case GestureAction.delete:
        return Icons.delete;
      case GestureAction.edit:
        return Icons.edit;
      case GestureAction.duplicate:
        return Icons.copy;
      case GestureAction.archive:
        return Icons.archive;
      case GestureAction.categorize:
        return Icons.category;
      case GestureAction.addNote:
        return Icons.note_add;
      case GestureAction.transfer:
        return Icons.swap_horiz;
      case GestureAction.none:
        return Icons.block;
    }
  }
}
