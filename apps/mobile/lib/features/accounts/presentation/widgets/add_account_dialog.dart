import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import 'package:database/database.dart';
import '../../data/account_provider.dart';

class AddAccountDialog extends ConsumerStatefulWidget {
  final Account? account;
  final Account? parentAccount;

  const AddAccountDialog({super.key, this.account, this.parentAccount});

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
  String? _selectedParentId;
  bool _isPlaceholder = false;
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
      _selectedParentId = widget.account!.parentId;
      _isPlaceholder = widget.account!.isPlaceholder;
    } else if (widget.parentAccount != null) {
      _selectedParentId = widget.parentAccount!.id;
      _selectedType = widget.parentAccount!.accountType;
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
              const SizedBox(height: 16),
              _buildParentSelector(),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('作为账户组'),
                subtitle: const Text('账户组可用于归类其他账户'),
                value: _isPlaceholder,
                onChanged: (value) {
                  setState(() => _isPlaceholder = value);
                },
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
          parentId: _selectedParentId,
          code: _codeController.text.isEmpty ? null : _codeController.text,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          isPlaceholder: _isPlaceholder,
        );
      } else {
        await notifier.updateAccount(
          widget.account!.copyWith(
            name: _nameController.text,
            accountType: _selectedType,
            commodityId: _selectedCurrency,
            parentId: drift.Value(_selectedParentId),
            code: drift.Value(_codeController.text.isEmpty ? null : _codeController.text),
            description: drift.Value(_descriptionController.text.isEmpty ? null : _descriptionController.text),
            isPlaceholder: drift.Value(_isPlaceholder),
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

  Widget _buildParentSelector() {
    final accountsAsync = ref.watch(accountsProvider);
    
    return accountsAsync.when(
      data: (accounts) {
        // Filter to show only placeholder accounts of same type (or all if creating new)
        final eligibleParents = accounts
            .where((a) => 
                a.isPlaceholder && 
                !a.isHidden &&
                (widget.account == null || a.id != widget.account?.id))
            .toList();
        
        if (eligibleParents.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return DropdownButtonFormField<String>(
          value: _selectedParentId,
          decoration: const InputDecoration(
            labelText: '父账户 (可选)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.folder_outlined),
          ),
          hint: const Text('选择父账户组'),
          items: [
            const DropdownMenuItem(value: null, child: Text('无 (根级账户)')),
            ...eligibleParents.map((a) => DropdownMenuItem(
              value: a.id,
              child: Text('${a.name} (${_getTypeLabel(a.accountType)})'),
            )),
          ],
          onChanged: (value) {
            setState(() => _selectedParentId = value);
          },
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _getTypeLabel(String accountType) {
    switch (accountType) {
      case 'ASSET':
        return '资产';
      case 'LIABILITY':
        return '负债';
      case 'EQUITY':
        return '权益';
      case 'INCOME':
        return '收入';
      case 'EXPENSE':
        return '支出';
      default:
        return accountType;
    }
  }
}