import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:database/database.dart';
import 'package:finance_app/features/currency/data/currency_provider.dart';
import '../data/journal_entry_provider.dart';
import 'journal_account_selector.dart';

/// Dialog for creating/editing double-entry journal transactions.
///
/// Features:
/// - Date picker for transaction date
/// - Description and reference number fields
/// - Dynamic split list with add/remove functionality
/// - Real-time balance validation
/// - Save button disabled when unbalanced
class JournalEntryDialog extends ConsumerStatefulWidget {
  /// Existing transaction to edit (null for new entry)
  final Transaction? transaction;

  const JournalEntryDialog({
    super.key,
    this.transaction,
  });

  /// Shows the journal entry dialog as a modal bottom sheet.
  static Future<bool?> show(
    BuildContext context, {
    Transaction? transaction,
  }) async {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => JournalEntryDialog(transaction: transaction),
    );
  }

  @override
  ConsumerState<JournalEntryDialog> createState() => _JournalEntryDialogState();
}

class _JournalEntryDialogState extends ConsumerState<JournalEntryDialog> {
  final _descriptionController = TextEditingController();
  final _referenceController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize description from existing transaction if editing
    if (widget.transaction != null) {
      _descriptionController.text = widget.transaction!.description ?? '';
      _referenceController.text = widget.transaction!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _referenceController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(journalEntryProvider);
    final notifier = ref.read(journalEntryProvider.notifier);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          _buildHeader(theme),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Date picker
                  _buildDatePicker(theme, state, notifier),
                  const SizedBox(height: 16),

                  // Currency selector
                  _buildCurrencySelector(theme, state, notifier),
                  const SizedBox(height: 16),

                  // Description field
                  _buildDescriptionField(theme, notifier),
                  const SizedBox(height: 16),

                  // Reference number field
                  _buildReferenceField(theme, notifier),
                  const SizedBox(height: 24),

                  // Splits header
                  _buildSplitsHeader(theme, state),
                  const SizedBox(height: 12),

                  // Split lines
                  ...state.splits.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SplitLineCard(
                        key: ValueKey(entry.value.id),
                        split: entry.value,
                        index: entry.key,
                        canRemove: state.splits.length > 2,
                        onRemove: () => notifier.removeSplit(entry.value.id),
                        onAccountSelected: (account) =>
                            notifier.updateSplitAccount(entry.value.id, account),
                        onDebitChanged: (value) =>
                            notifier.updateSplitDebit(entry.value.id, value),
                        onCreditChanged: (value) =>
                            notifier.updateSplitCredit(entry.value.id, value),
                        onMemoChanged: (memo) =>
                            notifier.updateSplitMemo(entry.value.id, memo),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Add split button
                  _buildAddSplitButton(theme, notifier),
                  const SizedBox(height: 24),

                  // Balance indicator
                  _buildBalanceIndicator(theme, state),
                  const SizedBox(height: 24),

                  // Error message
                  if (state.errorMessage != null)
                    _buildErrorMessage(theme, state),

                  // Action buttons
                  _buildActionButtons(theme, state, notifier),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.receipt_long,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            widget.transaction == null ? '记账凭证' : '编辑凭证',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(
    ThemeData theme,
    JournalEntryState state,
    JournalEntryNotifier notifier,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: state.date,
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          notifier.setDate(picked);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '日期',
          prefixIcon: const Icon(Icons.calendar_today),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          DateFormat('yyyy年MM月dd日').format(state.date),
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }

  Widget _buildDescriptionField(ThemeData theme, JournalEntryNotifier notifier) {
    return TextField(
      controller: _descriptionController,
      decoration: InputDecoration(
        labelText: '摘要',
        prefixIcon: const Icon(Icons.description_outlined),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onChanged: notifier.setDescription,
    );
  }

  Widget _buildReferenceField(ThemeData theme, JournalEntryNotifier notifier) {
    return TextField(
      controller: _referenceController,
      decoration: InputDecoration(
        labelText: '凭证号（可选）',
        prefixIcon: const Icon(Icons.tag),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onChanged: notifier.setReferenceNumber,
    );
  }

  Widget _buildCurrencySelector(
    ThemeData theme,
    JournalEntryState state,
    JournalEntryNotifier notifier,
  ) {
    final currencies = ref.watch(currenciesProvider);

    return InputDecorator(
      decoration: InputDecoration(
        labelText: '币种',
        prefixIcon: const Icon(Icons.currency_exchange),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: state.currencyId,
          isExpanded: true,
          items: currencies.map((currency) {
            return DropdownMenuItem(
              value: currency.id,
              child: Text('${currency.mnemonic} - ${currency.fullName ?? currency.id}'),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              notifier.setCurrency(value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSplitsHeader(ThemeData theme, JournalEntryState state) {
    return Row(
      children: [
        Text(
          '分录明细',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${state.splits.length} 条',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddSplitButton(ThemeData theme, JournalEntryNotifier notifier) {
    return OutlinedButton.icon(
      onPressed: notifier.addSplit,
      icon: const Icon(Icons.add),
      label: const Text('添加分录'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildBalanceIndicator(ThemeData theme, JournalEntryState state) {
    final isBalanced = state.isBalanced;
    final balanceColor = isBalanced ? Colors.green : theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isBalanced
            ? Colors.green.withOpacity(0.1)
            : theme.colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: balanceColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBalanceColumn(
                theme,
                label: '借方合计',
                value: state.totalDebits,
                color: Colors.orange,
              ),
              Container(
                width: 1,
                height: 40,
                color: theme.colorScheme.outlineVariant,
              ),
              _buildBalanceColumn(
                theme,
                label: '贷方合计',
                value: state.totalCredits,
                color: Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isBalanced ? Icons.check_circle : Icons.error_outline,
                color: balanceColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isBalanced
                    ? '借贷平衡'
                    : '差额: ¥${state.balance.abs().toStringAsFixed(2)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: balanceColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceColumn(
    ThemeData theme, {
    required String label,
    required double value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '¥${value.toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(ThemeData theme, JournalEntryState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber,
            color: theme.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              state.errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    ThemeData theme,
    JournalEntryState state,
    JournalEntryNotifier notifier,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: state.isSaving
                ? null
                : () {
                    notifier.reset();
                    Navigator.pop(context, false);
                  },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('取消'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: (state.isValid && !state.isSaving)
                ? () async {
                    final success = await notifier.save();
                    if (success && mounted) {
                      Navigator.pop(context, true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('凭证已保存'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: state.isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('保存'),
          ),
        ),
      ],
    );
  }
}

/// Widget for a single split line in the journal entry.
class _SplitLineCard extends StatefulWidget {
  final SplitLine split;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final void Function(Account) onAccountSelected;
  final void Function(double) onDebitChanged;
  final void Function(double) onCreditChanged;
  final void Function(String?) onMemoChanged;
  final void Function(CostCenter?)? onCostCenterChanged; // Cost center callback

  const _SplitLineCard({
    super.key,
    required this.split,
    required this.index,
    required this.canRemove,
    required this.onRemove,
    required this.onAccountSelected,
    required this.onDebitChanged,
    required this.onCreditChanged,
    required this.onMemoChanged,
    this.onCostCenterChanged,
  });

  @override
  State<_SplitLineCard> createState() => _SplitLineCardState();
}

class _SplitLineCardState extends State<_SplitLineCard> {
  final _debitController = TextEditingController();
  final _creditController = TextEditingController();
  final _memoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _updateControllers();
  }

  @override
  void didUpdateWidget(_SplitLineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.split != widget.split) {
      _updateControllers();
    }
  }

  void _updateControllers() {
    if (widget.split.debit > 0) {
      _debitController.text = widget.split.debit.toStringAsFixed(2);
      _creditController.clear();
    } else if (widget.split.credit > 0) {
      _creditController.text = widget.split.credit.toStringAsFixed(2);
      _debitController.clear();
    } else {
      _debitController.clear();
      _creditController.clear();
    }
    _memoController.text = widget.split.memo ?? '';
  }

  @override
  void dispose() {
    _debitController.dispose();
    _creditController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with index and remove button
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${widget.index + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '分录 #${widget.index + 1}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.canRemove)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    iconSize: 20,
                    color: theme.colorScheme.error,
                    onPressed: widget.onRemove,
                    tooltip: '删除分录',
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Account selector
            _buildAccountSelector(theme),
            const SizedBox(height: 12),

            // Debit and Credit inputs
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildAmountField(
                    theme,
                    controller: _debitController,
                    label: '借方',
                    color: Colors.orange,
                    onChanged: (value) {
                      widget.onDebitChanged(value);
                      _creditController.clear();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAmountField(
                    theme,
                    controller: _creditController,
                    label: '贷方',
                    color: Colors.blue,
                    onChanged: (value) {
                      widget.onCreditChanged(value);
                      _debitController.clear();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Memo field
            TextField(
              controller: _memoController,
              decoration: InputDecoration(
                labelText: '备注（可选）',
                prefixIcon: const Icon(Icons.notes_outlined, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: theme.textTheme.bodySmall,
              onChanged: widget.onMemoChanged,
            ),
            
            // Cost center selector (optional)
            if (widget.onCostCenterChanged != null) ...[
              const SizedBox(height: 12),
              _buildCostCenterSelector(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCostCenterSelector(ThemeData theme) {
    // Get cost centers from provider - need to wrap in Consumer for this
    return Builder(
      builder: (context) {
        // This will be implemented with Consumer widget when used in journal_entry_dialog
        return InkWell(
          onTap: widget.onCostCenterChanged == null ? null : () async {
            // Cost center selection will be implemented in the parent widget
          },
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: '成本中心（可选）',
              prefixIcon: Icon(
                Icons.account_tree_outlined,
                size: 18,
                color: widget.split.costCenterName != null
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              suffixIcon: const Icon(Icons.arrow_drop_down),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              widget.split.costCenterName ?? '未选择',
              style: theme.textTheme.bodySmall?.copyWith(
                color: widget.split.costCenterName != null
                    ? null
                    : theme.colorScheme.outline,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccountSelector(ThemeData theme) {
    return InkWell(
      onTap: () async {
        final account = await JournalAccountSelector.show(
          context,
          selectedAccountId: widget.split.accountId,
          showBalances: false,
          title: '选择账户',
        );
        if (account != null) {
          widget.onAccountSelected(account);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '账户',
          prefixIcon: Icon(
            _getAccountTypeIcon(widget.split.accountType),
            size: 18,
            color: _getAccountTypeColor(widget.split.accountType),
          ),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          widget.split.accountName ?? '点击选择账户',
          style: widget.split.accountName != null
              ? theme.textTheme.bodyMedium
              : theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
        ),
      ),
    );
  }

  Widget _buildAmountField(
    ThemeData theme, {
    required TextEditingController controller,
    required String label,
    required Color color,
    required void Function(double) onChanged,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: color),
        prefixText: '¥ ',
        prefixStyle: TextStyle(color: color),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color, width: 2),
        ),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      onChanged: (value) {
        final amount = double.tryParse(value) ?? 0;
        onChanged(amount);
      },
    );
  }

  IconData _getAccountTypeIcon(String? accountType) {
    switch (accountType) {
      case 'ASSET':
        return Icons.account_balance_wallet;
      case 'LIABILITY':
        return Icons.credit_card;
      case 'EQUITY':
        return Icons.pie_chart;
      case 'INCOME':
        return Icons.trending_up;
      case 'EXPENSE':
        return Icons.shopping_cart;
      default:
        return Icons.folder;
    }
  }

  Color _getAccountTypeColor(String? accountType) {
    switch (accountType) {
      case 'ASSET':
        return Colors.green;
      case 'LIABILITY':
        return Colors.red;
      case 'EQUITY':
        return Colors.purple;
      case 'INCOME':
        return Colors.blue;
      case 'EXPENSE':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
