import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import 'package:database/database.dart';
import 'package:finance_app/features/journal/data/journal_list_provider.dart';
import 'package:finance_app/features/journal/presentation/widgets/journal_entry_detail_sheet.dart';

/// Journal Entry List Page.
///
/// Displays all journal entries with:
/// - Search by description/entry number
/// - Filter by status (All/Posted/Draft)
/// - Filter by date range
/// - Pull-to-refresh
/// - Tap to view details
/// - FAB to create new entry
class JournalEntryListPage extends ConsumerStatefulWidget {
  const JournalEntryListPage({super.key});

  @override
  ConsumerState<JournalEntryListPage> createState() => _JournalEntryListPageState();
}

class _JournalEntryListPageState extends ConsumerState<JournalEntryListPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  DateTime? _filterFromDate;
  DateTime? _filterToDate;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      ref.read(journalListProvider.notifier).loadInitial();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(journalListProvider.notifier).loadMore();
    }
  }

  void _updateSearchQuery(String query) {
    final currentFilter = ref.read(journalListFilterProvider);
    final newFilter = currentFilter.copyWith(
      searchQuery: query.isEmpty ? null : query,
      clearSearchQuery: query.isEmpty,
    );
    ref.read(journalListFilterProvider.notifier).state = newFilter;
    ref.read(journalListProvider.notifier).updateFilter(newFilter);
  }

  void _updateStatusFilter(JournalEntryStatusFilter status) {
    final currentFilter = ref.read(journalListFilterProvider);
    final newFilter = currentFilter.copyWith(status: status);
    ref.read(journalListFilterProvider.notifier).state = newFilter;
    ref.read(journalListProvider.notifier).updateFilter(newFilter);
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: (_filterFromDate != null && _filterToDate != null)
          ? DateTimeRange(start: _filterFromDate!, end: _filterToDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _filterFromDate = DateTime(
            picked.start.year, picked.start.month, picked.start.day);
        _filterToDate = DateTime(
            picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });

      final currentFilter = ref.read(journalListFilterProvider);
      final newFilter = currentFilter.copyWith(
        fromDate: _filterFromDate,
        toDate: _filterToDate,
      );
      ref.read(journalListFilterProvider.notifier).state = newFilter;
      ref.read(journalListProvider.notifier).updateFilter(newFilter);
    }
  }

  void _clearFilters() {
    setState(() {
      _filterFromDate = null;
      _filterToDate = null;
      _searchController.clear();
    });
    ref.read(journalListFilterProvider.notifier).state = const JournalListFilter();
    ref.read(journalListProvider.notifier).updateFilter(const JournalListFilter());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paginationState = ref.watch(journalListProvider);
    final filter = ref.watch(journalListFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? _buildSearchField(theme)
            : const Text('凭证列表'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _updateSearchQuery('');
                setState(() => _isSearching = false);
              },
            ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _isSearching = true),
            ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.date_range),
              onPressed: _selectDateRange,
              tooltip: '选择日期范围',
            ),
          if (!_isSearching && filter.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              onPressed: _clearFilters,
              tooltip: '清除筛选',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(journalListProvider.notifier).refresh();
        },
        child: _buildBody(context, paginationState, filter),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/journal-entry'),
        icon: const Icon(Icons.add),
        label: const Text('新建凭证'),
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: '搜索凭证号、摘要...',
        border: InputBorder.none,
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      style: theme.textTheme.bodyLarge,
      autofocus: true,
      onChanged: _updateSearchQuery,
    );
  }

  Widget _buildBody(
    BuildContext context,
    JournalListPaginationState paginationState,
    JournalListFilter filter,
  ) {
    return Column(
      children: [
        // Status filter chips
        _buildStatusFilterChips(context, filter),

        // Date range indicator
        if (_filterFromDate != null || _filterToDate != null)
          _buildDateRangeIndicator(context),

        // List content
        Expanded(
          child: paginationState.items.isEmpty && !paginationState.isLoading
              ? _buildEmptyState(context, filter)
              : _buildEntryList(context, paginationState),
        ),
      ],
    );
  }

  Widget _buildStatusFilterChips(BuildContext context, JournalListFilter filter) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildFilterChip(
            context,
            label: '全部',
            isSelected: filter.status == JournalEntryStatusFilter.all,
            onTap: () => _updateStatusFilter(JournalEntryStatusFilter.all),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            context,
            label: '已过账',
            isSelected: filter.status == JournalEntryStatusFilter.posted,
            onTap: () => _updateStatusFilter(JournalEntryStatusFilter.posted),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            context,
            label: '草稿',
            isSelected: filter.status == JournalEntryStatusFilter.draft,
            onTap: () => _updateStatusFilter(JournalEntryStatusFilter.draft),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.onPrimaryContainer,
      labelStyle: TextStyle(
        color: isSelected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
        ),
      ),
    );
  }

  Widget _buildDateRangeIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.date_range,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '${dateFormat.format(_filterFromDate!)} 至 ${dateFormat.format(_filterToDate!)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: () {
              setState(() {
                _filterFromDate = null;
                _filterToDate = null;
              });
              final currentFilter = ref.read(journalListFilterProvider);
              final newFilter = currentFilter.copyWith(
                clearFromDate: true,
                clearToDate: true,
              );
              ref.read(journalListFilterProvider.notifier).state = newFilter;
              ref.read(journalListProvider.notifier).updateFilter(newFilter);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, JournalListFilter filter) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            filter.isNotEmpty ? Icons.search_off : Icons.receipt_long_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            filter.isNotEmpty ? '未找到匹配的凭证' : '暂无凭证记录',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filter.isNotEmpty ? '尝试调整筛选条件' : '点击下方按钮创建新凭证',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          if (filter.isNotEmpty) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _clearFilters,
              child: const Text('清除筛选'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEntryList(
    BuildContext context,
    JournalListPaginationState paginationState,
  ) {
    final itemCount = paginationState.items.length +
        (paginationState.hasMore || paginationState.isLoading ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == paginationState.items.length) {
          return _buildLoadingIndicator(paginationState.isLoading);
        }

        final item = paginationState.items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: JournalEntryCard(
            item: item,
            onTap: () => _showEntryDetail(context, item),
          ),
        );
      },
    );
  }

  Widget _buildLoadingIndicator(bool isLoading) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  void _showEntryDetail(BuildContext context, JournalEntryListItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => JournalEntryDetailSheet(
        entryId: item.entry.id,
        onEdit: item.entry.isPosted
            ? null
            : () {
                Navigator.pop(context);
                context.push('/journal-entry', extra: item.entry.id);
              },
        onPost: item.entry.isPosted
            ? null
            : () async {
                Navigator.pop(context);
                final success = await ref
                    .read(journalListProvider.notifier)
                    .postEntry(item.entry.id);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('凭证已过账'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
        onDelete: item.entry.isPosted
            ? null
            : () async {
                final confirmed = await _confirmDelete(context, item.entry);
                if (confirmed == true && mounted) {
                  Navigator.pop(context);
                  final success = await ref
                      .read(journalListProvider.notifier)
                      .deleteEntry(item.entry.id);
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('凭证已删除'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, JournalEntry entry) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除凭证'),
        content: Text('确定要删除凭证 ${entry.entryNumber} 吗？\n此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
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

/// Card widget for displaying a journal entry summary.
class JournalEntryCard extends StatelessWidget {
  final JournalEntryListItem item;
  final VoidCallback onTap;

  const JournalEntryCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = item.entry;
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Entry number and status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      entry.entryNumber ?? '',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(context, entry.isPosted),
                  const Spacer(),
                  Text(
                    dateFormat.format(DateTime.fromMillisecondsSinceEpoch(entry.postDate)),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Description
              if (entry.description != null && entry.description!.isNotEmpty) ...[
                Text(
                  entry.description!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
              ],

              // Totals row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildAmountColumn(
                      context,
                      label: '借方',
                      amount: item.totalDebits,
                      color: Colors.orange,
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: theme.colorScheme.outlineVariant,
                    ),
                    _buildAmountColumn(
                      context,
                      label: '贷方',
                      amount: item.totalCredits,
                      color: Colors.blue,
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${item.lineCount} 条',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '分录',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, bool isPosted) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPosted
            ? Colors.green.withOpacity(0.15)
            : theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPosted ? Icons.check_circle : Icons.edit_document,
            size: 12,
            color: isPosted
                ? Colors.green
                : theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            isPosted ? '已过账' : '草稿',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isPosted
                  ? Colors.green
                  : theme.colorScheme.onTertiaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountColumn(
    BuildContext context, {
    required String label,
    required double amount,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '¥${amount.toStringAsFixed(2)}',
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
