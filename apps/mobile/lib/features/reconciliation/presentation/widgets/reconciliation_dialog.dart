import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:database/database.dart' hide Account;
import '../../data/reconciliation_provider.dart';
import '../../../accounts/data/account_provider.dart';

/// Dialog for starting a new reconciliation session.
/// 
/// Allows user to select:
/// - Account to reconcile
/// - Statement date
/// - Statement balance
class ReconciliationDialog extends ConsumerStatefulWidget {
  const ReconciliationDialog({super.key});

  @override
  ConsumerState<ReconciliationDialog> createState() => _ReconciliationDialogState();
}

class _ReconciliationDialogState extends ConsumerState<ReconciliationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _balanceController = TextEditingController();
  
  String? _selectedAccountId;
  DateTime _statementDate = DateTime.now();
  bool _isLoading = false;

  final _currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 2);
  final _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void dispose() {
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(reconcilableAccountsProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '开始对账',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '选择账户并输入银行对账单余额以开始对账',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              
              // Account selector
              DropdownButtonFormField<String>(
                value: _selectedAccountId,
                decoration: const InputDecoration(
                  labelText: '选择账户',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                items: accounts.map((account) {
                  return DropdownMenuItem(
                    value: account.id,
                    child: Text(account.name),
                  );
                }).toList(),
                validator: (value) {
                  if (value == null) {
                    return '请选择账户';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() => _selectedAccountId = value);
                },
              ),
              const SizedBox(height: 16),
              
              // Statement date picker
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '对账单日期',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(_dateFormat.format(_statementDate)),
                ),
              ),
              const SizedBox(height: 16),
              
              // Statement balance input
              TextFormField(
                controller: _balanceController,
                decoration: const InputDecoration(
                  labelText: '对账单余额',
                  prefixIcon: Icon(Icons.attach_money),
                  hintText: '0.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入对账单余额';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null) {
                    return '请输入有效的金额';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isLoading ? null : _startReconciliation,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('开始对账'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _statementDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _statementDate = picked);
    }
  }

  Future<void> _startReconciliation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Get account name
      final accounts = ref.read(reconcilableAccountsProvider);
      final account = accounts.firstWhere((a) => a.id == _selectedAccountId);
      
      // Parse balance - convert to integer (cents)
      final balanceStr = _balanceController.text;
      final balanceDecimal = double.parse(balanceStr);
      final balanceNum = (balanceDecimal * 100).round(); // Convert to cents

      // Start reconciliation session
      final notifier = ref.read(reconciliationNotifierProvider.notifier);
      await notifier.startSession(
        accountId: _selectedAccountId!,
        accountName: account.name,
        statementDate: _statementDate,
        statementBalanceNum: balanceNum,
        statementBalanceDenom: 100, // Cents
      );

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('开始对账失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
