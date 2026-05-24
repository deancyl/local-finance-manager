import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:database/database.dart';
import 'package:uuid/uuid.dart';
import '../../data/cost_center_provider.dart';

/// Dialog for adding/editing cost centers.
class AddCostCenterDialog extends ConsumerStatefulWidget {
  final CostCenter? costCenter;

  const AddCostCenterDialog({
    super.key,
    this.costCenter,
  });

  @override
  ConsumerState<AddCostCenterDialog> createState() => _AddCostCenterDialogState();
}

class _AddCostCenterDialogState extends ConsumerState<AddCostCenterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  CostCenterType _selectedType = CostCenterType.department;
  String? _selectedParentId;
  bool _isActive = true;
  int _sortOrder = 0;

  @override
  void initState() {
    super.initState();
    if (widget.costCenter != null) {
      _idController.text = widget.costCenter!.id;
      _nameController.text = widget.costCenter!.name;
      _codeController.text = widget.costCenter!.code ?? '';
      _descriptionController.text = widget.costCenter!.description ?? '';
      _selectedType = CostCenterType.fromCode(widget.costCenter!.costCenterType);
      _selectedParentId = widget.costCenter!.parentId;
      _isActive = widget.costCenter!.isActive;
      _sortOrder = widget.costCenter!.sortOrder;
    } else {
      _idController.text = const Uuid().v4().substring(0, 8).toUpperCase();
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final costCenters = ref.watch(activeCostCentersProvider);
    final state = ref.watch(costCenterNotifierProvider);

    return AlertDialog(
      title: Text(widget.costCenter == null ? '添加成本中心' : '编辑成本中心'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ID field (disabled for editing)
              if (widget.costCenter == null)
                TextFormField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    labelText: 'ID',
                    prefixIcon: Icon(Icons.key),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入ID';
                    }
                    return null;
                  },
                ),
              if (widget.costCenter == null) const SizedBox(height: 16),

              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名称',
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Code field
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: '代码（可选）',
                  prefixIcon: Icon(Icons.code),
                ),
              ),
              const SizedBox(height: 16),

              // Type selector
              DropdownButtonFormField<CostCenterType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: '类型',
                  prefixIcon: Icon(Icons.category),
                ),
                items: CostCenterType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    _selectedType = value;
                  }
                },
              ),
              const SizedBox(height: 16),

              // Parent selector
              DropdownButtonFormField<String>(
                value: _selectedParentId,
                decoration: const InputDecoration(
                  labelText: '上级成本中心（可选）',
                  prefixIcon: Icon(Icons.account_tree),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('无'),
                  ),
                  ...costCenters.where((c) => 
                    widget.costCenter == null || c.id != widget.costCenter!.id
                  ).map((c) {
                    return DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name),
                    );
                  }),
                ],
                onChanged: (value) {
                  _selectedParentId = value;
                },
              ),
              const SizedBox(height: 16),

              // Description field
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '描述（可选）',
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Active switch
              SwitchListTile(
                title: const Text('启用'),
                value: _isActive,
                onChanged: (value) {
                  _isActive = value;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.isLoading ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: state.isLoading ? null : _save,
          child: state.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.costCenter == null ? '添加' : '保存'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(costCenterNotifierProvider.notifier);

    if (widget.costCenter == null) {
      await notifier.create(
        id: _idController.text,
        name: _nameController.text,
        code: _codeController.text.isEmpty ? null : _codeController.text,
        parentId: _selectedParentId,
        type: _selectedType,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        isActive: _isActive,
        sortOrder: _sortOrder,
      );
    } else {
      final updated = CostCenter(
        id: widget.costCenter!.id,
        name: _nameController.text,
        code: _codeController.text.isEmpty ? null : _codeController.text,
        parentId: _selectedParentId,
        costCenterType: _selectedType.code,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        isActive: _isActive,
        managerId: widget.costCenter!.managerId,
        budgetLimitNum: widget.costCenter!.budgetLimitNum,
        budgetLimitDenom: widget.costCenter!.budgetLimitDenom,
        budgetCurrency: widget.costCenter!.budgetCurrency,
        sortOrder: _sortOrder,
        version: widget.costCenter!.version,
        createdAt: widget.costCenter!.createdAt,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        deletedAt: widget.costCenter!.deletedAt,
      );
      await notifier.update(updated);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }
}