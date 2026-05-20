import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import 'package:database/database.dart';
import '../../data/account_provider.dart';

class AddAccountDialog extends ConsumerStatefulWidget {
  final Account? account;

  const AddAccountDialog({super.key, this.account});

  @override
  ConsumerState<AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends ConsumerState<AddAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedType = 'ASSET';
  String _selectedCurrency = 'CNY';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      _nameController.text = widget.account!.name;
      _codeController.text = widget.account!.code ?? '';
      _descriptionController.text = widget.account!.description ?? '';
      _selectedType = widget.account!.accountType;
      _selectedCurrency = widget.account!.commodityId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                widget.account == null ? '添加账户' : '编辑账户',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '账户名称',
                  hintText: '例如: 工商银行储蓄卡',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入账户名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: '账户类型',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'ASSET', child: Text('资产')),
                  DropdownMenuItem(value: 'LIABILITY', child: Text('负债')),
                  DropdownMenuItem(value: 'EQUITY', child: Text('权益')),
                  DropdownMenuItem(value: 'INCOME', child: Text('收入')),
                  DropdownMenuItem(value: 'EXPENSE', child: Text('支出')),
                ],
                onChanged: (value) {
                  setState(() => _selectedType = value!);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCurrency,
                decoration: const InputDecoration(
                  labelText: '币种',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                items: const [
                  DropdownMenuItem(value: 'CNY', child: Text('人民币 (CNY)')),
                  DropdownMenuItem(value: 'USD', child: Text('美元 (USD)')),
                  DropdownMenuItem(value: 'EUR', child: Text('欧元 (EUR)')),
                  DropdownMenuItem(value: 'JPY', child: Text('日元 (JPY)')),
                ],
                onChanged: (value) {
                  setState(() => _selectedCurrency = value!);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: '账号后四位（可选）',
                  prefixIcon: Icon(Icons.numbers),
                ),
                keyboardType: TextInputType.number,
                maxLength: 4,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.account == null ? '添加' : '保存'),
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
      final notifier = ref.read(accountNotifierProvider.notifier);

      if (widget.account == null) {
        await notifier.createAccount(
          name: _nameController.text,
          accountType: _selectedType,
          commodityId: _selectedCurrency,
          code: _codeController.text.isEmpty ? null : _codeController.text,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        );
      } else {
        await notifier.updateAccount(
          widget.account!.copyWith(
            name: _nameController.text,
            accountType: _selectedType,
            commodityId: _selectedCurrency,
            code: drift.Value(_codeController.text.isEmpty ? null : _codeController.text),
            description: drift.Value(_descriptionController.text.isEmpty ? null : _descriptionController.text),
          ),
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.account == null ? '账户已添加' : '账户已更新')),
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