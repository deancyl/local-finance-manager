import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import 'dart:typed_data';

import 'package:database/database.dart';
import 'package:finance_app/features/voice/presentation/widgets/voice_input_button.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';
import '../../../../core/presentation/widgets/gesture_controls.dart';
import '../../../../core/presentation/widgets/undo_snackbar.dart';
import '../../data/transaction_provider.dart';
import '../../data/transaction_filter.dart';
import '../widgets/transaction_card.dart';
import '../widgets/add_transaction_dialog.dart';
import '../widgets/transfer_dialog.dart';
import '../widgets/transaction_filter_dialog.dart';
import '../../../print/data/print_service.dart';
import '../../../print/data/print_provider.dart';
import '../../../export/data/export_service.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  final TransactionFilter? initialFilter;
  
  const TransactionsPage({super.key, this.initialFilter});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  TransactionFilter? _lastFilter;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Apply initial filter if provided
    if (widget.initialFilter != null) {
      Future.microtask(() {
        ref.read(transactionFilterProvider.notifier).state = widget.initialFilter!;
      });
    }
    
    // Load initial data
    Future.microtask(() {
      ref.read(filteredPaginatedTransactionsProvider.notifier).loadInitial();
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
      // Load more when within 200 pixels of bottom
      ref.read(filteredPaginatedTransactionsProvider.notifier).loadMore();
    }
  }

  void _updateSearchQuery(String query) {
    final currentFilter = ref.read(transactionFilterProvider);
    final newFilter = currentFilter.copyWith(
      searchQuery: query.isEmpty ? null : query,
      clearSearchQuery: query.isEmpty,
    );
    ref.read(transactionFilterProvider.notifier).state = newFilter;
  }

  @override
  Widget build(BuildContext context) {
    final paginationState = ref.watch(filteredPaginatedTransactionsProvider);
    final filter = ref.watch(transactionFilterProvider);

    // Reset pagination when filter changes
    if (_lastFilter != null && _lastFilter != filter) {
      Future.microtask(() {
        ref.read(filteredPaginatedTransactionsProvider.notifier).updateFilter(filter);
      });
    }
    _lastFilter = filter;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching 
            ? TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索交易...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                style: Theme.of(context).textTheme.bodyLarge,
                autofocus: true,
                onChanged: (query) {
                  _updateSearchQuery(query);
                },
              )
            : const Text('交易记录'),
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
              onPressed: () {
                setState(() => _isSearching = true);
              },
            ),
          if (!_isSearching)
            VoiceInputButton(
              controller: _searchController,
              mode: VoiceInputMode.search,
              showLocaleSelector: true,
              hint: '说出要搜索的内容',
              onStart: () {
                setState(() => _isSearching = true);
              },
              onResult: (text) {
                _updateSearchQuery(text);
              },
            ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: _handlePrint,
              tooltip: '打印',
            ),
          if (!_isSearching)
            _buildFilterButton(context, filter),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(filteredPaginatedTransactionsProvider.notifier).refresh();
        },
        child: _buildBody(context, paginationState, filter),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOptions(context),
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PaginationState paginationState,
    TransactionFilter filter,
  ) {
    if (paginationState.items.isEmpty && !paginationState.isLoading) {
      if (filter.isNotEmpty) {
        return _buildNoResultsState(context);
      }
      return _buildEmptyState(context);
    }

    return _buildTransactionList(context, paginationState);
  }

  Widget _buildFilterButton(BuildContext context, TransactionFilter filter) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: () => _showFilterDialog(context),
        ),
        if (filter.isNotEmpty)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无交易记录',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮开始记账',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
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
            '未找到符合条件的交易',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '尝试调整筛选条件',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () {
              ref.read(transactionFilterProvider.notifier).state = const TransactionFilter();
            },
            child: const Text('清除筛选'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const TransactionFilterDialog(),
    );
  }

  void _handlePrint() async {
    final filter = ref.read(transactionFilterProvider);

    await PrintService.showPreview(
      context: context,
      title: '交易记录 - 打印预览',
      onLayout: (setup) async {
        final pdfService = ref.read(pdfExportServiceProvider);
        final exportFilters = ExportFilters(
          startDate: filter.startDate,
          endDate: filter.endDate,
          categoryId: filter.categoryId,
          accountId: filter.accountId,
        );
        final result = await pdfService.exportToPDF(filters: exportFilters);
        return result.bytes ?? Uint8List(0);
      },
    );
  }

  Widget _buildTransactionList(BuildContext context, PaginationState paginationState) {
    final transactions = paginationState.items.map((t) => t.$1).toList();
    final splitsMap = Map<String, List<Split>.fromEntries(
      paginationState.items.map((t) => MapEntry(t.$1.id, t.$2)),
    );
    final grouped = _groupByDate(transactions);
    final itemCount = grouped.length + (paginationState.hasMore || paginationState.isLoading ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Show loading indicator at the bottom
        if (index == grouped.length) {
          return _buildLoadingIndicator(paginationState.isLoading);
        }

        final entry = grouped.entries.elementAt(index);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _formatDateHeader(entry.key),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            ...entry.value.map((transaction) => TransactionCard(
                  transaction: transaction,
                  splits: splitsMap[transaction.id],
                  onTap: () => _showEditDialog(context, transaction),
                  onDelete: () => _deleteTransaction(context, transaction),
                  onEdit: () => _showEditDialog(context, transaction),
                  onDuplicate: () => _duplicateTransaction(context, transaction),
                  onCategorize: () => _categorizeTransaction(context, transaction),
                  onAddNote: () => _addNoteToTransaction(context, transaction),
                  onArchive: () => _archiveTransaction(context, transaction),
                )),
            const SizedBox(height: 8),
          ],
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

  Map<DateTime, List<Transaction>> _groupByDate(List<Transaction> transactions) {
    final grouped = <DateTime, List<Transaction>>{};
    for (final transaction in transactions) {
      final date = DateTime.fromMillisecondsSinceEpoch(transaction.postDate);
      final dateKey = DateTime(date.year, date.month, date.day);
      grouped.putIfAbsent(dateKey, () => []).add(transaction);
    }
    return grouped;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) return '今天';
    if (date == yesterday) return '昨天';
    return DateFormat('MM月dd日', 'zh_CN').format(date);
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('记一笔'),
              subtitle: const Text('收入或支出'),
              onTap: () {
                Navigator.pop(context);
                _showAddDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('账户转账'),
              subtitle: const Text('账户间转账'),
              onTap: () {
                Navigator.pop(context);
                _showTransferDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AddTransactionDialog(),
    );
  }

  void _showTransferDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const TransferDialog(),
    );
  }

  void _showEditDialog(BuildContext context, Transaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddTransactionDialog(transaction: transaction),
    );
  }

  void _deleteTransaction(BuildContext context, Transaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除交易'),
        content: const Text('确定要删除这条交易记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Delete with undo capability
              final undoAction = await ref
                  .read(transactionNotifierProvider.notifier)
                  .deleteTransactionWithUndo(transaction.id);
              
              if (undoAction != null && context.mounted) {
                // Show undo snackbar with 5-second timeout
                showUndoSnackBar(
                  context: context,
                  message: '交易已删除',
                  onUndo: () async {
                    final success = await ref
                        .read(transactionNotifierProvider.notifier)
                        .undoDelete();
                    
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('交易已恢复')),
                      );
                    }
                  },
                );
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _duplicateTransaction(BuildContext context, Transaction transaction) {
    // Create a duplicate transaction with current timestamp
    // Note: Transaction uses id (String), currencyId, and other fields
    // The duplicate will be created via AddTransactionDialog with the original data
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddTransactionDialog(
        // Pass original transaction data for duplication
        isDuplicate: true,
        originalDescription: transaction.description,
        originalNotes: transaction.notes,
        originalCurrencyId: transaction.currencyId,
      ),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('交易已复制')),
    );
  }

  void _categorizeTransaction(BuildContext context, Transaction transaction) {
    // Show category selection dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择分类'),
        content: const Text('分类功能开发中...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _addNoteToTransaction(BuildContext context, Transaction transaction) {
    final noteController = TextEditingController(text: transaction.notes ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加备注'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            hintText: '输入备注内容',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              // Update transaction notes
              final db = ref.read(databaseProvider);
              final query = db.select(db.splits)
                  ..where((s) => s.transactionId.equals(transaction.id));
              final splits = await query.get();
              
              if (splits.isNotEmpty) {
                final updatedSplit = splits.first.copyWith(
                  memo: drift.Value(noteController.text.isNotEmpty ? noteController.text : null),
                );
                await ref.read(transactionNotifierProvider.notifier).updateTransaction(
                  transaction,
                  updatedSplit,
                );
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('备注已添加')),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _archiveTransaction(BuildContext context, Transaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('归档交易'),
        content: const Text('确定要归档这条交易记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              // Archive functionality placeholder
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('交易已归档')),
              );
            },
            child: const Text('归档'),
          ),
        ],
      ),
    );
  }
}