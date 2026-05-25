import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:core/core.dart' hide Transaction, Split;
import 'package:database/database.dart';
import 'package:finance_app/features/transactions/presentation/widgets/transaction_card.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

/// Filter class for advanced search (placeholder)
class TransactionFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? categoryId;
  final String? accountId;
  final double? minAmount;
  final double? maxAmount;
  final String? searchQuery;

  const TransactionFilter({
    this.startDate,
    this.endDate,
    this.categoryId,
    this.accountId,
    this.minAmount,
    this.maxAmount,
    this.searchQuery,
  });
}

/// Advanced Search Page with FTS5 full-text search and saved search presets.
class AdvancedSearchPage extends ConsumerStatefulWidget {
  final TransactionFilter? initialFilter;

  const AdvancedSearchPage({super.key, this.initialFilter});

  @override
  ConsumerState<AdvancedSearchPage> createState() => _AdvancedSearchPageState();
}

class _AdvancedSearchPageState extends ConsumerState<AdvancedSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Filter state
  DateTime? _startDate;
  DateTime? _endDate;
  String? _categoryId;
  String? _accountId;
  double? _minAmount;
  double? _maxAmount;
  List<String> _selectedTagIds = [];
  
  // Search state
  List<(Transaction, List<Split>)> _results = [];
  List<SavedSearch> _savedSearches = [];
  List<SearchHistoryEntry> _searchHistory = [];
  bool _isLoading = false;
  bool _showFilters = false;
  String? _lastQuery;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    if (widget.initialFilter != null) {
      _startDate = widget.initialFilter!.startDate;
      _endDate = widget.initialFilter!.endDate;
      _categoryId = widget.initialFilter!.categoryId;
      _accountId = widget.initialFilter!.accountId;
      _minAmount = widget.initialFilter!.minAmount;
      _maxAmount = widget.initialFilter!.maxAmount;
      _searchController.text = widget.initialFilter!.searchQuery ?? '';
    }
    
    _loadSavedSearches();
    _loadSearchHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreResults();
    }
  }

  Future<void> _loadSavedSearches() async {
    // SavedSearchDao was removed - saved searches feature disabled
    // final db = ref.read(databaseProvider);
    // final searches = await db.savedSearchDao.getAll();
    setState(() => _savedSearches = []);
  }

  Future<void> _loadSearchHistory() async {
    // SavedSearchDao was removed - search history feature disabled
    // final db = ref.read(databaseProvider);
    // final history = await db.savedSearchDao.getRecentHistory(limit: 10);
    setState(() => _searchHistory = []);
  }

  Future<void> _performSearch({bool loadMore = false}) async {
    final query = _searchController.text.trim();
    
    if (query.isEmpty && _hasNoFilters()) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = ref.read(databaseProvider);
      
      if (query.isNotEmpty) {
        // SavedSearchDao was removed - search history feature disabled
        // await db.savedSearchDao.addToHistory(query);
        // _loadSearchHistory();
      }

      // Use FTS5 for full-text search
      final results = await db.transactionsDao.advancedFullTextSearch(
        query: query.isEmpty ? '*' : query,
        limit: 20,
        offset: loadMore ? _results.length : 0,
        startDate: _startDate,
        endDate: _endDate,
        categoryId: _categoryId,
        accountId: _accountId,
        minAmount: _minAmount,
        maxAmount: _maxAmount,
        tagIds: _selectedTagIds.isEmpty ? null : _selectedTagIds,
      );

      setState(() {
        if (loadMore) {
          _results.addAll(results);
        } else {
          _results = results;
        }
        _lastQuery = query;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreResults() async {
    if (_isLoading || _lastQuery == null) return;
    await _performSearch(loadMore: true);
  }

  bool _hasNoFilters() {
    return _startDate == null &&
        _endDate == null &&
        _categoryId == null &&
        _accountId == null &&
        _minAmount == null &&
        _maxAmount == null &&
        _selectedTagIds.isEmpty;
  }

  Future<void> _saveSearch() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存搜索'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '名称 *',
                hintText: '例如：本月餐饮支出',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: '描述',
                hintText: '可选备注',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (shouldSave == true) {
      final search = SavedSearch.create(
        name: nameController.text,
        description: descriptionController.text.isEmpty 
            ? null 
            : descriptionController.text,
        startDate: _startDate,
        endDate: _endDate,
        categoryId: _categoryId,
        accountId: _accountId,
        searchQuery: _searchController.text.isEmpty 
            ? null 
            : _searchController.text,
        minAmount: _minAmount,
        maxAmount: _maxAmount,
        tagIds: _selectedTagIds,
      );

      final db = ref.read(databaseProvider);
      // SavedSearchDao was removed - saved search feature disabled
      // await db.savedSearchDao.create(search);
      // _loadSavedSearches();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('搜索已保存')),
        );
      }
    }
  }

  void _applySavedSearch(SavedSearch search) async {
    // SavedSearchDao was removed - use count tracking disabled
    // final db = ref.read(databaseProvider);
    // await db.savedSearchDao.incrementUseCount(search.id);
    
    setState(() {
      _searchController.text = search.searchQuery ?? '';
      _startDate = search.startDate;
      _endDate = search.endDate;
      _categoryId = search.categoryId;
      _accountId = search.accountId;
      _minAmount = search.minAmount;
      _maxAmount = search.maxAmount;
      _selectedTagIds = search.tagIds;
    });

    _performSearch();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _startDate = null;
      _endDate = null;
      _categoryId = null;
      _accountId = null;
      _minAmount = null;
      _maxAmount = null;
      _selectedTagIds = [];
      _results = [];
    });
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('高级搜索'),
        actions: [
          if (_results.isNotEmpty || _searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.save_outlined),
              onPressed: _saveSearch,
              tooltip: '保存搜索',
            ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearFilters,
            tooltip: '清除筛选',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_showFilters) _buildFilterSection(),
          if (_savedSearches.isNotEmpty || _searchHistory.isNotEmpty)
            _buildQuickAccess(),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索交易描述、备注、参考号...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _results = []);
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            onSubmitted: (_) => _performSearch(),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _showFilters = !_showFilters),
                icon: Icon(_showFilters ? Icons.expand_less : Icons.filter_list),
                label: Text(_showFilters ? '隐藏筛选' : '显示筛选'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _isLoading ? null : () => _performSearch(),
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: const Text('搜索'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          // Date range
          ListTile(
            leading: const Icon(Icons.date_range),
            title: Text(
              _startDate != null && _endDate != null
                  ? '${DateFormat('MM/dd').format(_startDate!)} - ${DateFormat('MM/dd').format(_endDate!)}'
                  : '日期范围',
            ),
            trailing: _startDate != null
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      _startDate = null;
                      _endDate = null;
                    }),
                  )
                : null,
            onTap: _selectDateRange,
          ),
          // Category and Account filters
          Row(
            children: [
              Expanded(
                child: _buildFilterChip(
                  icon: Icons.category,
                  label: '分类',
                  value: _categoryId,
                  onTap: () => _showCategoryPicker(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterChip(
                  icon: Icons.account_balance,
                  label: '账户',
                  value: _accountId,
                  onTap: () => _showAccountPicker(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Amount range
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: '最小金额',
                    prefixText: '¥',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    _minAmount = double.tryParse(value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: '最大金额',
                    prefixText: '¥',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    _maxAmount = double.tryParse(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required String? value,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(value != null ? '已选择' : label),
      onPressed: onTap,
    );
  }

  Future<void> _showCategoryPicker() async {
    final db = ref.read(databaseProvider);
    final categories = await db.categoriesDao.getAll();

    if (!mounted) return;

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择分类'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                title: Text(category.name),
                selected: category.id == _categoryId,
                onTap: () => Navigator.pop(context, category.id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (selected != null) {
      setState(() => _categoryId = selected.isEmpty ? null : selected);
    }
  }

  Future<void> _showAccountPicker() async {
    final db = ref.read(databaseProvider);
    final accounts = await db.accountsDao.getAll();

    if (!mounted) return;

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择账户'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return ListTile(
                title: Text(account.name),
                selected: account.id == _accountId,
                onTap: () => Navigator.pop(context, account.id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (selected != null) {
      setState(() => _accountId = selected.isEmpty ? null : selected);
    }
  }

  Widget _buildQuickAccess() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_savedSearches.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '已保存的搜索',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _savedSearches.length,
                itemBuilder: (context, index) {
                  final search = _savedSearches[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(search.name),
                      avatar: Icon(
                        search.isFavorite ? Icons.star : Icons.bookmark_border,
                        size: 18,
                      ),
                      onSelected: (_) => _applySavedSearch(search),
                    ),
                  );
                },
              ),
            ),
          ] else if (_searchHistory.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '最近搜索',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _searchHistory.length,
                itemBuilder: (context, index) {
                  final entry = _searchHistory[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                      label: Text(entry.query),
                      onPressed: () {
                        _searchController.text = entry.query;
                        _performSearch();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results.isEmpty) {
      if (_searchController.text.isEmpty && _hasNoFilters()) {
        return _buildEmptyState();
      }
      return _buildNoResultsState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _results.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _results.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final (transaction, splits) = _results[index];
        return TransactionCard(
          transaction: transaction,
          onTap: () {
            // Navigate to transaction detail
          },
          onDelete: () {
            // Delete transaction - feature disabled in search results
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '输入关键词开始搜索',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '支持搜索交易描述、备注和参考号',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
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
            '未找到匹配的交易',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '尝试调整搜索条件',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}
