import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:finance_app/core/presentation/widgets/customizable_dashboard.dart';
import 'package:finance_app/core/presentation/widgets/dashboard_config_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(dashboardConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('本地金融管家'),
        actions: [
          // Edit mode toggle button
          IconButton(
            icon: Icon(
              config.isEditMode ? Icons.check : Icons.edit_outlined,
            ),
            onPressed: () {
              ref.read(dashboardConfigProvider.notifier).toggleEditMode();
            },
            tooltip: config.isEditMode ? '完成编辑' : '编辑仪表盘',
          ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main dashboard content
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CustomizableDashboard(),
              ],
            ),
          ),
          // Edit mode bottom bar
          if (config.isEditMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildEditModeBottomBar(context, ref),
            ),
        ],
      ),
      floatingActionButton: config.isEditMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/transactions/add'),
              icon: const Icon(Icons.add),
              label: const Text('记一笔'),
            ),
    );
  }

  Widget _buildEditModeBottomBar(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                _showResetConfirmationDialog(context, ref);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重置'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () {
                ref.read(dashboardConfigProvider.notifier).toggleEditMode();
              },
              icon: const Icon(Icons.check),
              label: const Text('完成'),
            ),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmationDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置仪表盘'),
        content: const Text('确定要恢复默认的仪表盘布局吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(dashboardConfigProvider.notifier).resetToDefault();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已恢复默认布局'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }
}
