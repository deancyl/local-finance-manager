import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:database/database.dart';
import '../../data/cost_center_provider.dart';
import '../widgets/add_cost_center_dialog.dart';

/// Cost centers management page.
/// 
/// Features:
/// - List all cost centers with hierarchy
/// - Create/edit/delete cost centers
/// - Set active/inactive status
/// - Filter by type
class CostCentersPage extends ConsumerWidget {
  const CostCentersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final costCentersAsync = ref.watch(costCentersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('成本中心'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context, ref),
            tooltip: '筛选',
          ),
        ],
      ),
      body: costCentersAsync.when(
        data: (costCenters) {
          if (costCenters.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildCostCenterList(context, ref, costCenters);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('加载失败: $error'),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无成本中心',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角按钮添加成本中心',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostCenterList(
    BuildContext context,
    WidgetRef ref,
    List<CostCenter> costCenters,
  ) {
    // Group by type
    final grouped = <String, List<CostCenter>>{};
    for (final cc in costCenters) {
      grouped.putIfAbsent(cc.costCenterType, () => []).add(cc);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final entry = grouped.entries.elementAt(index);
        final type = CostCenterType.fromCode(entry.key);
        final centers = entry.value;

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getTypeIcon(type),
                      size: 20,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      type.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${centers.length}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              ),
              // Cost centers list
              ...centers.map((cc) => _buildCostCenterTile(context, ref, cc)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCostCenterTile(
    BuildContext context,
    WidgetRef ref,
    CostCenter cc,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cc.isActive
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(
          cc.name.substring(0, 1),
          style: TextStyle(
            color: cc.isActive
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
      title: Text(
        cc.name,
        style: TextStyle(
          color: cc.isActive ? null : Theme.of(context).colorScheme.outline,
        ),
      ),
      subtitle: cc.code != null
          ? Text(
              cc.code!,
              style: TextStyle(
                color: cc.isActive ? null : Theme.of(context).colorScheme.outline,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: cc.isActive,
            onChanged: (value) {
              ref.read(costCenterNotifierProvider.notifier).setActive(cc.id, value);
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditDialog(context, ref, cc),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            color: Colors.red,
            onPressed: () => _confirmDelete(context, ref, cc),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(CostCenterType type) {
    switch (type) {
      case CostCenterType.department:
        return Icons.business;
      case CostCenterType.project:
        return Icons.folder;
      case CostCenterType.activity:
        return Icons.event;
      case CostCenterType.location:
        return Icons.location_on;
    }
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const AddCostCenterDialog(),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, CostCenter cc) {
    showDialog(
      context: context,
      builder: (context) => AddCostCenterDialog(costCenter: cc),
    );
  }

  void _showFilterDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('筛选'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: CostCenterType.values.map((type) {
            return ListTile(
              leading: Icon(_getTypeIcon(type)),
              title: Text(type.label),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement filter
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, CostCenter cc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除成本中心 "${cc.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(costCenterNotifierProvider.notifier).delete(cc.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
