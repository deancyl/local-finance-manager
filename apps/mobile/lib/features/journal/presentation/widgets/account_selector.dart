import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:database/database.dart';
import 'package:core/core.dart' as domain;
import 'package:finance_app/features/accounts/data/account_provider.dart';

/// Account selector widget for journal entries.
/// 
/// Features:
/// - Hierarchical account tree (expandable)
/// - Filter chips by account type (ASSET/LIABILITY/EQUITY/INCOME/EXPENSE)
/// - Search input
/// - Account balance display (optional)
class AccountSelectorWidget extends ConsumerStatefulWidget {
  final String? selectedAccountId;
  final List<String>? accountTypeFilter;
  final bool showBalances;
  final String title;

  const AccountSelectorWidget({
    super.key,
    this.selectedAccountId,
    this.accountTypeFilter,
    this.showBalances = false,
    this.title = '选择账户',
  });

  /// Shows the account selector as a modal bottom sheet.
  static Future<domain.Account?> show(
    BuildContext context, {
    String? selectedAccountId,
    List<String>? accountTypeFilter,
    bool showBalances = false,
    String title = '选择账户',
  }) async {
    final result = await showModalBottomSheet<Account>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => AccountSelectorWidget(
          selectedAccountId: selectedAccountId,
          accountTypeFilter: accountTypeFilter,
          showBalances: showBalances,
          title: title,
        ),
      ),
    );

    if (result == null) return null;
    return _convertToDomainAccount(result);
  }

  static domain.Account _convertToDomainAccount(Account account) {
    return domain.Account(
      id: account.id,
      name: account.name,
      accountType: domain.AccountType.values.firstWhere(
        (e) => e.code == account.accountType,
        orElse: () => domain.AccountType.asset,
      ),
      parentId: account.parentId,
      commodityId: account.commodityId,
      code: account.code,
      description: account.description,
      isPlaceholder: account.isPlaceholder,
      isHidden: account.isHidden,
      sortOrder: account.sortOrder,
      createdAt: DateTime.fromMillisecondsSinceEpoch(account.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(account.updatedAt),
      version: account.version,
      liquidityType: domain.LiquidityType.values.firstWhere(
        (e) => e.code == account.liquidityType,
        orElse: () => domain.LiquidityType.current,
      ),
    );
  }

  @override
  ConsumerState<AccountSelectorWidget> createState() => _AccountSelectorWidgetState();
}

class _AccountSelectorWidgetState extends ConsumerState<AccountSelectorWidget> {
  final _searchController = TextEditingController();
  final _expandedNodes = <String>{};
  String? _selectedTypeFilter;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(searchQueryProvider.notifier).state = '';
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        _buildHeader(theme),
        _buildSearchBar(theme),
        _buildFilterChips(theme),
        Expanded(child: _buildAccountTree()),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            widget.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索账户...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(searchQueryProvider.notifier).state = '';
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
        ),
        onChanged: (value) {
          ref.read(searchQueryProvider.notifier).state = value;
        },
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    final types = widget.accountTypeFilter ?? 
        ['ASSET', 'LIABILITY', 'EQUITY', 'INCOME', 'EXPENSE'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: const Text('全部'),
              selected: _selectedTypeFilter == null,
              onSelected: (selected) {
                setState(() {
                  _selectedTypeFilter = null;
                  ref.read(selectedAccountTypeFilterProvider.notifier).state = null;
                });
              },
              selectedColor: theme.colorScheme.primaryContainer,
              checkmarkColor: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          ...types.map((type) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(_getTypeLabel(type)),
              avatar: Icon(
                _getTypeIcon(type),
                size: 18,
                color: _getTypeColor(type),
              ),
              selected: _selectedTypeFilter == type,
              onSelected: (selected) {
                setState(() {
                  _selectedTypeFilter = selected ? type : null;
                  ref.read(selectedAccountTypeFilterProvider.notifier).state =
                      selected ? type : null;
                });
              },
              selectedColor: _getTypeColor(type).withOpacity(0.2),
              checkmarkColor: _getTypeColor(type),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildAccountTree() {
    final hierarchy = ref.watch(filteredAccountHierarchyProvider);

    if (hierarchy.isEmpty) {
      return const Center(child: Text('没有找到账户'));
    }

    final types = widget.accountTypeFilter ?? 
        ['ASSET', 'LIABILITY', 'EQUITY', 'INCOME', 'EXPENSE'];

    final displayTypes = _selectedTypeFilter != null 
        ? [_selectedTypeFilter!]
        : types;

    final filteredHierarchy = <String, List<AccountTreeNode>>{};
    for (final type in displayTypes) {
      if (hierarchy.containsKey(type)) {
        filteredHierarchy[type] = hierarchy[type]!;
      }
    }

    if (filteredHierarchy.isEmpty) {
      return const Center(child: Text('没有找到匹配的账户'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: filteredHierarchy.length,
      itemBuilder: (context, index) {
        final type = displayTypes[index];
        final nodes = filteredHierarchy[type];
        if (nodes == null || nodes.isEmpty) return const SizedBox.shrink();

        return _buildTypeSection(type, nodes);
      },
    );
  }

  Widget _buildTypeSection(String type, List<AccountTreeNode> nodes) {
    final theme = Theme.of(context);
    final color = _getTypeColor(type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              Icon(_getTypeIcon(type), size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                _getTypeLabel(type),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        ...nodes.map((node) => _buildAccountNode(node, 0)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildAccountNode(AccountTreeNode node, int depth) {
    final theme = Theme.of(context);
    final color = _getTypeColor(node.account.accountType);
    final indent = depth * 20.0;
    final isSelected = widget.selectedAccountId == node.account.id;

    if (node.isGroup) {
      final isExpanded = _expandedNodes.contains(node.account.id);

      return Padding(
        padding: EdgeInsets.only(left: indent),
        child: Card(
          margin: const EdgeInsets.only(bottom: 2, left: 4, right: 4),
          color: isSelected 
              ? theme.colorScheme.primaryContainer.withOpacity(0.3)
              : null,
          child: ExpansionTile(
            key: PageStorageKey(node.account.id),
            initiallyExpanded: isExpanded,
            onExpansionChanged: (expanded) {
              setState(() {
                if (expanded) {
                  _expandedNodes.add(node.account.id);
                } else {
                  _expandedNodes.remove(node.account.id);
                }
              });
            },
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getGroupIcon(node.account.name),
                color: color,
                size: 18,
              ),
            ),
            title: Text(
              node.account.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: widget.showBalances
                ? Text(
                    '小计: ¥${node.subtotal.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : null,
            trailing: node.account.isPlaceholder
                ? null
                : IconButton(
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    onPressed: () => Navigator.pop(context, node.account),
                    tooltip: '选择此账户',
                  ),
            children: node.children
                .map((child) => _buildAccountNode(child, depth + 1))
                .toList(),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Card(
        margin: const EdgeInsets.only(bottom: 2, left: 4, right: 4),
        color: isSelected 
            ? theme.colorScheme.primaryContainer.withOpacity(0.3)
            : null,
        child: InkWell(
          onTap: () => Navigator.pop(context, node.account),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getAccountIcon(node.account.name),
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.account.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (node.account.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          node.account.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.showBalances)
                  Text(
                    '¥${node.subtotal.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'ASSET': return '资产';
      case 'LIABILITY': return '负债';
      case 'EQUITY': return '权益';
      case 'INCOME': return '收入';
      case 'EXPENSE': return '支出';
      default: return type;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'ASSET': return Icons.account_balance_wallet;
      case 'LIABILITY': return Icons.credit_card;
      case 'EQUITY': return Icons.pie_chart;
      case 'INCOME': return Icons.trending_up;
      case 'EXPENSE': return Icons.shopping_cart;
      default: return Icons.folder;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'ASSET': return Colors.green;
      case 'LIABILITY': return Colors.red;
      case 'EQUITY': return Colors.purple;
      case 'INCOME': return Colors.blue;
      case 'EXPENSE': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _getGroupIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('银行') || lower.contains('bank')) return Icons.account_balance;
    if (lower.contains('现金') || lower.contains('cash')) return Icons.money;
    if (lower.contains('投资') || lower.contains('invest')) return Icons.trending_up;
    if (lower.contains('信用卡') || lower.contains('credit')) return Icons.credit_card;
    if (lower.contains('贷款') || lower.contains('loan')) return Icons.home;
    if (lower.contains('工资') || lower.contains('salary')) return Icons.work;
    if (lower.contains('日常') || lower.contains('daily')) return Icons.shopping_bag;
    if (lower.contains('交通') || lower.contains('transport')) return Icons.directions_car;
    if (lower.contains('娱乐') || lower.contains('entertainment')) return Icons.movie;
    if (lower.contains('医疗') || lower.contains('health')) return Icons.local_hospital;
    return Icons.folder;
  }

  IconData _getAccountIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('支付宝') || lower.contains('alipay')) return Icons.payment;
    if (lower.contains('微信') || lower.contains('wechat')) return Icons.chat;
    if (lower.contains('工商') || lower.contains('icbc')) return Icons.account_balance;
    if (lower.contains('建设') || lower.contains('ccb')) return Icons.account_balance;
    if (lower.contains('中国银行') || lower.contains('boc')) return Icons.account_balance;
    return Icons.account_balance_wallet;
  }
}