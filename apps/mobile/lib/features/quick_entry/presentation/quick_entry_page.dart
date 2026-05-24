import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/quick_entry_provider.dart';
import '../../templates/data/template_provider.dart';
import '../../accounts/data/account_provider.dart';
import '../../categories/data/category_provider.dart';

/// Quick entry page for fast transaction creation
class QuickEntryPage extends ConsumerWidget {
  const QuickEntryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quickEntryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('快速记账'),
        actions: [
          TextButton(
            onPressed: state.isValid
                ? () async {
                    final id = await ref.read(quickEntryProvider.notifier).submit();
                    if (id != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('交易已创建')),
                      );
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
            QuickEntryMode.simple => _buildSimpleEntry(context, ref, state),
            QuickEntryMode.transfer => _buildTransferEntry(context, ref, state),
            QuickEntryMode.template => _buildTemplateEntry(context, ref),
            QuickEntryMode.split => _buildSplitEntry(context, ref, state),
          },
        ],
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

  Widget _buildSimpleEntry(BuildContext context, WidgetRef ref, QuickEntryState state) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(expenseCategoriesProvider);

    return Column(
      children: [
        // Amount input
        _buildAmountInput(context, ref, state),
        const SizedBox(height: 16),

        // Account selector
        accountsAsync.when(
          data: (accounts) => _buildAccountDropdown(
            context,
            ref,
            '账户',
            state.fromAccountId,
            accounts,
            (id) => ref.read(quickEntryProvider.notifier).setFromAccount(id),
          ),
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('加载账户失败'),
        ),
        const SizedBox(height: 16),

        // Category selector
        categoriesAsync.when(
          data: (categories) => _buildCategoryDropdown(
            context,
            ref,
            state.categoryId,
            categories,
          ),
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('加载分类失败'),
        ),
        const SizedBox(height: 16),

        // Description
        TextField(
          decoration: const InputDecoration(
            labelText: '描述',
            hintText: '例如：午餐',
          ),
          onChanged: (v) => ref.read(quickEntryProvider.notifier).setDescription(v),
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
        _buildAmountInput(context, ref, state),
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
                (id) => ref.read(quickEntryProvider.notifier).setFromAccount(id),
              ),
              const SizedBox(height: 16),
              _buildAccountDropdown(
                context,
                ref,
                '到账户',
                state.toAccountId,
                accounts,
                (id) => ref.read(quickEntryProvider.notifier).setToAccount(id),
              ),
            ],
          ),
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('加载账户失败'),
        ),
        const SizedBox(height: 16),

        TextField(
          decoration: const InputDecoration(
            labelText: '备注',
            hintText: '可选',
          ),
          onChanged: (v) => ref.read(quickEntryProvider.notifier).setNotes(v),
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

  Widget _buildAmountInput(BuildContext context, WidgetRef ref, QuickEntryState state) {
    return TextField(
      decoration: InputDecoration(
        labelText: '金额',
        prefixText: '¥',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) {
        final amount = double.tryParse(v);
        ref.read(quickEntryProvider.notifier).setAmount(amount);
      },
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
      items: accounts.map<DropdownMenuItem<String>>((a) {
        return DropdownMenuItem(
          value: a.id,
          child: Text(a.name),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildCategoryDropdown(
    BuildContext context,
    WidgetRef ref,
    String? value,
    List categories,
  ) {
    return DropdownButtonFormField<String>(
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
      onChanged: (v) => ref.read(quickEntryProvider.notifier).setCategory(v),
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
        }
      },
    );
  }
}
