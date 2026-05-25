import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/quick_entry_provider.dart';
import '../data/draft_provider.dart';
import '../../templates/data/template_provider.dart';
import '../../accounts/data/account_provider.dart';
import '../../categories/data/category_provider.dart';
import '../../transactions/presentation/widgets/quick_amount_input.dart';
import '../../../core/presentation/widgets/keyboard_shortcuts.dart';

/// Quick entry page for fast transaction creation
/// Enhanced with auto-save, smart defaults, and keyboard shortcuts
class QuickEntryPage extends ConsumerStatefulWidget {
  const QuickEntryPage({super.key});

  @override
  ConsumerState<QuickEntryPage> createState() => _QuickEntryPageState();
}

class _QuickEntryPageState extends ConsumerState<QuickEntryPage> {
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _amountController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadSmartDefaults();
  }
  
  @override
  void dispose() {
    _descriptionController.dispose();
    _notesController.dispose();
    _amountController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSmartDefaults() async {
    // Load smart defaults and apply to form
    final smartDefaults = await ref.read(smartDefaultsProvider.future);
    if (smartDefaults.suggestedAccountId != null) {
      ref.read(quickEntryProvider.notifier).setFromAccount(smartDefaults.suggestedAccountId);
    }
    if (smartDefaults.suggestedCategoryId != null) {
      ref.read(quickEntryProvider.notifier).setCategory(smartDefaults.suggestedCategoryId);
    }
    if (smartDefaults.suggestedAmount != null) {
      _amountController.text = smartDefaults.suggestedAmount!.toStringAsFixed(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quickEntryProvider);
    final draftState = ref.watch(draftAutoSaveProvider);
    final smartDefaultsAsync = ref.watch(smartDefaultsProvider);

    return ShortcutsActionWidget(
      onSave: () async {
        if (state.isValid) {
          final id = await ref.read(quickEntryProvider.notifier).submit();
          if (id != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('交易已创建')),
            );
            // Clear form
            _descriptionController.clear();
            _notesController.clear();
            _amountController.clear();
          }
        }
      },
      onSaveDraft: () {
        ref.read(draftAutoSaveProvider.notifier).saveNow();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('草稿已保存')),
        );
      },
      onSubmit: () async {
        if (state.isValid) {
          final id = await ref.read(quickEntryProvider.notifier).submit();
          if (id != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('交易已创建')),
            );
            _descriptionController.clear();
            _notesController.clear();
            _amountController.clear();
          }
        }
      },
      onToggleMode: () {
        final modes = QuickEntryMode.values;
        final currentIndex = modes.indexOf(state.mode);
        final nextIndex = (currentIndex + 1) % modes.length;
        ref.read(quickEntryProvider.notifier).setMode(modes[nextIndex]);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('快速记账'),
          actions: [
            // Auto-save indicator
            if (draftState.hasUnsavedChanges)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.save_outlined, size: 16),
              ),
            // Drafts button
            IconButton(
              onPressed: () => _showDraftsList(context),
              icon: const Icon(Icons.drafts),
              tooltip: '查看草稿',
            ),
            // Save button
            TextButton(
              onPressed: state.isValid
                  ? () async {
                      final id = await ref.read(quickEntryProvider.notifier).submit();
                      if (id != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('交易已创建')),
                        );
                        _descriptionController.clear();
                        _notesController.clear();
                        _amountController.clear();
                      }
                    }
                  : null,
              child: const Text('保存'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Mode selector
            _buildModeSelector(context, ref, state),
            const SizedBox(height: 16),

            // Content based on mode
            switch (state.mode) {
              QuickEntryMode.simple => _buildSimpleEntry(context, ref, state, smartDefaultsAsync),
              QuickEntryMode.transfer => _buildTransferEntry(context, ref, state),
              QuickEntryMode.template => _buildTemplateEntry(context, ref),
              QuickEntryMode.split => _buildSplitEntry(context, ref, state),
            },
            
            // Keyboard shortcuts help
            const SizedBox(height: 24),
            _buildKeyboardShortcutsHelp(context),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).pushNamed('/batch-entry');
          },
          icon: const Icon(Icons.playlist_add),
          label: const Text('批量记账'),
        ),
      ),
    );
  }

  Widget _buildModeSelector(BuildContext context, WidgetRef ref, QuickEntryState state) {
    return SegmentedButton<QuickEntryMode>(
      segments: const [
        ButtonSegment(value: QuickEntryMode.simple, label: Text('简单')),
        ButtonSegment(value: QuickEntryMode.transfer, label: Text('转账')),
        ButtonSegment(value: QuickEntryMode.template, label: Text('模板')),
        ButtonSegment(value: QuickEntryMode.split, label: Text('分录')),
      ],
      selected: {state.mode},
      onSelectionChanged: (modes) {
        ref.read(quickEntryProvider.notifier).setMode(modes.first);
      },
    );
  }

  Widget _buildSimpleEntry(
    BuildContext context,
    WidgetRef ref,
    QuickEntryState state,
    AsyncValue<SmartDefaults> smartDefaultsAsync,
  ) {
    final accountsAsync = ref.watch(accountsProvider);
    final categories = ref.watch(expenseCategoriesProvider);

    return Column(
      children: [
        // Amount input with quick amounts
        QuickAmountInput(
          controller: _amountController,
          enableQuickAmounts: true,
          quickAmounts: const [10, 50, 100, 500, 1000],
          onChanged: (v) {
            final amount = double.tryParse(v);
            ref.read(quickEntryProvider.notifier).setAmount(amount);
            // Auto-save draft
            ref.read(draftAutoSaveProvider.notifier).updateCurrentDraft(
              mode: 'simple',
              amount: v,
            );
          },
        ),
        const SizedBox(height: 16),

        // Account selector with smart default
        accountsAsync.when(
          data: (accounts) => _buildAccountDropdown(
            context,
            ref,
            '账户',
            state.fromAccountId,
            accounts,
            (id) {
              ref.read(quickEntryProvider.notifier).setFromAccount(id);
              ref.read(draftAutoSaveProvider.notifier).updateCurrentDraft(
                mode: 'simple',
                fromAccountId: id,
              );
            },
          ),
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('加载账户失败'),
        ),
        const SizedBox(height: 16),

        // Category selector with smart suggestions
        _buildCategoryDropdownWithSuggestions(
          context,
          ref,
          state.categoryId,
          categories,
          smartDefaultsAsync,
        ),
        const SizedBox(height: 16),

        // Description with auto-complete
        TextField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: '描述',
            hintText: '例如：午餐',
          ),
          onChanged: (v) {
            ref.read(quickEntryProvider.notifier).setDescription(v);
            // Auto-suggest category based on description
            smartDefaultsAsync.whenData((defaults) {
              final suggestedCategory = defaults.commonCategoryForDescription[v];
              if (suggestedCategory != null) {
                ref.read(quickEntryProvider.notifier).setCategory(suggestedCategory);
              }
            });
            ref.read(draftAutoSaveProvider.notifier).updateCurrentDraft(
              mode: 'simple',
              description: v,
            );
          },
        ),
        const SizedBox(height: 16),

        // Date
        _buildDateSelector(context, ref, state),
      ],
    );
  }

  Widget _buildTransferEntry(BuildContext context, WidgetRef ref, QuickEntryState state) {
    final accountsAsync = ref.watch(accountsProvider);

    return Column(
      children: [
        QuickAmountInput(
          controller: _amountController,
          enableQuickAmounts: true,
          onChanged: (v) {
            final amount = double.tryParse(v);
            ref.read(quickEntryProvider.notifier).setAmount(amount);
            ref.read(draftAutoSaveProvider.notifier).updateCurrentDraft(
              mode: 'transfer',
              amount: v,
            );
          },
        ),
        const SizedBox(height: 16),

        accountsAsync.when(
          data: (accounts) => Column(
            children: [
              _buildAccountDropdown(
                context,
                ref,
                '从账户',
                state.fromAccountId,
                accounts,
                (id) {
                  ref.read(quickEntryProvider.notifier).setFromAccount(id);
                  ref.read(draftAutoSaveProvider.notifier).updateCurrentDraft(
                    mode: 'transfer',
                    fromAccountId: id,
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildAccountDropdown(
                context,
                ref,
                '到账户',
                state.toAccountId,
                accounts,
                (id) {
                  ref.read(quickEntryProvider.notifier).setToAccount(id);
                  ref.read(draftAutoSaveProvider.notifier).updateCurrentDraft(
                    mode: 'transfer',
                    toAccountId: id,
                  );
                },
              ),
            ],
          ),
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('加载账户失败'),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: '备注',
            hintText: '可选',
          ),
          onChanged: (v) {
            ref.read(quickEntryProvider.notifier).setNotes(v);
            ref.read(draftAutoSaveProvider.notifier).updateCurrentDraft(
              mode: 'transfer',
              notes: v,
            );
          },
        ),
        const SizedBox(height: 16),

        _buildDateSelector(context, ref, state),
      ],
    );
  }

  Widget _buildTemplateEntry(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(templatesProvider);

    return Column(
      children: [
        templatesAsync.when(
          data: (templates) {
            if (templates.isEmpty) {
              return const Center(
                child: Text('暂无模板，请先创建模板'),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return Card(
                  child: InkWell(
                    onTap: () async {
                      ref.read(quickEntryProvider.notifier).setTemplate(template.id);
                      final id = await ref.read(quickEntryProvider.notifier).submit();
                      if (id != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已使用模板: ${template.name}')),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                template.isFavorite
                                    ? Icons.star
                                    : Icons.description,
                                color: template.isFavorite
                                    ? Colors.amber
                                    : null,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  template.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            '${template.splits.length} 分录',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败: $e')),
        ),
      ],
    );
  }

  Widget _buildSplitEntry(BuildContext context, WidgetRef ref, QuickEntryState state) {
    return const Center(
      child: Text('分录模式 - 请使用完整的日记账界面'),
    );
  }

  Widget _buildAccountDropdown(
    BuildContext context,
    WidgetRef ref,
    String label,
    String? value,
    List accounts,
    void Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      value: value,
      items: accounts
          .where((a) => !a.isPlaceholder)
          .map<DropdownMenuItem<String>>((a) {
        return DropdownMenuItem(
          value: a.id,
          child: Text(a.name),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildCategoryDropdownWithSuggestions(
    BuildContext context,
    WidgetRef ref,
    String? value,
    List categories,
    AsyncValue<SmartDefaults> smartDefaultsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: '分类',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          value: value,
          items: categories.map<DropdownMenuItem<String>>((c) {
            return DropdownMenuItem(
              value: c.id,
              child: Text(c.name),
            );
          }).toList(),
          onChanged: (v) {
            ref.read(quickEntryProvider.notifier).setCategory(v);
            ref.read(draftAutoSaveProvider.notifier).updateCurrentDraft(
              mode: 'simple',
              categoryId: v,
            );
          },
        ),
        // Show suggested categories
        smartDefaultsAsync.when(
          data: (defaults) {
            if (defaults.frequentCategories.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                children: defaults.frequentCategories.take(3).map((categoryId) {
                  final category = categories.firstWhere(
                    (c) => c.id == categoryId,
                    orElse: () => categories.first,
                  );
                  return ActionChip(
                    label: Text(category.name),
                    onPressed: () {
                      ref.read(quickEntryProvider.notifier).setCategory(categoryId);
                      ref.read(draftAutoSaveProvider.notifier).updateCurrentDraft(
                        mode: 'simple',
                        categoryId: categoryId,
                      );
                    },
                  );
                }).toList(),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildDateSelector(BuildContext context, WidgetRef ref, QuickEntryState state) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('日期'),
      subtitle: Text(DateFormat('yyyy-MM-dd').format(state.date)),
      trailing: const Icon(Icons.calendar_today),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: state.date,
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null) {
          ref.read(quickEntryProvider.notifier).setDate(date);
          ref.read(draftAutoSaveProvider.notifier).updateCurrentDraft(
            date: date,
          );
        }
      },
    );
  }

  void _showDraftsList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final draftsAsync = ref.watch(availableDraftsProvider);
            
            return Container(
              constraints: const BoxConstraints(maxHeight: 400),
              child: Column(
                children: [
                  AppBar(
                    title: const Text('草稿'),
                    automaticallyImplyLeading: false,
                    actions: [
                      TextButton(
                        onPressed: () {
                          ref.read(draftAutoSaveProvider.notifier).clearDraft();
                          Navigator.of(context).pop();
                        },
                        child: const Text('清空'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: draftsAsync.when(
                      data: (drafts) {
                        if (drafts.isEmpty) {
                          return const Center(
                            child: Text('暂无草稿'),
                          );
                        }
                        return ListView.builder(
                          itemCount: drafts.length,
                          itemBuilder: (context, index) {
                            final draft = drafts[index];
                            return ListTile(
                              leading: const Icon(Icons.drafts),
                              title: Text(draft.description ?? '无标题'),
                              subtitle: Text(
                                '${draft.mode} · ${DateTime.fromMillisecondsSinceEpoch(draft.updatedAt).toString()}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  ref.read(databaseProvider).draftTransactionsDao.deleteDraft(draft.id);
                                },
                              ),
                              onTap: () {
                                // Load draft into form
                                ref.read(draftAutoSaveProvider.notifier).loadDraft(draft.id);
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('加载失败: $e')),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKeyboardShortcutsHelp(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('键盘快捷键'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _ShortcutHelpRow(shortcut: 'Ctrl+S', description: '保存交易'),
                _ShortcutHelpRow(shortcut: 'Ctrl+Shift+S', description: '保存草稿'),
                _ShortcutHelpRow(shortcut: 'Enter', description: '快速提交'),
                _ShortcutHelpRow(shortcut: 'Ctrl+M', description: '切换模式'),
                _ShortcutHelpRow(shortcut: 'Alt+1-4', description: '快速金额 (10/50/100/500)'),
                _ShortcutHelpRow(shortcut: 'Esc', description: '取消'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutHelpRow extends StatelessWidget {
  final String shortcut;
  final String description;

  const _ShortcutHelpRow({
    required this.shortcut,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              shortcut,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Text(description),
        ],
      ),
    );
  }
}