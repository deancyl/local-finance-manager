import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:database/database.dart';
import '../../data/recurring_provider.dart';
import '../../../accounts/data/account_provider.dart';
import '../../../categories/data/category_provider.dart';

class AddRecurringDialog extends ConsumerStatefulWidget {
  final RecurringTransaction? recurring;

  const AddRecurringDialog({super.key, this.recurring});

  @override
  ConsumerState<AddRecurringDialog> createState() => _AddRecurringDialogState();
}

class _AddRecurringDialogState extends ConsumerState<AddRecurringDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  final _intervalController = TextEditingController(text: '1');
  final _maxOccurrencesController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedFrequency = 'monthly';
  String? _selectedAccountId;
  String? _selectedCategoryId;
  DateTime _startDate = DateTime.now();
  DateTime _nextDate = DateTime.now().add(const Duration(days: 1));
  DateTime? _endDate;
  int? _dayOfWeek;
  int? _dayOfMonth;
  int? _monthOfYear;

  final List<String> _frequencyOptions = ['daily', 'weekly', 'monthly', 'yearly', 'custom'];
  final List<String> _frequencyLabels = ['每天', '每周', '每月', '每年', '自定义'];

  @override
  void initState() {
    super.initState();
    if (widget.recurring != null) {
      final r = widget.recurring!;
      _nameController.text = r.name;
      _descriptionController.text = r.description ?? '';
      _amountController.text = (r.valueNum / r.valueDenom.toDouble()).toStringAsFixed(2);
      _memoController.text = r.memo ?? '';
      _intervalController.text = r.interval.toString();
      _maxOccurrencesController.text = r.maxOccurrences?.toString() ?? '';
      _notesController.text = r.notes ?? '';
      _selectedFrequency = r.frequency;
      _selectedAccountId = r.accountId;
      _selectedCategoryId = r.categoryId;
      _startDate = DateTime.fromMillisecondsSinceEpoch(r.startDate);
      _nextDate = DateTime.fromMillisecondsSinceEpoch(r.nextDate);
      _endDate = r.endDate != null ? DateTime.fromMillisecondsSinceEpoch(r.endDate!) : null;
      _dayOfWeek = r.dayOfWeek;
      _dayOfMonth = r.dayOfMonth;
      _monthOfYear = r.monthOfYear;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    _intervalController.dispose();
    _maxOccurrencesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return AlertDialog(
      title: Text(widget.recurring == null ? '添加定期交易' : '编辑定期交易'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名称 *',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '描述',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: '金额 *',
                  prefixText: '¥ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入金额';
                  }
                  if (double.tryParse(value) == null) {
                    return '请输入有效金额';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedAccountId,
                decoration: const InputDecoration(
                  labelText: '账户',
                ),
                items: accountsAsync.when(
                  data: (accounts) => accounts.map((a) => DropdownMenuItem(
                    value: a.id,
                    child: Text(a.name),
                  )).toList(),
                  loading: () => [],
                  error: (_, __) => [],
                ),
                onChanged: (value) => setState(() => _selectedAccountId = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: '分类',
                ),
                items: categoriesAsync.when(
                  data: (categories) => categories.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name),
                  )).toList(),
                  loading: () => [],
                  error: (_, __) => [],
                ),
                onChanged: (value) => setState(() => _selectedCategoryId = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedFrequency,
                decoration: const InputDecoration(
                  labelText: '频率 *',
                ),
                items: List.generate(_frequencyOptions.length, (index) => 
                  DropdownMenuItem(
                    value: _frequencyOptions[index],
                    child: Text(_frequencyLabels[index]),
                  ),
                ),
                onChanged: (value) => setState(() => _selectedFrequency = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _intervalController,
                decoration: const InputDecoration(
                  labelText: '间隔',
                  helperText: '例如: 每2周 = 频率选每周，间隔填2',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('开始日期'),
                subtitle: Text(DateFormat.yMMMd().format(_startDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, true),
              ),
              ListTile(
                title: const Text('下次执行日期'),
                subtitle: Text(DateFormat.yMMMd().format(_nextDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, false),
              ),
              ListTile(
                title: Text(_endDate != null 
                    ? '结束日期: ${DateFormat.yMMMd().format(_endDate!)}' 
                    : '结束日期（可选）'),
                subtitle: _endDate != null ? null : const Text('不设置则无限期'),
                trailing: Icon(_endDate != null ? Icons.calendar_today : Icons.calendar_today_outlined),
                onTap: () => _selectEndDate(context),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _maxOccurrencesController,
                decoration: const InputDecoration(
                  labelText: '最大次数（可选）',
                  helperText: '不设置则无限次',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _memoController,
                decoration: const InputDecoration(
                  labelText: '备注',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: '注释',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final initial = isStart ? _startDate : _nextDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _nextDate = picked;
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _nextDate.add(const Duration(days: 30)),
      firstDate: _nextDate,
      lastDate: DateTime(2100),
    );
    
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text);
    final valueNum = (amount * 100).round();
    final interval = int.tryParse(_intervalController.text) ?? 1;
    final maxOccurrences = _maxOccurrencesController.text.isNotEmpty 
        ? int.tryParse(_maxOccurrencesController.text) 
        : null;

    if (widget.recurring == null) {
      ref.read(recurringNotifierProvider.notifier).createRecurring(
        name: _nameController.text.trim(),
        valueNum: valueNum,
        description: _descriptionController.text.trim().isNotEmpty 
            ? _descriptionController.text.trim() 
            : null,
        memo: _memoController.text.trim().isNotEmpty 
            ? _memoController.text.trim() 
            : null,
        accountId: _selectedAccountId,
        categoryId: _selectedCategoryId,
        frequency: _selectedFrequency,
        interval: interval,
        dayOfWeek: _dayOfWeek,
        dayOfMonth: _dayOfMonth,
        monthOfYear: _monthOfYear,
        startDate: _startDate,
        nextDate: _nextDate,
        endDate: _endDate,
        maxOccurrences: maxOccurrences,
        notes: _notesController.text.trim().isNotEmpty 
            ? _notesController.text.trim() 
            : null,
      );
    } else {
      ref.read(recurringNotifierProvider.notifier).updateRecurring(
        id: widget.recurring!.id,
        name: _nameController.text.trim(),
        valueNum: valueNum,
        description: _descriptionController.text.trim().isNotEmpty 
            ? _descriptionController.text.trim() 
            : null,
        memo: _memoController.text.trim().isNotEmpty 
            ? _memoController.text.trim() 
            : null,
        accountId: _selectedAccountId,
        categoryId: _selectedCategoryId,
        frequency: _selectedFrequency,
        interval: interval,
        dayOfWeek: _dayOfWeek,
        dayOfMonth: _dayOfMonth,
        monthOfYear: _monthOfYear,
        nextDate: _nextDate,
        endDate: _endDate,
        maxOccurrences: maxOccurrences,
        notes: _notesController.text.trim().isNotEmpty 
            ? _notesController.text.trim() 
            : null,
      );
    }

    Navigator.pop(context);
  }
}
