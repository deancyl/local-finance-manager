import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;

import 'package:database/database.dart';
import '../../data/account_provider.dart';
import '../widgets/account_tree_node.dart';
import '../widgets/add_account_dialog.dart';
import '../widgets/move_account_dialog.dart';

/// Account hierarchy management page with visual tree view.
/// 
/// Features:
/// - Visual tree view with collapsible nodes
/// - Drag-and-drop reordering
/// - Parent-child relationship management
/// - Account type icons
/// - Balance roll-up display
class AccountHierarchyPage extends ConsumerStatefulWidget {
  const AccountHierarchyPage({super.key});

  @override
  ConsumerState<AccountHierarchyPage> createState() => _AccountHierarchyPageState();
}

class _AccountHierarchyPageState extends ConsumerState<AccountHierarchyPage> {
  bool _isSearchExpanded = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  
  /// Track expanded state for each account
  final Map<String, bool> _expandedNodes = {};
  
  /// Currently selected account type filter (null = all)
  String? _selectedTypeFilter;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hierarchy = ref.watch(filteredAccountHierarchyProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearchExpanded
            ? _buildSearchField()
            : const Text('账户层级管理'),
        actions: [
          IconButton(
            icon: Icon(_isSearchExpanded ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
            tooltip: _isSearchExpanded ? '关闭搜索' : '搜索',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context),
            tooltip: '添加账户',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'expand_all',
                child: ListTile(
                  leading: Icon(Icons.unfold_more),
                  title: Text('全部展开'),
                ),
              ),
              const PopupMenuItem(
                value: 'collapse_all',
                child: ListTile(
                  leading: Icon(Icons.unfold_less),
                  title: Text('全部折叠'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'regenerate_codes',
                child: ListTile(
                  leading: Icon(Icons.numbers),
                  title: Text('重新生成账户代码'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Type filter chips
          _buildTypeFilterChips(),
          // Account tree
          Expanded(
            child: _buildAccountTree(context, hierarchy),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('添加账户'),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      autofocus: true,
      decoration: InputDecoration(
        hintText: '搜索账户...',
        border: InputBorder.none,
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        suffixIcon: ref.watch(searchQueryProvider).isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  _searchController.clear();
                  ref.read(searchQueryProvider.notifier).state = '';
                },
              )
            : null,
      ),
      onChanged: (value) {
        ref.read(searchQueryProvider.notifier).state = value;
      },
    );
  }

  void _toggleSearch() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
      if (!_isSearchExpanded) {
        _searchController.clear();
        ref.read(searchQueryProvider.notifier).state = '';
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }

  Widget _buildTypeFilterChips() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildTypeFilterChip(
            label: '全部',
            isSelected: _selectedTypeFilter == null,
            onTap: () => setState(() => _selectedTypeFilter = null),
          ),
          const SizedBox(width: 8),
          _buildTypeFilterChip(
            label: '资产',
            icon: Icons.account_balance_wallet,
            color: Colors.green,
            isSelected: _selectedTypeFilter == 'ASSET',
            onTap: () => setState(() => _selectedTypeFilter = 'ASSET'),
          ),
          const SizedBox(width: 8),
          _buildTypeFilterChip(
            label: '负债',
            icon: Icons.trending_down,
            color: Colors.red,
            isSelected: _selectedTypeFilter == 'LIABILITY',
            onTap: () => setState(() => _selectedTypeFilter = 'LIABILITY'),
          ),
          const SizedBox(width: 8),
          _buildTypeFilterChip(
            label: '权益',
            icon: Icons.pie_chart,
            color: Colors.purple,
            isSelected: _selectedTypeFilter == 'EQUITY',
            onTap: () => setState(() => _selectedTypeFilter = 'EQUITY'),
          ),
          const SizedBox(width: 8),
          _buildTypeFilterChip(
            label: '收入',
            icon: Icons.arrow_upward,
            color: Colors.blue,
            isSelected: _selectedTypeFilter == 'INCOME',
            onTap: () => setState(() => _selectedTypeFilter = 'INCOME'),
          ),
          const SizedBox(width: 8),
          _buildTypeFilterChip(
            label: '支出',
            icon: Icons.arrow_downward,
            color: Colors.orange,
            isSelected: _selectedTypeFilter == 'EXPENSE',
            onTap: () => setState(() => _selectedTypeFilter = 'EXPENSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterChip({
    required String label,
    IconData? icon,
    Color? color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.primary;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : chipColor,
            ),
            const SizedBox(width: 4),
          ],
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: theme.colorScheme.surface,
      selectedColor: chipColor,
      labelStyle: TextStyle(
        color: isSelected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? chipColor : theme.colorScheme.outline,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildAccountTree(
    BuildContext context,
    Map<String, List<AccountTreeNode>> hierarchy,
  ) {
    // Determine which types to show based on filter
    final typesToShow = _selectedTypeFilter != null
        ? [_selectedTypeFilter!]
        : ['ASSET', 'LIABILITY', 'EQUITY', 'INCOME', 'EXPENSE'];

    // Check if any accounts exist
    final hasAnyAccounts = typesToShow.any((type) => hierarchy[type]?.isNotEmpty ?? false);

    if (!hasAnyAccounts) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: typesToShow.length,
      itemBuilder: (context, index) {
        final type = typesToShow[index];
        final nodes = hierarchy[type] ?? [];

        if (nodes.isEmpty && _selectedTypeFilter == null) {
          return const SizedBox.shrink();
        }

        return _buildTypeSection(context, type, nodes);
      },
    );
  }

  Widget _buildTypeSection(
    BuildContext context,
    String accountType,
    List<AccountTreeNode> nodes,
  ) {
    if (nodes.isEmpty) return const SizedBox.shrink();

    final (title, icon, color) = _getTypeInfo(accountType);
    final total = nodes.fold(0.0, (sum, n) => sum + n.subtotal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '¥${total.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Reorderable root accounts
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: nodes.length,
          onReorder: (oldIndex, newIndex) => _handleReorder(nodes, oldIndex, newIndex),
          itemBuilder: (context, index) {
            final node = nodes[index];
            return AccountTreeNodeWidget(
              key: ValueKey(node.account.id),
              node: node,
              depth: 0,
              isExpanded: _expandedNodes[node.account.id] ?? false,
              onExpansionChanged: (expanded) {
                setState(() {
                  _expandedNodes[node.account.id] = expanded;
                });
              },
              onTap: () => _showEditDialog(context, node.account),
              onDelete: () => _deleteAccount(context, node.account),
              onMove: () => _showMoveDialog(context, node.account),
              onAddChild: node.isGroup
                  ? () => _showAddChildDialog(context, node.account)
                  : null,
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _handleReorder(List<AccountTreeNode> nodes, int oldIndex, int newIndex) {
    // Adjust for Flutter's quirk when moving down
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    // Create new order
    final reorderedNodes = List<AccountTreeNode>.from(nodes);
    final movedNode = reorderedNodes.removeAt(oldIndex);
    reorderedNodes.insert(newIndex, movedNode);

    // Get account IDs in new order
    final newOrder = reorderedNodes.map((n) => n.account.id).toList();

    // Persist the reorder
    ref.read(accountNotifierProvider.notifier).reorderAccounts(
      accountIds: newOrder,
      parentId: null,
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无账户',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮添加您的第一个账户',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  (String, IconData, Color) _getTypeInfo(String accountType) {
    switch (accountType) {
      case 'ASSET':
        return ('资产账户', Icons.account_balance_wallet, Colors.green);
      case 'LIABILITY':
        return ('负债账户', Icons.trending_down, Colors.red);
      case 'EQUITY':
        return ('权益账户', Icons.pie_chart, Colors.purple);
      case 'INCOME':
        return ('收入账户', Icons.arrow_upward, Colors.blue);
      case 'EXPENSE':
        return ('支出账户', Icons.arrow_downward, Colors.orange);
      default:
        return ('账户', Icons.folder, Colors.grey);
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'expand_all':
        _expandAll();
        break;
      case 'collapse_all':
        _collapseAll();
        break;
      case 'regenerate_codes':
        _showRegenerateCodesDialog();
        break;
    }
  }

  void _expandAll() {
    final hierarchy = ref.read(accountHierarchyProvider);
    final allIds = <String>[];

    void collectIds(List<AccountTreeNode> nodes) {
      for (final node in nodes) {
        if (node.hasChildren) {
          allIds.add(node.account.id);
          collectIds(node.children);
        }
      }
    }

    for (final nodes in hierarchy.values) {
      collectIds(nodes);
    }

    setState(() {
      for (final id in allIds) {
        _expandedNodes[id] = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已展开所有节点')),
    );
  }

  void _collapseAll() {
    setState(() {
      _expandedNodes.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已折叠所有节点')),
    );
  }

  void _showRegenerateCodesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新生成账户代码'),
        content: const Text('这将根据账户层级位置重新生成所有账户的代码。此操作不可撤销。\n\n确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Get all root accounts and regenerate codes
              final db = ref.read(databaseProvider);
              final rootAccounts = await db.accountsDao.getAll();
              
              // Group by type
              final byType = <String, List<Account>>{};
              for (final acc in rootAccounts) {
                byType.putIfAbsent(acc.accountType, () => []).add(acc);
              }
              
              // Regenerate for each type
              for (final entry in byType.entries) {
                final roots = entry.value.where((a) => a.parentId == null).toList()
                  ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
                
                for (var i = 0; i < roots.length; i++) {
                  final code = await ref.read(accountNotifierProvider.notifier)
                      .generateAccountCode(
                    accountType: entry.key,
                    parentId: null,
                    position: i,
                  );
                  
                  await (db.update(db.accounts)
                    ..where((a) => a.id.equals(roots[i].id))).write(
                    AccountsCompanion(
                      code: drift.Value(code),
                      sortOrder: drift.Value(i),
                      updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
                    ),
                  );
                  
                  // Recursively regenerate for children
                  if (roots[i].isPlaceholder) {
                    await ref.read(accountNotifierProvider.notifier)
                        .regenerateCodesForBranch(roots[i].id);
                  }
                }
              }
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('账户代码已重新生成')),
                );
              }
            },
            child: const Text('生成'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AddAccountDialog(),
    );
  }

  void _showAddChildDialog(BuildContext context, Account parent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddAccountDialog(parentAccount: parent),
    );
  }

  void _showEditDialog(BuildContext context, Account account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddAccountDialog(account: account),
    );
  }

  void _showMoveDialog(BuildContext context, Account account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => MoveAccountDialog(account: account),
    );
  }

  void _deleteAccount(BuildContext context, Account account) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除账户'),
        content: Text('确定要删除账户 "${account.name}" 吗？\n\n注意：如果该账户有子账户，需要先删除子账户。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(accountNotifierProvider.notifier).deleteAccount(account.id);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('账户已删除')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
