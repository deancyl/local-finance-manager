import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:database/database.dart';
import '../../data/category_provider.dart';
import 'category_icon_picker.dart';
import 'category_color_picker.dart';

class AddCategoryDialog extends ConsumerStatefulWidget {
  final Category? category;
  final bool initialIsIncome;

  const AddCategoryDialog({
    super.key,
    this.category,
    this.initialIsIncome = false,
  });

  @override
  ConsumerState<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends ConsumerState<AddCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  late bool _isIncome;
  String? _selectedIcon;
  String? _selectedColor;
  String? _selectedParentId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isIncome = widget.category?.isIncome ?? widget.initialIsIncome;
    
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _selectedIcon = widget.category!.icon;
      _selectedColor = widget.category!.color;
      _selectedParentId = widget.category!.parentId;
    } else {
      // Default values for new category
      _selectedIcon = _isIncome ? 'account_balance_wallet' : 'restaurant';
      _selectedColor = CategoryColors.colorToHex(
        _isIncome ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.category == null ? '添加分类' : '编辑分类',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Name field
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '分类名称',
                      hintText: '例如: 餐饮、交通',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入分类名称';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Income/Expense toggle
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('支出')),
                      ButtonSegment(value: true, label: Text('收入')),
                    ],
                    selected: {_isIncome},
                    onSelectionChanged: (Set<bool> selection) {
                      setState(() {
                        _isIncome = selection.first;
                        // Reset icon when switching type
                        _selectedIcon = _isIncome 
                            ? 'account_balance_wallet' 
                            : 'restaurant';
                        _selectedColor = CategoryColors.colorToHex(
                          _isIncome 
                              ? const Color(0xFF4CAF50) 
                              : const Color(0xFFE53935),
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Parent category selector
                  _buildParentSelector(),
                  const SizedBox(height: 16),
                  
                  // Icon picker
                  CategoryIconPicker(
                    selectedIcon: _selectedIcon,
                    isIncome: _isIncome,
                    onIconSelected: (icon) {
                      setState(() => _selectedIcon = icon);
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Color picker
                  CategoryColorPicker(
                    selectedColor: _selectedColor,
                    onColorSelected: (color) {
                      setState(() => _selectedColor = color);
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Preview
                  _buildPreview(context),
                  const SizedBox(height: 24),
                  
                  // Save button
                  FilledButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(widget.category == null ? '添加' : '保存'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParentSelector() {
    final categoriesAsync = ref.watch(categoriesProvider);
    
    return categoriesAsync.when(
      data: (categories) {
        // Filter to show only categories of same type (income/expense)
        final eligibleParents = categories
            .where((c) => 
                c.isIncome == _isIncome && 
                (widget.category == null || c.id != widget.category?.id))
            .toList();
        
        if (eligibleParents.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return DropdownButtonFormField<String>(
          value: _selectedParentId,
          decoration: const InputDecoration(
            labelText: '父分类 (可选)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.folder_outlined),
          ),
          hint: const Text('选择父分类'),
          items: [
            const DropdownMenuItem(value: null, child: Text('无 (根级分类)')),
            ...eligibleParents.map((c) => DropdownMenuItem(
              value: c.id,
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: c.color != null
                          ? CategoryColors.hexToColor(c.color)
                          : Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      CategoryIcons.getIconData(c.icon),
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(c.name),
                ],
              ),
            )),
          ],
          onChanged: (value) {
            setState(() => _selectedParentId = value);
          },
        );
      },
      loading: () => const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final color = CategoryColors.hexToColor(_selectedColor);
    final icon = CategoryIcons.getIconData(_selectedIcon);
    final name = _nameController.text.isEmpty ? '分类预览' : _nameController.text;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '预览',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            title: Text(
              name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(_isIncome ? '收入分类' : '支出分类'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(categoryNotifierProvider.notifier);

      if (widget.category == null) {
        await notifier.createCategory(
          name: _nameController.text,
          isIncome: _isIncome,
          icon: _selectedIcon,
          color: _selectedColor,
          parentId: _selectedParentId,
        );
      } else {
        // Update category using the notifier
        await notifier.updateCategory(
          widget.category!.id,
          name: _nameController.text,
          isIncome: _isIncome,
          icon: _selectedIcon,
          color: _selectedColor,
          parentId: _selectedParentId,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.category == null ? '分类已添加' : '分类已更新'),
          ),
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
