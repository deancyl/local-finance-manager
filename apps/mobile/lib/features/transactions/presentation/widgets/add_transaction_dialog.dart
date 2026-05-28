import 'dart:async';
import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;

import 'package:database/database.dart';
import 'package:ai/ai.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';
import 'package:finance_app/features/categories/data/category_provider.dart';
import 'package:finance_app/features/tags/presentation/widgets/tag_selector.dart';
import 'package:finance_app/features/attachments/presentation/widgets/attachment_section.dart';
import 'package:finance_app/features/voice/presentation/widgets/voice_input_button.dart';
import 'package:finance_app/features/quick_entry/presentation/widgets/quick_category_select.dart';
import 'package:finance_app/features/quick_entry/presentation/widgets/recent_payees_widget.dart';
import 'package:finance_app/features/quick_entry/data/quick_actions_provider.dart';
import '../../data/transaction_provider.dart';
import '../../data/ai_provider.dart';
import '../../../templates/data/template_provider.dart' show templatesProvider, recentTemplatesProvider, templateNotifierProvider, TemplateModel, SplitTemplateData;
import 'quick_amount_input.dart';

class AddTransactionDialog extends ConsumerStatefulWidget {
  final Transaction? transaction;
  final bool isDuplicate;
  final String? originalDescription;
  final String? originalNotes;
  final String? originalCurrencyId;

  const AddTransactionDialog({
    super.key,
    this.transaction,
    this.isDuplicate = false,
    this.originalDescription,
    this.originalNotes,
    this.originalCurrencyId,
  });

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
  List<String> _selectedTagIds = [];
  
  // AI suggestion state
  Timer? _debounceTimer;
  String _debouncedDescription = '';
  CategorySuggestion? _currentSuggestion;
  bool _showSuggestion = false;

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
    
    // Add listener for AI suggestions
    _descriptionController.addListener(_onDescriptionChanged);
  }
  
  void _onDescriptionChanged() {
    final description = _descriptionController.text.trim();
    
    // Cancel previous debounce timer
    _debounceTimer?.cancel();
    
    // Hide suggestion if description is too short
    if (description.length < 3) {
      setState(() {
        _showSuggestion = false;
        _currentSuggestion = null;
        _debouncedDescription = '';
      });
      return;
    }
    
    // Debounce the AI suggestion request
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (description != _debouncedDescription && mounted) {
        setState(() {
          _debouncedDescription = description;
        });
      }
    });
  }
  
  void _acceptAISuggestion() {
    final suggestion = _currentSuggestion;
    if (suggestion != null) {
      setState(() {
        _selectedCategoryId = suggestion.categoryId;
        _showSuggestion = false;
      });
    }
  }
  
  void _dismissSuggestion() {
    setState(() {
      _showSuggestion = false;
    });
  }
  
  List<Widget> _buildAISuggestionSection() {
    if (!_showSuggestion || _currentSuggestion == null) {
      return [];
    }
    
    return [
      const SizedBox(height: 8),
      _buildAISuggestionChip(),
    ];
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
    _debounceTimer?.cancel();
    _descriptionController.removeListener(_onDescriptionChanged);
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    
    // Listen to AI suggestions when description changes
    if (_debouncedDescription.isNotEmpty) {
      ref.listen<AsyncValue<CategorySuggestion?>>(
        categorySuggestionProvider(_debouncedDescription),
        (previous, next) {
          next.when(
            data: (suggestion) {
              if (suggestion != null && mounted && _currentSuggestion != suggestion) {
                setState(() {
                  _currentSuggestion = suggestion;
                  _showSuggestion = true;
                });
              } else if (suggestion == null && _showSuggestion) {
                setState(() {
                  _showSuggestion = false;
                  _currentSuggestion = null;
                });
              }
            },
            loading: () {
              // Keep current state while loading
            },
            error: (_, __) {
              if (_showSuggestion) {
                setState(() {
                  _showSuggestion = false;
                  _currentSuggestion = null;
                });
              }
            },
          );
        },
      );
    }

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
              // Header with template selector
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.transaction == null ? '记一笔' : '编辑交易',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (widget.transaction == null)
                    TextButton.icon(
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text('模板'),
                      onPressed: () => _showTemplateSelector(context),
                    ),
                ],
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
              
              // 金额输入 - Quick Amount Entry
              QuickAmountInput(
                controller: _amountController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入金额';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null) {
                    return '请输入有效数字';
                  }
                  if (amount < 0) {
                    return '金额不能为负数';
                  }
                  if (amount >= 1000000000) {
                    return '金额不能超过10亿';
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
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
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
                      ),
                      
                      // Quick category select
                      const SizedBox(height: 12),
                      QuickCategorySelect(
                        selectedCategoryId: _selectedCategoryId,
                        onCategorySelected: (categoryId) {
                          setState(() => _selectedCategoryId = categoryId);
                        },
                        isIncome: _isIncome,
                        maxItems: 6,
                      ),
                    ],
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('加载分类失败'),
              ),
              const SizedBox(height: 16),
              
              // Recent payees
              RecentPayeesWidget(
                selectedPayee: _descriptionController.text,
                onPayeeSelected: (payee) {
                  setState(() {
                    _descriptionController.text = payee.description;
                    if (payee.categoryId != null) {
                      _selectedCategoryId = payee.categoryId;
                    }
                  });
                },
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
                decoration: InputDecoration(
                  labelText: '描述',
                  prefixIcon: const Icon(Icons.description_outlined),
                  suffixIcon: _debouncedDescription.isNotEmpty
                      ? ref.watch(categorySuggestionProvider(_debouncedDescription)).isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null
                      : null,
                ),
              ),
              
              // AI Category Suggestion - use ref.listen in build to update state
              ..._buildAISuggestionSection(),
              
              const SizedBox(height: 16),
              
              // 备注
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: '备注（可选）',
                  prefixIcon: const Icon(Icons.notes_outlined),
                  suffixIcon: VoiceInputButton(
                    controller: _notesController,
                    showLocaleSelector: true,
                    hint: '说点什么...',
                    onResult: (text) {
                      // Auto-save after voice input
                      setState(() {});
                    },
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              // 标签选择
              TagSelector(
                transactionId: widget.transaction?.id,
                onChanged: (tagIds) {
                  _selectedTagIds = tagIds;
                },
              ),
              const SizedBox(height: 16),
              
              // 附件
              AttachmentSection(
                transactionId: widget.transaction?.id,
                isEditing: widget.transaction != null,
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
  
  Widget _buildAISuggestionChip() {
    final categoriesAsync = ref.watch(categoriesProvider);
    final suggestion = _currentSuggestion;
    
    if (suggestion == null) {
      return const SizedBox.shrink();
    }
    
    return categoriesAsync.when(
      data: (categories) {
        final suggestedCategory = categories.where(
          (c) => c.id == suggestion.categoryId
        ).firstOrNull;
        
        if (suggestedCategory == null) {
          return const SizedBox.shrink();
        }
        
        // Check if suggestion matches current transaction type
        if (suggestedCategory.isIncome != _isIncome) {
          return const SizedBox.shrink();
        }
        
        final confidence = suggestion.confidence;
        final confidencePercent = (confidence * 100).round();
        final confidenceColor = confidence >= 0.8
            ? Colors.green
            : confidence >= 0.5
                ? Colors.orange
                : Colors.red;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'AI 建议分类',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          suggestedCategory.name,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: confidenceColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$confidencePercent%',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: confidenceColor,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _acceptAISuggestion,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('采纳'),
              ),
              IconButton(
                onPressed: _dismissSuggestion,
                icon: const Icon(Icons.close, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                tooltip: '忽略建议',
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
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
      final amount = double.tryParse(_amountController.text);
      if (amount == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无效的金额格式')),
          );
        }
        return;
      }
      final finalAmount = _isIncome ? amount : -amount;

      final notifier = ref.read(transactionNotifierProvider.notifier);

      if (widget.transaction != null && _existingSplit != null) {
        // Update existing transaction
        final existingTransaction = widget.transaction;
        final existingSplit = _existingSplit;
        
        if (existingTransaction == null || existingSplit == null) {
          throw StateError('Transaction or split should not be null');
        }
        
        final updatedTransaction = existingTransaction.copyWith(
          description: Value(_descriptionController.text.isEmpty ? null : _descriptionController.text),
          notes: Value(_notesController.text.isEmpty ? null : _notesController.text),
          postDate: _selectedDate.millisecondsSinceEpoch,
        );
        
        final selectedAccountId = _selectedAccountId;
        if (selectedAccountId == null) {
          throw StateError('Account ID should not be null');
        }
        
        final updatedSplit = existingSplit.copyWith(
          accountId: selectedAccountId,
          categoryId: Value(_selectedCategoryId),
          valueNum: (finalAmount * 100).round(),
          quantityNum: (finalAmount * 100).round(),
        );
        
        await notifier.updateTransaction(updatedTransaction, updatedSplit);
        
        // Update tags
        await ref.read(databaseProvider).tagsDao.updateTransactionTags(
          existingTransaction.id,
          _selectedTagIds,
        );
      } else {
        // Create new transaction
        final selectedAccountId = _selectedAccountId;
        if (selectedAccountId == null) {
          throw StateError('Account ID should not be null');
        }
        
        final transactionId = await notifier.createTransaction(
          accountId: selectedAccountId,
          amount: finalAmount,
          date: _selectedDate,
          currencyId: _selectedCurrency,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          categoryId: _selectedCategoryId,
        );
        
        // Save tags for new transaction
        if (transactionId != null && _selectedTagIds.isNotEmpty) {
          await ref.read(databaseProvider).tagsDao.updateTransactionTags(
            transactionId,
            _selectedTagIds,
          );
        }
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

  /// Show template selector bottom sheet
  void _showTemplateSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          final templatesAsync = ref.watch(templatesProvider);
          final recentTemplatesAsync = ref.watch(recentTemplatesProvider);

          return Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      '选择模板',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('新建'),
                      onPressed: () {
                        Navigator.pop(context);
                        _showSaveAsTemplateDialog();
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Template list
              Expanded(
                child: templatesAsync.when(
                  data: (templates) {
                    if (templates.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 48,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            const Text('暂无模板'),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _showSaveAsTemplateDialog();
                              },
                              child: const Text('创建模板'),
                            ),
                          ],
                        ),
                      );
                    }

                    // Show recent templates first
                    return ListView(
                      controller: scrollController,
                      children: [
                        // Recent templates
                        recentTemplatesAsync.when(
                          data: (recent) {
                            if (recent.isEmpty) return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                  child: Text(
                                    '最近使用',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          color: Theme.of(context).colorScheme.outline,
                                        ),
                                  ),
                                ),
                                ...recent.take(5).map((t) => _buildTemplateItem(context, t)),
                                const Divider(),
                              ],
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                        // All templates
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Text(
                            '全部模板',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                        ),
                        ...templates.map((t) => _buildTemplateItem(context, t)),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('加载失败: $e')),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTemplateItem(BuildContext context, TemplateModel template) {
    return ListTile(
      leading: Icon(
        template.isFavorite ? Icons.star : Icons.receipt_long,
        color: template.isFavorite ? Colors.amber : null,
      ),
      title: Text(template.name),
      subtitle: Text(
        '${template.splits.length} 分录 · 使用 ${template.useCount} 次',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () {
        Navigator.pop(context);
        _applyTemplate(template);
      },
    );
  }

  /// Apply template to form
  void _applyTemplate(TemplateModel template) {
    if (template.splits.isEmpty) return;

    final split = template.splits.first;
    final amount = split.amount.abs();

    setState(() {
      _amountController.text = amount.toString();
      _selectedAccountId = split.accountId;
      _selectedCategoryId = split.categoryId;
      _isIncome = split.amount > 0;
      if (template.defaultTxnDescription != null) {
        _descriptionController.text = template.defaultTxnDescription!;
      }
      if (template.defaultNotes != null) {
        _notesController.text = template.defaultNotes!;
      }
    });

    // Record usage
    ref.read(templateNotifierProvider.notifier).recordUsage(template.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已应用模板: ${template.name}')),
    );
  }

  /// Show dialog to save current form as template
  void _showSaveAsTemplateDialog() {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存为模板'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '模板名称',
                  hintText: '例如：月薪、房租',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: '分类（可选）',
                  hintText: '例如：收入、支出',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入模板名称')),
                );
                return;
              }

              final amount = double.tryParse(_amountController.text) ?? 0;
              final finalAmount = _isIncome ? amount : -amount;

              await ref.read(templateNotifierProvider.notifier).createTemplate(
                    name: nameController.text,
                    category: categoryController.text.isEmpty
                        ? null
                        : categoryController.text,
                    currencyId: _selectedCurrency,
                    defaultTxnDescription: _descriptionController.text.isEmpty
                        ? null
                        : _descriptionController.text,
                    defaultNotes: _notesController.text.isEmpty
                        ? null
                        : _notesController.text,
                    splits: [
                      SplitTemplateData(
                        accountId: _selectedAccountId ?? '',
                        categoryId: _selectedCategoryId,
                        amount: finalAmount,
                      ),
                    ],
                  );

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('模板已保存')),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}