import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:database/database.dart';

import '../../data/budget_provider.dart';
import '../../../categories/data/category_provider.dart';

class AddBudgetDialog extends ConsumerStatefulWidget {
  final Budget? budget;

  const AddBudgetDialog({super.key, this.budget});

  @override
  ConsumerState<AddBudgetDialog> createState() => _AddBudgetDialogState();
}

class _AddBudgetDialogState extends ConsumerState<AddBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  
  String? _selectedCategoryId;
  String _selectedPeriod = 'MONTHLY';
  bool _isLoading = false;
  
  // Alert settings
  bool _alertEnabled = true;
  bool _alertAt50 = true;
  bool _alertAt75 = true;
  bool _alertAt90 = true;
  bool _alertAt100 = true;

  @override
  void initState() {
    super.initState();
    if (widget.budget != null) {
      _nameController.text = widget.budget!.name;
      _amountController.text = (widget.budget!.amountNum / widget.budget!.amountDenom).toStringAsFixed(2);
      _selectedCategoryId = widget.budget!.categoryId;
      _selectedPeriod = widget.budget!.period;
      // Load alert settings
      _alertEnabled = widget.budget!.alertEnabled;
      _alertAt50 = widget.budget!.alertAt50;
      _alertAt75 = widget.budget!.alertAt75;
      _alertAt90 = widget.budget!.alertAt90;
      _alertAt100 = widget.budget!.alertAt100;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                widget.budget == null ? '添加预算' : '编辑预算',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              
              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '预算名称',
                  hintText: '例如: 餐饮预算',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入预算名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Category dropdown
              categoriesAsync.when(
                data: (categories) {
                  final expenseCategories = categories.where((c) => !c.isIncome).toList();
                  return DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: '分类（可选）',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('全部分类')),
                      ...expenseCategories.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedCategoryId = value);
                    },
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('加载分类失败'),
              ),
              const SizedBox(height: 16),
              
              // Amount field
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: '预算金额',
                  hintText: '1000.00',
                  prefixIcon: Icon(Icons.attach_money),
                  suffixText: 'CNY',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入预算金额';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return '请输入有效的金额';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Period dropdown
              DropdownButtonFormField<String>(
                value: _selectedPeriod,
                decoration: const InputDecoration(
                  labelText: '预算周期',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                items: const [
                  DropdownMenuItem(value: 'MONTHLY', child: Text('每月')),
                  DropdownMenuItem(value: 'YEARLY', child: Text('每年')),
                  DropdownMenuItem(value: 'CUSTOM', child: Text('自定义')),
                ],
                onChanged: (value) {
                  setState(() => _selectedPeriod = value!);
                },
              ),
              const SizedBox(height: 24),
              
              // Alert settings section
              _buildAlertSettingsSection(context),
              const SizedBox(height: 24),
              
              // Submit button
              FilledButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.budget == null ? '添加' : '保存'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(budgetNotifierProvider.notifier);
      final amount = double.parse(_amountController.text);
      final amountNum = (amount * 100).round(); // Convert to cents
      final now = DateTime.now().millisecondsSinceEpoch;

      if (widget.budget == null) {
        await notifier.createBudget(
          name: _nameController.text,
          categoryId: _selectedCategoryId,
          amountNum: amountNum,
          currencyId: 'CNY',
          period: _selectedPeriod,
          startDate: now,
          alertEnabled: _alertEnabled,
          alertAt50: _alertAt50,
          alertAt75: _alertAt75,
          alertAt90: _alertAt90,
          alertAt100: _alertAt100,
        );
      } else {
        // Update budget using BudgetNotifier
        final updatedBudget = widget.budget!.copyWith(
          name: _nameController.text,
          categoryId: Value(_selectedCategoryId),
          amountNum: amountNum,
          amountDenom: 100,
          period: _selectedPeriod,
          alertEnabled: _alertEnabled,
          alertAt50: _alertAt50,
          alertAt75: _alertAt75,
          alertAt90: _alertAt90,
          alertAt100: _alertAt100,
        );
        await notifier.updateBudget(updatedBudget);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.budget == null ? '预算已添加' : '预算已更新')),
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
  
  Widget _buildAlertSettingsSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '提醒设置',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Master toggle
          SwitchListTile(
            title: const Text('启用预算提醒'),
            subtitle: Text(
              _alertEnabled ? '将在达到设定阈值时发送通知' : '不会发送预算提醒通知',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            value: _alertEnabled,
            onChanged: (value) {
              setState(() => _alertEnabled = value);
            },
            contentPadding: EdgeInsets.zero,
          ),
          
          // Threshold toggles
          if (_alertEnabled) ...[
            const Divider(),
            _buildThresholdToggle('50%', _alertAt50, (v) => setState(() => _alertAt50 = v)),
            _buildThresholdToggle('75%', _alertAt75, (v) => setState(() => _alertAt75 = v)),
            _buildThresholdToggle('90%', _alertAt90, (v) => setState(() => _alertAt90 = v)),
            _buildThresholdToggle('100%', _alertAt100, (v) => setState(() => _alertAt100 = v)),
          ],
        ],
      ),
    );
  }
  
  Widget _buildThresholdToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$label 阈值提醒',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}