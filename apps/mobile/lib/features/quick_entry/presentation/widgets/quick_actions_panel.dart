import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quick_category_select.dart';
import 'recent_payees_widget.dart';
import 'one_tap_entry_widget.dart';

/// Combined quick actions panel for dashboard
/// 
/// Features:
/// - One-tap entry templates
/// - Quick category selection
/// - Recent payees
class QuickActionsPanel extends ConsumerWidget {
  final bool showCategories;
  final bool showPayees;
  final bool showOneTap;
  final String? selectedCategoryId;
  final ValueChanged<String?>? onCategorySelected;

  const QuickActionsPanel({
    super.key,
    this.showCategories = true,
    this.showPayees = true,
    this.showOneTap = true,
    this.selectedCategoryId,
    this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.flash_on,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '快速操作',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // One-tap entry
            if (showOneTap) ...[
              const OneTapEntryWidget(),
              const SizedBox(height: 16),
            ],
            
            // Quick category select
            if (showCategories) ...[
              QuickCategorySelect(
                selectedCategoryId: selectedCategoryId,
                onCategorySelected: onCategorySelected ?? (_) {},
                isIncome: false,
              ),
              const SizedBox(height: 16),
            ],
            
            // Recent payees
            if (showPayees) ...[
              RecentPayeesWidget(
                selectedPayee: null,
                onPayeeSelected: (payee) {
                  // Navigate to transaction with pre-filled data
                  // This will be handled by parent widget
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
