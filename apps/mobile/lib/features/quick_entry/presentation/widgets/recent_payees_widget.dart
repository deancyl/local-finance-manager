import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/quick_actions_provider.dart';

/// Recent payees quick selector
/// 
/// Features:
/// - Shows frequently used transaction descriptions
/// - One-tap to reuse with same category
/// - Horizontal scrollable list
class RecentPayeesWidget extends ConsumerWidget {
  final String? selectedPayee;
  final ValueChanged<RecentPayee> onPayeeSelected;
  final int maxItems;

  const RecentPayeesWidget({
    super.key,
    this.selectedPayee,
    required this.onPayeeSelected,
    this.maxItems = 8,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentPayeesAsync = ref.watch(recentPayeesProvider);
    
    return recentPayeesAsync.when(
      data: (payees) {
        if (payees.isEmpty) {
          return const SizedBox.shrink();
        }
        
        final displayPayees = payees.take(maxItems).toList();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '最近收款方',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: displayPayees.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final payee = displayPayees[index];
                  final isSelected = payee.description == selectedPayee;
                  
                  return _PayeeChip(
                    payee: payee,
                    isSelected: isSelected,
                    onTap: () => onPayeeSelected(payee),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 56,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _PayeeChip extends StatelessWidget {
  final RecentPayee payee;
  final bool isSelected;
  final VoidCallback onTap;

  const _PayeeChip({
    required this.payee,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1,
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Description
              Text(
                payee.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              // Use count
              if (payee.useCount > 1) ...[
                const SizedBox(height: 2),
                Text(
                  '使用${payee.useCount}次',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}