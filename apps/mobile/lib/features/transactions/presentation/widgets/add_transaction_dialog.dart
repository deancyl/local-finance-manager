import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';
import 'package:finance_app/features/categories/data/category_provider.dart';
import '../../data/transaction_provider.dart';

class AddTransactionDialog extends ConsumerStatefulWidget {
  final Transaction? transaction;

  const AddTransactionDialog({super.key, this.transaction});

  @override
  ConsumerState<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends ConsumerState<AddTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedAccountId;
  String? _selectedCategoryId;
  String _selectedCurrency = 'CNY';
  bool _isIncome = false;
  bool _isLoading = false;
  Split? _existingSplit;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _descriptionController.text = widget.transaction!.description ?? '';
      _notesController.text = widget.transaction!.notes ?? '';
      _selectedDate = DateTime.fromMillisecondsSinceEpoch(widget.transaction!.postDate);
      _selectedCurrency = widget.transaction!.currencyId;
      _loadSplitData();
    }
  }

  Future<void> _loadSplitData() async {
    if (widget.transaction == null) return;
    
    final db = ref.read(databaseProvider);
    final splits = await db.transactionsDao.getSplits(widget.transaction!.id);
    
    if (splits.isNotEmpty && mounted) {
      final split = splits.first;
      _existingSplit = split;
      
      // Determine income/expense from amount sign
      final amount = split.valueNum.abs() / 100.0;
      final isIncome = split.valueNum > 0;
      
      setState(() {
        _amountController.text = amount.toString();
        _selectedAccountId = split.accountId;
        _selectedCategoryId = split.categoryId;
        _isIncome = isIncome;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

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
                widget.transaction == null ? '记一笔' : '编辑交易',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              
              // 收入/支出切换
              Row(
                children: [
                  Expanded(
                    child: _buildTypeButton(
                      context,
                      label: '支出',
                      isSelected: !_isIncome,
                      color: Colors.red,
                      onTap: () => setState(() => _isIncome = false),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTypeButton(
                      context,
                      label: '收入',
                      isSelected: _isIncome,
                      color: Colors.green,
                      onTap: () => setState(() => _isIncome = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // 金额输入
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: '金额',
                  prefixText: '¥ ',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入金额';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return '请输入有效金额';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // 分类选择
              categoriesAsync.when(
                data: (categories) {
                  final filteredCategories = _isIncome 
                      ? categories.where((c) => c.isIncome).toList()
                      : categories.where((c) => !c.isIncome).toList();
                  
                  if (filteredCategories.isEmpty) {
                    return const Text('请先添加分类');
                  }
                  
                  // Reset category if type changed and current category is invalid
                  if (_selectedCategoryId != null && 
                      !filteredCategories.any((c) => c.id == _selectedCategoryId)) {
                    _selectedCategoryId = filteredCategories.first.id;
                  }
                  
                  return DropdownButtonFormField<String>(
                    value: _selectedCategoryId ?? filteredCategories.first.id,
                    decoration: const InputDecoration(
                      labelText: '分类',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: filteredCategories.map((category) {
                      return DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategoryId = value);
                    },
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('加载分类失败'),
              ),
              const SizedBox(height: 16),
              
              // 账户选择
              accountsAsync.when(
                data: (accounts) {
                  if (accounts.isEmpty) {
                    return const Text('请先添加账户');
                  }
                  return DropdownButtonFormField<String>(
                    value: _selectedAccountId ?? accounts.first.id,
                    decoration: const InputDecoration(
                      labelText: '账户',
                      prefixIcon: Icon(Icons.account_balance_wallet),
                    ),
                    items: accounts.map((account) {
                      return DropdownMenuItem(
                        value: account.id,
                        child: Text(account.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedAccountId = value);
                    },
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('加载账户失败'),
              ),
              const SizedBox(height: 16),
              
              // 日期选择
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '日期',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormat('yyyy年MM月dd日').format(_selectedDate)),
                ),
              ),
              const SizedBox(height: 16),
              
              // 描述
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '描述',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 16),
              
              // 备注
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              
              // 保存按钮
              FilledButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Theme.of(context).colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isSelected ? color : Theme.of(context).colorScheme.outline,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择账户')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);
      final finalAmount = _isIncome ? amount : -amount;

      final notifier = ref.read(transactionNotifierProvider.notifier);

      if (widget.transaction != null && _existingSplit != null) {
        // Update existing transaction
        final updatedTransaction = widget.transaction!.copyWith(
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          postDate: _selectedDate.millisecondsSinceEpoch,
        );
        
        final updatedSplit = _existingSplit!.copyWith(
          accountId: _selectedAccountId!,
          categoryId: _selectedCategoryId,
          valueNum: (finalAmount * 100).round(),
          quantityNum: (finalAmount * 100).round(),
        );
        
        await notifier.updateTransaction(updatedTransaction, updatedSplit);
      } else {
        // Create new transaction
        await notifier.createTransaction(
          accountId: _selectedAccountId!,
          amount: finalAmount,
          date: _selectedDate,
          currencyId: _selectedCurrency,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          categoryId: _selectedCategoryId,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.transaction == null ? '交易已保存' : '交易已更新')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}