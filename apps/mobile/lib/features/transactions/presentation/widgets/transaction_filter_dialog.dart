import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:database/database.dart';
import '../../../accounts/data/account_provider.dart';
import '../../../categories/data/category_provider.dart';
import '../../../tags/data/tag_provider.dart';
import '../../data/transaction_filter.dart';
import '../../data/transaction_provider.dart';

/// Transaction filter dialog with search and filter options.
class TransactionFilterDialog extends ConsumerStatefulWidget {
  const TransactionFilterDialog({super.key});

  @override
  ConsumerState<TransactionFilterDialog> createState() => _TransactionFilterDialogState();
}

class _TransactionFilterDialogState extends ConsumerState<TransactionFilterDialog> {
  final _searchController = TextEditingController();
  final _minAmountController = TextEditingController();
  final _maxAmountController = TextEditingController();
  
  DateTime? _startDate;
  DateTime? _endDate;
  String? _categoryId;
  String? _accountId;
  List<String> _tagIds = [];
  TagFilterLogic _tagFilterLogic = TagFilterLogic.and;
  
  @override
  void initState() {
    super.initState();
    // Initialize with current filter state
    final filter = ref.read(transactionFilterProvider);
    _searchController.text = filter.searchQuery ?? '';
    _startDate = filter.startDate;
    _endDate = filter.endDate;
    _categoryId = filter.categoryId;
    _accountId = filter.accountId;
    _tagIds = filter.tagIds;
    _tagFilterLogic = filter.tagFilterLogic;
    if (filter.minAmount != null) {
      _minAmountController.text = filter.minAmount!.toStringAsFixed(2);
    }
    if (filter.maxAmount != null) {
      _maxAmountController.text = filter.maxAmount!.toStringAsFixed(2);
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final accountsAsync = ref.watch(accountsProvider);
    
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Text(
                  '筛选交易',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Search field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: '搜索',
                hintText: '搜索描述或备注',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            
            // Date range section
            Text(
              '日期范围',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectStartDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '开始日期',
                        prefixIcon: Icon(Icons.calendar_today, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _startDate != null
                            ? DateFormat('yyyy-MM-dd').format(_startDate!)
                            : '选择日期',
                        style: TextStyle(
                          color: _startDate != null
                              ? null
                              : Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectEndDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '结束日期',
                        prefixIcon: Icon(Icons.calendar_today, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _endDate != null
                            ? DateFormat('yyyy-MM-dd').format(_endDate!)
                            : '选择日期',
                        style: TextStyle(
                          color: _endDate != null
                              ? null
                              : Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Category dropdown
            categoriesAsync.when(
              data: (categories) {
                final expenseCategories = categories.where((c) => !c.isIncome).toList();
                return DropdownButtonFormField<String>(
                  value: _categoryId,
                  decoration: const InputDecoration(
                    labelText: '分类',
                    prefixIcon: Icon(Icons.category_outlined),
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('全部分类'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('全部分类')),
                    ...expenseCategories.map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() => _categoryId = value);
                  },
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            
            // Account dropdown
            accountsAsync.when(
              data: (accounts) {
                return DropdownButtonFormField<String>(
                  value: _accountId,
                  decoration: const InputDecoration(
                    labelText: '账户',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('全部账户'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('全部账户')),
                    ...accounts.map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text(a.name),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() => _accountId = value);
                  },
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            
            // Amount range section
            Text(
              '金额范围',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minAmountController,
                    decoration: const InputDecoration(
                      labelText: '最小金额',
                      prefixText: '¥ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _maxAmountController,
                    decoration: const InputDecoration(
                      labelText: '最大金额',
                      prefixText: '¥ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Tag filter section
            _buildTagFilterSection(context, categoriesAsync),
            const SizedBox(height: 24),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _hasFilters() ? _clearFilters : null,
                    child: const Text('清除筛选'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _applyFilters(context),
                    child: const Text('应用'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  bool _hasFilters() {
    return _searchController.text.isNotEmpty ||
        _startDate != null ||
        _endDate != null ||
        _categoryId != null ||
        _accountId != null ||
        _minAmountController.text.isNotEmpty ||
        _maxAmountController.text.isNotEmpty ||
        _tagIds.isNotEmpty;
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _startDate = date);
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _endDate = date);
    }
  }

  Widget _buildTagFilterSection(BuildContext context, AsyncValue<List<Category>> categoriesAsync) {
    final allTagsAsync = ref.watch(allTagsProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '标签筛选',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        
        // AND/OR logic toggle
        Row(
          children: [
            Text(
              '筛选逻辑: ',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SegmentedButton<TagFilterLogic>(
              segments: const [
                ButtonSegment<TagFilterLogic>(
                  value: TagFilterLogic.and,
                  label: Text('AND'),
                  icon: Icon(Icons.check_circle_outline),
                ),
                ButtonSegment<TagFilterLogic>(
                  value: TagFilterLogic.or,
                  label: Text('OR'),
                  icon: Icon(Icons.library_add_check_outlined),
                ),
              ],
              selected: {_tagFilterLogic},
              onSelectionChanged: (Set<TagFilterLogic> newSelection) {
                setState(() => _tagFilterLogic = newSelection.first);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Tag chips
        allTagsAsync.when(
          data: (tags) {
            if (tags.isEmpty) {
              return const Text('暂无可用标签');
            }
            
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) => _buildTagFilterChip(tag)).toList(),
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (error, _) => Text('加载标签失败: $error'),
        ),
        
        if (_tagIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '已选择 ${_tagIds.length} 个标签 (${_tagFilterLogic == TagFilterLogic.and ? "必须全部匹配" : "匹配任意一个"})',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTagFilterChip(Tag tag) {
    final isSelected = _tagIds.contains(tag.id);
    final color = _parseColor(tag.color);
    
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text('#${tag.name}'),
          if (tag.usageCount > 0) ...[
            const SizedBox(width: 4),
            Text(
              '(${tag.usageCount})',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _tagIds.add(tag.id);
          } else {
            _tagIds.remove(tag.id);
          }
        });
      },
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      side: BorderSide(color: isSelected ? color : Theme.of(context).colorScheme.outline),
    );
  }

  Color _parseColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  void _clearFilters() {
    _searchController.clear();
    _minAmountController.clear();
    _maxAmountController.clear();
    setState(() {
      _startDate = null;
      _endDate = null;
      _categoryId = null;
      _accountId = null;
      _tagIds = [];
      _tagFilterLogic = TagFilterLogic.and;
    });
  }

  void _applyFilters(BuildContext context) {
    final filter = TransactionFilter(
      searchQuery: _searchController.text.isEmpty ? null : _searchController.text,
      startDate: _startDate,
      endDate: _endDate,
      categoryId: _categoryId,
      accountId: _accountId,
      minAmount: _minAmountController.text.isEmpty 
          ? null 
          : double.tryParse(_minAmountController.text),
      maxAmount: _maxAmountController.text.isEmpty 
          ? null 
          : double.tryParse(_maxAmountController.text),
      tagIds: _tagIds,
      tagFilterLogic: _tagFilterLogic,
    );
    
    ref.read(transactionFilterProvider.notifier).setFilter(filter);
    Navigator.pop(context);
  }
}
