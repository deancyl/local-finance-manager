import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:database/database.dart';
import '../../data/account_provider.dart';
import '../widgets/account_tree_card.dart';
import '../widgets/add_account_dialog.dart';
import '../widgets/move_account_dialog.dart';

class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  bool _isSearchExpanded = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final Map<String, bool> _expandedGroups = {};

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final hierarchy = ref.watch(filteredAccountHierarchyProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final typeFilter = ref.watch(selectedAccountTypeFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearchExpanded
            ? _buildSearchField()
            : const Text('账户管理'),
        actions: [
          IconButton(
            icon: Icon(_isSearchExpanded ? Icons.close : Icons.search),
            onPressed: () => _toggleSearch(),
          ),
          IconButton(
            icon: const Icon(Icons.account_tree),
            tooltip: '层级视图',
            onPressed: () => context.go('/accounts/hierarchy'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips row
          _buildFilterChips(typeFilter),
          // Account list
          Expanded(
            child: accountsAsync.when(
              data: (accounts) {
                if (accounts.isEmpty) {
                  return _buildEmptyState(context);
                }
                if (hierarchy.isEmpty && (searchQuery.isNotEmpty || typeFilter != null)) {
                  return _buildNoResultsState(context);
                }
                return _buildAccountTree(context, ref, hierarchy);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('错误: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
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
      }
    });
  }

  Widget _buildFilterChips(String? typeFilter) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip(
            label: '全部',
            isSelected: typeFilter == null,
            onTap: () => ref.read(selectedAccountTypeFilterProvider.notifier).state = null,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: '资产',
            icon: Icons.trending_up,
            color: Colors.green,
            isSelected: typeFilter == 'ASSET',
            onTap: () => ref.read(selectedAccountTypeFilterProvider.notifier).state = 'ASSET',
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: '负债',
            icon: Icons.trending_down,
            color: Colors.red,
            isSelected: typeFilter == 'LIABILITY',
            onTap: () => ref.read(selectedAccountTypeFilterProvider.notifier).state = 'LIABILITY',
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: '收入',
            icon: Icons.arrow_upward,
            color: Colors.blue,
            isSelected: typeFilter == 'INCOME',
            onTap: () => ref.read(selectedAccountTypeFilterProvider.notifier).state = 'INCOME',
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: '支出',
            icon: Icons.arrow_downward,
            color: Colors.orange,
            isSelected: typeFilter == 'EXPENSE',
            onTap: () => ref.read(selectedAccountTypeFilterProvider.notifier).state = 'EXPENSE',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
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

  Widget _buildNoResultsState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '未找到匹配的账户',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '尝试调整搜索条件或筛选器',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
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
            '点击右下角按钮添加账户',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTree(BuildContext context, WidgetRef ref, Map<String, List<AccountTreeNode>> hierarchy) {
    // Build sections for each account type
    final sections = <Widget>[];
    
    // ASSET section with reorderable root accounts
    if (hierarchy['ASSET']?.isNotEmpty ?? false) {
      sections.add(
        _buildTypeHeader(
          context, 
          '资产账户', 
          Icons.trending_up, 
          Colors.green,
          hierarchy['ASSET']!.fold(0.0, (sum, n) => sum + n.subtotal),
        ),
      );
      sections.add(
        _buildReorderableSection(
          context,
          ref,
          hierarchy['ASSET']!,
          'ASSET',
        ),
      );
      sections.add(const SizedBox(height: 24));
    }
    
    // LIABILITY section
    if (hierarchy['LIABILITY']?.isNotEmpty ?? false) {
      sections.add(
        _buildTypeHeader(
          context, 
          '负债账户', 
          Icons.trending_down, 
          Colors.red,
          hierarchy['LIABILITY']!.fold(0.0, (sum, n) => sum + n.subtotal),
        ),
      );
      sections.add(
        _buildReorderableSection(
          context,
          ref,
          hierarchy['LIABILITY']!,
          'LIABILITY',
        ),
      );
      sections.add(const SizedBox(height: 24));
    }
    
    // INCOME section
    if (hierarchy['INCOME']?.isNotEmpty ?? false) {
      sections.add(
        _buildTypeHeader(
          context, 
          '收入账户', 
          Icons.arrow_upward, 
          Colors.blue,
          hierarchy['INCOME']!.fold(0.0, (sum, n) => sum + n.subtotal),
        ),
      );
      sections.add(
        _buildReorderableSection(
          context,
          ref,
          hierarchy['INCOME']!,
          'INCOME',
        ),
      );
      sections.add(const SizedBox(height: 24));
    }
    
    // EXPENSE section
    if (hierarchy['EXPENSE']?.isNotEmpty ?? false) {
      sections.add(
        _buildTypeHeader(
          context, 
          '支出账户', 
          Icons.arrow_downward, 
          Colors.orange,
          hierarchy['EXPENSE']!.fold(0.0, (sum, n) => sum + n.subtotal),
        ),
      );
      sections.add(
        _buildReorderableSection(
          context,
          ref,
          hierarchy['EXPENSE']!,
          'EXPENSE',
        ),
      );
    }
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: sections,
    );
  }

  /// Builds a reorderable section for root accounts of a specific type.
  Widget _buildReorderableSection(
    BuildContext context,
    WidgetRef ref,
    List<AccountTreeNode> nodes,
    String accountType,
  ) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: nodes.length,
      onReorder: (oldIndex, newIndex) {
        _handleRootReorder(ref, nodes, accountType, oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final node = nodes[index];
        return AccountTreeCard(
          key: ValueKey(node.account.id),
          node: node,
          onTap: () => _showEditDialogWithMenu(context, ref, node.account),
          onDelete: () => _deleteAccount(context, ref, node.account),
          onAddChild: node.isGroup 
              ? () => _showAddChildDialog(context, node.account)
              : null,
          isExpanded: _expandedGroups[node.account.id] ?? false,
          onExpansionChanged: (expanded) {
            setState(() {
              _expandedGroups[node.account.id] = expanded;
            });
          },
          enableReordering: true,
        );
      },
      proxyDecorator: (widget, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final animValue = Curves.easeInOut.transform(animation.value);
            final elevation = 1 + animValue * 8;
            final scale = 1 + animValue * 0.05;
            return Transform.scale(
              scale: scale,
              child: Material(
                elevation: elevation,
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).cardColor,
                child: widget,
              ),
            );
          },
          child: widget,
        );
      },
    );
  }

  /// Handles reorder of root accounts within a type.
  void _handleRootReorder(
    WidgetRef ref,
    List<AccountTreeNode> nodes,
    String accountType,
    int oldIndex,
    int newIndex,
  ) {
    // Adjust newIndex if moving down (Flutter's quirk)
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final reorderedNodes = List<AccountTreeNode>.from(nodes);
    final movedNode = reorderedNodes.removeAt(oldIndex);
    reorderedNodes.insert(newIndex, movedNode);

    // Get the new order of account IDs
    final newOrder = reorderedNodes.map((n) => n.account.id).toList();

    // Call reorderAccounts on the notifier
    ref.read(accountNotifierProvider.notifier).reorderAccounts(
      accountIds: newOrder,
      parentId: null, // Root accounts have no parent
    );
  }

  Widget _buildTypeHeader(
    BuildContext context, 
    String title, 
    IconData icon, 
    Color color,
    double total,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '¥${total.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddChildDialog(BuildContext context, Account parent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddAccountDialog(parentAccount: parent),
    );
  }

  void _showAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AddAccountDialog(),
    );
  }

  /// Shows edit dialog with context menu for additional actions.
  void _showEditDialogWithMenu(BuildContext context, WidgetRef ref, Account account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddAccountDialog(account: account),
    );
  }

  /// Shows context menu for account actions.
  void _showContextMenu(BuildContext context, WidgetRef ref, Account account) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑'),
              onTap: () {
                Navigator.pop(context);
                _showEditDialogWithMenu(context, ref, account);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('移动到...'),
              onTap: () {
                Navigator.pop(context);
                _showMoveDialog(context, ref, account);
              },
            ),
            if (account.isPlaceholder)
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('添加子账户'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddChildDialog(context, account);
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              title: Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                _deleteAccount(context, ref, account);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Shows dialog to move account to a new parent.
  void _showMoveDialog(BuildContext context, WidgetRef ref, Account account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => MoveAccountDialog(account: account),
    );
  }

  void _deleteAccount(BuildContext context, WidgetRef ref, Account account) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除账户'),
        content: Text('确定要删除账户 "${account.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(accountNotifierProvider.notifier).deleteAccount(account.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('账户已删除')),
              );
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// AnimatedBuilder helper for proxy decorator
class AnimatedBuilder extends AnimatedWidget {
  final Widget child;
  final Widget Function(BuildContext context, Widget? child) builder;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    required this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}