import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:core/core.dart';
import '../widgets/account_selector.dart';
import '../../../core/presentation/widgets/accounting_help_icon.dart';
import '../../../core/presentation/widgets/accounting_help_icon.dart';

/// Widget for a single journal entry line in the editor.
class JournalEntryLineWidget extends StatefulWidget {
  final String lineId;
  final int index;
  final String? accountId;
  final String? accountName;
  final String? accountType;
  final double debit;
  final double credit;
  final String? memo;
  final bool canRemove;
  final VoidCallback onRemove;
  final void Function(Account) onAccountSelected;
  final void Function(double) onDebitChanged;
  final void Function(double) onCreditChanged;
  final void Function(String?) onMemoChanged;

  const JournalEntryLineWidget({
    super.key,
    required this.lineId,
    required this.index,
    this.accountId,
    this.accountName,
    this.accountType,
    this.debit = 0,
    this.credit = 0,
    this.memo,
    required this.canRemove,
    required this.onRemove,
    required this.onAccountSelected,
    required this.onDebitChanged,
    required this.onCreditChanged,
    required this.onMemoChanged,
  });

  @override
  State<JournalEntryLineWidget> createState() => _JournalEntryLineWidgetState();
}

class _JournalEntryLineWidgetState extends State<JournalEntryLineWidget> {
  final _debitController = TextEditingController();
  final _creditController = TextEditingController();
  final _memoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _updateControllers();
  }

  @override
  void didUpdateWidget(JournalEntryLineWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.debit != widget.debit || 
        oldWidget.credit != widget.credit ||
        oldWidget.memo != widget.memo) {
      _updateControllers();
    }
  }

  void _updateControllers() {
    if (widget.debit > 0) {
      _debitController.text = widget.debit.toStringAsFixed(2);
      _creditController.clear();
    } else if (widget.credit > 0) {
      _creditController.text = widget.credit.toStringAsFixed(2);
      _debitController.clear();
    } else {
      _debitController.clear();
      _creditController.clear();
    }
    _memoController.text = widget.memo ?? '';
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
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            const SizedBox(height: 12),
            _buildAccountSelector(theme),
            const SizedBox(height: 12),
            _buildAmountFields(theme),
            const SizedBox(height: 12),
            _buildMemoField(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
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
    );
  }

  Widget _buildAccountSelector(ThemeData theme) {
    return InkWell(
      onTap: () async {
        final account = await AccountSelectorWidget.show(
          context,
          selectedAccountId: widget.accountId,
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
            _getAccountTypeIcon(widget.accountType),
            size: 18,
            color: _getAccountTypeColor(widget.accountType),
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
          widget.accountName ?? '点击选择账户',
          style: widget.accountName != null
              ? theme.textTheme.bodyMedium
              : theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
        ),
      ),
    );
  }

  Widget _buildAmountFields(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildAmountField(
            theme,
            controller: _debitController,
            label: '借方',
            color: Colors.orange,
            helpKey: 'debit',
            onChanged: (value) {
              widget.onDebitChanged(value);
              setState(() {
                _creditController.clear();
              });
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
            helpKey: 'credit',
            onChanged: (value) {
              widget.onCreditChanged(value);
              setState(() {
                _debitController.clear();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField(
    ThemeData theme, {
    required TextEditingController controller,
    required String label,
    required Color color,
    required String helpKey,
    required void Function(double) onChanged,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: color),
        prefixText: '¥ ',
        prefixStyle: TextStyle(color: color),
        suffixIcon: AccountingHelpIcon.fromKey(
          glossaryKey: helpKey,
          iconSize: 16,
          iconColor: color,
        ),
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

  Widget _buildMemoField(ThemeData theme) {
    return TextField(
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
    );
  }

  IconData _getAccountTypeIcon(String? accountType) {
    switch (accountType) {
      case 'ASSET': return Icons.account_balance_wallet;
      case 'LIABILITY': return Icons.credit_card;
      case 'EQUITY': return Icons.pie_chart;
      case 'INCOME': return Icons.trending_up;
      case 'EXPENSE': return Icons.shopping_cart;
      default: return Icons.folder;
    }
  }

  Color _getAccountTypeColor(String? accountType) {
    switch (accountType) {
      case 'ASSET': return Colors.green;
      case 'LIABILITY': return Colors.red;
      case 'EQUITY': return Colors.purple;
      case 'INCOME': return Colors.blue;
      case 'EXPENSE': return Colors.orange;
      default: return Colors.grey;
    }
  }
}
