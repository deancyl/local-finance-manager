import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:database/database.dart';
import 'package:core/core.dart' as domain;
import 'journal_account_selector.dart';

/// Entry side enumeration for debit/credit indicator.
enum EntrySide {
  debit,
  credit,
}

/// Extension to determine default entry side based on account type.
extension AccountTypeEntrySide on domain.AccountType {
  /// Returns the default entry side (debit/credit) for this account type.
  /// 
  /// ASSET and EXPENSE accounts normally have debit balances.
  /// LIABILITY, EQUITY, and INCOME accounts normally have credit balances.
  EntrySide get defaultSide {
    switch (this) {
      case domain.AccountType.asset:
      case domain.AccountType.expense:
      case domain.AccountType.investment:
        return EntrySide.debit;
      case domain.AccountType.liability:
      case domain.AccountType.equity:
      case domain.AccountType.income:
        return EntrySide.credit;
    }
  }
}

/// Data model for a split row in a journal entry.
class SplitRowData {
  final String? id;
  final String? accountId;
  final String? accountName;
  final domain.AccountType? accountType;
  final double amount;
  final String? memo;
  final EntrySide side;

  const SplitRowData({
    this.id,
    this.accountId,
    this.accountName,
    this.accountType,
    this.amount = 0.0,
    this.memo,
    this.side = EntrySide.debit,
  });

  SplitRowData copyWith({
    String? id,
    String? accountId,
    String? accountName,
    domain.AccountType? accountType,
    double? amount,
    String? memo,
    EntrySide? side,
  }) {
    return SplitRowData(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      accountType: accountType ?? this.accountType,
      amount: amount ?? this.amount,
      memo: memo ?? this.memo,
      side: side ?? this.side,
    );
  }
}

/// Reusable widget for a single debit/credit entry in journal entries.
/// 
/// Features:
/// - Account dropdown (uses JournalAccountSelector)
/// - Amount input (decimal, currency display)
/// - Memo text field (optional)
/// - Debit/Credit indicator (automatic based on account type)
/// - Delete button
class SplitRowWidget extends StatefulWidget {
  /// Initial data for the split row
  final SplitRowData initialData;
  
  /// Callback when split data changes
  final void Function(SplitRowData data) onChanged;
  
  /// Callback when delete button is pressed
  final VoidCallback onDelete;
  
  /// Whether this is the first split (cannot be deleted)
  final bool isRemovable;
  
  /// Index in the list (for display purposes)
  final int index;

  const SplitRowWidget({
    super.key,
    required this.initialData,
    required this.onChanged,
    required this.onDelete,
    this.isRemovable = true,
    this.index = 0,
  });

  @override
  State<SplitRowWidget> createState() => _SplitRowWidgetState();
}

class _SplitRowWidgetState extends State<SplitRowWidget> {
  late SplitRowData _data;
  late TextEditingController _amountController;
  late TextEditingController _memoController;
  
  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _amountController = TextEditingController(
      text: _data.amount != 0 ? _data.amount.abs().toStringAsFixed(2) : '',
    );
    _memoController = TextEditingController(text: _data.memo ?? '');
  }
  
  @override
  void didUpdateWidget(SplitRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialData != widget.initialData) {
      _data = widget.initialData;
      _amountController.text = _data.amount != 0 ? _data.amount.abs().toStringAsFixed(2) : '';
      _memoController.text = _data.memo ?? '';
    }
  }
  
  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _selectAccount() async {
    final account = await JournalAccountSelector.show(
      context,
      selectedAccountId: _data.accountId,
      showBalances: true,
      title: '选择账户',
    );
    
    if (account != null) {
      // Determine account type from string
      final accountType = domain.AccountType.values.firstWhere(
        (t) => t.code == account.accountType,
        orElse: () => domain.AccountType.asset,
      );
      
      setState(() {
        _data = _data.copyWith(
          accountId: account.id,
          accountName: account.name,
          accountType: accountType,
          side: accountType.defaultSide,
        );
      });
      widget.onChanged(_data);
    }
  }

  void _updateAmount(String value) {
    final amount = double.tryParse(value) ?? 0.0;
    setState(() {
      _data = _data.copyWith(amount: amount);
    });
    widget.onChanged(_data);
  }

  void _updateMemo(String value) {
    setState(() {
      _data = _data.copyWith(memo: value.isEmpty ? null : value);
    });
    widget.onChanged(_data);
  }

  void _toggleSide() {
    setState(() {
      _data = _data.copyWith(
        side: _data.side == EntrySide.debit ? EntrySide.credit : EntrySide.debit,
      );
    });
    widget.onChanged(_data);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with index and delete button
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${widget.index + 1}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (widget.isRemovable)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: widget.onDelete,
                    color: theme.colorScheme.error,
                    tooltip: '删除此行',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Account selector
            InkWell(
              onTap: _selectAccount,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _data.accountId == null
                        ? theme.colorScheme.outline
                        : theme.colorScheme.primary,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: _data.accountId != null
                      ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      _getAccountTypeIcon(_data.accountType),
                      color: _getAccountTypeColor(_data.accountType, theme),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _data.accountName ?? '选择账户',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: _data.accountId == null
                              ? theme.colorScheme.onSurfaceVariant
                              : null,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Amount and Debit/Credit indicator
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount input
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _amountController,
                    decoration: InputDecoration(
                      labelText: '金额',
                      prefixText: '¥ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: false,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    onChanged: _updateAmount,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入金额';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return '金额必须大于0';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                
                // Debit/Credit toggle
                Expanded(
                  flex: 2,
                  child: _buildSideToggle(theme),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Memo field (optional)
            TextFormField(
              controller: _memoController,
              decoration: InputDecoration(
                labelText: '备注 (可选)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                suffixIcon: _memoController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _memoController.clear();
                          _updateMemo('');
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    : null,
              ),
              onChanged: _updateMemo,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideToggle(ThemeData theme) {
    final isDebit = _data.side == EntrySide.debit;
    
    return InkWell(
      onTap: _toggleSide,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDebit ? Colors.green : Colors.blue,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isDebit
              ? Colors.green.withOpacity(0.1)
              : Colors.blue.withOpacity(0.1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDebit ? Icons.arrow_forward : Icons.arrow_back,
              color: isDebit ? Colors.green : Colors.blue,
              size: 18,
            ),
            const SizedBox(width: 4),
            Text(
              isDebit ? '借' : '贷',
              style: theme.textTheme.titleMedium?.copyWith(
                color: isDebit ? Colors.green : Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getAccountTypeIcon(domain.AccountType? type) {
    switch (type) {
      case domain.AccountType.asset:
        return Icons.account_balance_wallet;
      case domain.AccountType.liability:
        return Icons.credit_card;
      case domain.AccountType.equity:
        return Icons.pie_chart;
      case domain.AccountType.income:
        return Icons.trending_up;
      case domain.AccountType.expense:
        return Icons.shopping_cart;
      case domain.AccountType.investment:
        return Icons.show_chart;
      case null:
        return Icons.folder;
    }
  }

  Color _getAccountTypeColor(domain.AccountType? type, ThemeData theme) {
    switch (type) {
      case domain.AccountType.asset:
        return Colors.green;
      case domain.AccountType.liability:
        return Colors.red;
      case domain.AccountType.equity:
        return Colors.purple;
      case domain.AccountType.income:
        return Colors.blue;
      case domain.AccountType.expense:
        return Colors.orange;
      case domain.AccountType.investment:
        return Colors.teal;
      case null:
        return theme.colorScheme.onSurfaceVariant;
    }
  }
}
