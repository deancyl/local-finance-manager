import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/batch_entry_provider.dart';
import '../../accounts/data/account_provider.dart';
import '../../categories/data/category_provider.dart';
import '../../transactions/presentation/widgets/quick_amount_input.dart';

/// Batch entry page for entering multiple transactions quickly
/// Optimized for rapid data entry with minimal UI transitions
class BatchEntryPage extends ConsumerStatefulWidget {
  const BatchEntryPage({super.key});

  @override
  ConsumerState<BatchEntryPage> createState() => _BatchEntryPageState();
}

class _BatchEntryPageState extends ConsumerState<BatchEntryPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(batchEntryProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final categories = ref.watch(expenseCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('批量记账'),
        actions: [
          // Draft indicator
          if (state.pendingEntries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Badge(
                label: Text('${state.pendingEntries.length}'),
                child: const Icon(Icons.pending_actions),
              ),
            ),
          // Submit all button
          IconButton(
            onPressed: state.pendingEntries.isNotEmpty
                ? () async {
                    final count = await ref.read(batchEntryProvider.notifier).submitAll();
                    if (count > 0 && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已提交 $count 条交易')),
                      );
                      // Stay on page for more entries
                    }
                  }
                : null,
            icon: const Icon(Icons.send),
            tooltip: '提交所有',
          ),
        ],
      ),
      body: Column(
        children: [
          // Current entry form
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Quick entry form
                _buildEntryForm(context, ref, state, accountsAsync, categories),
              ],
            ),
          ),

          // Pending entries list
          if (state.pendingEntries.isNotEmpty)
            _buildPendingEntriesPanel(context, ref, state),
        ],
      ),
    );
  }

  Widget _buildEntryForm(
    BuildContext context,
    WidgetRef ref,
    BatchEntryState state,
    AsyncValue accountsAsync,
    List categories,
  ) {
    final currentEntry = state.currentEntry;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '第 ${state.pendingEntries.length + 1} 条',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 16),

            // Amount
            QuickAmountInput(
              controller: TextEditingController(text: currentEntry.amount?.toString() ?? ''),
              enableQuickAmounts: true,
              quickAmounts: [10, 20, 50, 100, 200, 500],
              onChanged: (value) {
                final amount = double.tryParse(value);
                ref.read(batchEntryProvider.notifier).updateAmount(amount);
              },
            ),
            const SizedBox(height: 16),

            // Account selector
            accountsAsync.when(
              data: (accounts) => DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: '账户',
                  border: OutlineInputBorder(),
                ),
                value: currentEntry.accountId,
                items: accounts
                    .where((a) => !a.isPlaceholder)
                    .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name),
                        ))
                    .toList(),
                onChanged: (v) => ref.read(batchEntryProvider.notifier).updateAccount(v),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('加载账户失败'),
            ),
            const SizedBox(height: 16),

            // Category selector
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '分类',
                border: OutlineInputBorder(),
              ),
              value: currentEntry.categoryId,
              items: categories
                  .map((c) => DropdownMenuItem<String>(
                        value: c.id,
                        child: Row(
                          children: [
                            Icon(_getCategoryIcon(c.icon), size: 20),
                            const SizedBox(width: 8),
                            Text(c.name),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) => ref.read(batchEntryProvider.notifier).updateCategory(v),
            ),
            const SizedBox(height: 16),

            // Description (with auto-complete suggestions)
            TextField(
              decoration: const InputDecoration(
                labelText: '描述',
                hintText: '例如：午餐',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => ref.read(batchEntryProvider.notifier).updateDescription(v),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: currentEntry.isValid
                        ? () => ref.read(batchEntryProvider.notifier).addToPending()
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('添加'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: currentEntry.isValid && currentEntry.amount != null
                      ? () async {
                          // Quick submit: add to pending and immediately submit all
                          ref.read(batchEntryProvider.notifier).addToPending();
                          final count = await ref.read(batchEntryProvider.notifier).submitAll();
                          if (count > 0 && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('已提交 $count 条交易')),
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.send),
                  label: const Text('快速提交'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingEntriesPanel(
    BuildContext context,
    WidgetRef ref,
    BatchEntryState state,
  ) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '待提交 (${state.pendingEntries.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                TextButton(
                  onPressed: state.pendingEntries.isNotEmpty
                      ? () => ref.read(batchEntryProvider.notifier).clearAll()
                      : null,
                  child: const Text('清空'),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: ListView.builder(
              itemCount: state.pendingEntries.length,
              itemBuilder: (context, index) {
                final entry = state.pendingEntries[index];
                return ListTile(
                  dense: true,
                  leading: Text(
                    '¥${entry.amount?.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  title: Text(entry.description ?? ''),
                  subtitle: Text(entry.categoryId ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => ref.read(batchEntryProvider.notifier).removeFromPending(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String? iconName) {
    if (iconName == null) return Icons.category;
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_car':
        return Icons.directions_car;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'movie':
        return Icons.movie;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'school':
        return Icons.school;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      case 'card_giftcard':
        return Icons.card_giftcard;
      case 'trending_up':
        return Icons.trending_up;
      case 'attach_money':
        return Icons.attach_money;
      default:
        return Icons.category;
    }
  }
}