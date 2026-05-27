import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:ai/ai.dart';
import 'data/ai_provider.dart';
import '../../transactions/data/transaction_provider.dart';
import '../../categories/data/category_provider.dart';

/// Page for reviewing and applying AI category suggestions.
class AiCategorySuggestionsPage extends ConsumerStatefulWidget {
  const AiCategorySuggestionsPage({super.key});

  @override
  ConsumerState<AiCategorySuggestionsPage> createState() => _AiCategorySuggestionsPageState();
}

class _AiCategorySuggestionsPageState extends ConsumerState<AiCategorySuggestionsPage> {
  List<String> _transactionIds = [];
  Map<String, CategorySuggestion?> _suggestions = {};
  Set<String> _selectedIds = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUncategorizedTransactions();
  }

  Future<void> _loadUncategorizedTransactions() async {
    setState(() => _isLoading = true);

    try {
      final db = ref.read(databaseProvider);
      final transactions = await db.transactionsDao.getUncategorizedTransactions(limit: 50);
      
      setState(() {
        _transactionIds = transactions.map((t) => t.id).toList();
        _selectedIds = {};
      });

      // Get suggestions for all transactions
      if (_transactionIds.isNotEmpty) {
        final suggestions = await ref.read(batchCategorySuggestionsProvider(_transactionIds).future);
        setState(() {
          _suggestions = suggestions;
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds = _suggestions.entries
          .where((e) => e.value != null)
          .map((e) => e.key)
          .toSet();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
    });
  }

  Future<void> _applySelected() async {
    if (_selectedIds.isEmpty) return;

    final toApply = <String, String>{};
    for (final id in _selectedIds) {
      final suggestion = _suggestions[id];
      if (suggestion != null) {
        toApply[id] = suggestion.categoryId;
      }
    }

    await ref.read(categorySuggestionApplierProvider.notifier).applyBatchSuggestions(toApply);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已应用 ${toApply.length} 个分类建议')),
      );
      _loadUncategorizedTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAvailable = ref.watch(aiAvailabilityProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 分类建议'),
        actions: [
          if (_selectedIds.isNotEmpty)
            TextButton.icon(
              onPressed: _applySelected,
              icon: const Icon(Icons.check),
              label: Text('应用 (${_selectedIds.length})'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Status banner
          if (!isAvailable)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(Icons.warning, color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI 服务不可用。请确保 Ollama 正在运行。',
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),

          // Selection controls
          if (_suggestions.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  Text(
                    '${_suggestions.values.where((s) => s != null).length} 个建议',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _selectAll,
                    child: const Text('全选'),
                  ),
                  TextButton(
                    onPressed: _clearSelection,
                    child: const Text('清除'),
                  ),
                ],
              ),
            ),
          ],

          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _loadUncategorizedTransactions,
        icon: const Icon(Icons.refresh),
        label: const Text('刷新'),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_transactionIds.isEmpty) {
      return _buildEmptyState();
    }

    if (_suggestions.isEmpty) {
      return const Center(child: Text('正在获取建议...'));
    }

    return ListView.builder(
      itemCount: _transactionIds.length,
      itemBuilder: (context, index) {
        final id = _transactionIds[index];
        final suggestion = _suggestions[id];
        final isSelected = _selectedIds.contains(id);

        return _SuggestionCard(
          transactionId: id,
          suggestion: suggestion,
          isSelected: isSelected,
          onTap: () => _toggleSelection(id),
          onApply: suggestion != null
              ? () async {
                  await ref.read(categorySuggestionApplierProvider.notifier).applySuggestion(
                        id,
                        suggestion.categoryId,
                      );
                  _loadUncategorizedTransactions();
                }
              : null,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            '所有交易都已分类！',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text('没有待分类的交易需要 AI 建议'),
        ],
      ),
    );
  }
}

/// Card widget for displaying a category suggestion.
class _SuggestionCard extends ConsumerWidget {
  final String transactionId;
  final CategorySuggestion? suggestion;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onApply;

  const _SuggestionCard({
    required this.transactionId,
    required this.suggestion,
    required this.isSelected,
    required this.onTap,
    this.onApply,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final transactionAsync = ref.watch(transactionProvider(transactionId));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Transaction info
              transactionAsync.when(
                data: (transaction) {
                  if (transaction == null) return const Text('未知交易');
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              transaction.description ?? '无描述',
                              style: theme.textTheme.titleSmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('yyyy-MM-dd').format(
                          DateTime.fromMillisecondsSinceEpoch(transaction.postDate),
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  );
                },
                loading: () => const Text('加载中...'),
                error: (e, _) => Text('错误: $e'),
              ),

              const Divider(height: 24),

              // Suggestion
              if (suggestion != null) ...[
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 20, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      'AI 建议:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    _ConfidenceBadge(confidence: suggestion!.confidence),
                  ],
                ),
                const SizedBox(height: 8),
                _CategoryName(categoryId: suggestion!.categoryId),
                if (suggestion!.reasoning != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    suggestion!.reasoning!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onApply,
                      child: const Text('应用'),
                    ),
                  ],
                ),
              ] else
                Text(
                  '无法生成建议',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge showing confidence level.
class _ConfidenceBadge extends StatelessWidget {
  final double confidence;

  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = (confidence * 100).round();
    
    Color color;
    if (confidence >= 0.8) {
      color = Colors.green;
    } else if (confidence >= 0.5) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        '$percentage%',
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

/// Widget showing category name from ID.
class _CategoryName extends ConsumerWidget {
  final String categoryId;

  const _CategoryName({required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return categoriesAsync.when(
      data: (categories) {
        final category = categories.where((c) => c.id == categoryId).firstOrNull;
        if (category == null) {
          return Text('未知分类: $categoryId');
        }
        return Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: category.isIncome ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              category.name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
      loading: () => const Text('加载中...'),
      error: (e, _) => Text('错误: $e'),
    );
  }
}
