import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:finance_app/features/journal/providers/journal_entry_provider.dart';
import 'package:finance_app/features/journal/presentation/widgets/journal_entry_line_widget.dart';

/// Journal Entry Editor Page.
/// 
/// A full-screen page for creating and editing journal entries with:
/// - Form fields: entryNumber, description, postDate, reference, notes
/// - Dynamic list of journal entry lines (add/remove)
/// - Balance indicator showing total debits vs credits
/// - Validation: must be balanced before save
/// - Save/Post/Cancel actions
class JournalEntryEditorPage extends ConsumerStatefulWidget {
  /// Existing entry ID to edit (null for new entry)
  final String? entryId;

  const JournalEntryEditorPage({
    super.key,
    this.entryId,
  });

  @override
  ConsumerState<JournalEntryEditorPage> createState() => _JournalEntryEditorPageState();
}

class _JournalEntryEditorPageState extends ConsumerState<JournalEntryEditorPage> {
  final _descriptionController = TextEditingController();
  final _entryNumberController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    
    // Load existing entry if editing
    if (widget.entryId != null) {
      Future.microtask(() {
        ref.read(journalEntryEditorProvider.notifier).loadEntry(widget.entryId!);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Sync controllers with state
    final state = ref.read(journalEntryEditorProvider);
    _descriptionController.text = state.description;
    _entryNumberController.text = state.entryNumber ?? '';
    _referenceController.text = state.reference ?? '';
    _notesController.text = state.notes ?? '';
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _entryNumberController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(journalEntryEditorProvider);
    final notifier = ref.read(journalEntryEditorProvider.notifier);

    // Sync controllers when state changes
    if (_descriptionController.text != state.description) {
      _descriptionController.text = state.description;
    }
    if (_entryNumberController.text != (state.entryNumber ?? '')) {
      _entryNumberController.text = state.entryNumber ?? '';
    }
    if (_referenceController.text != (state.reference ?? '')) {
      _referenceController.text = state.reference ?? '';
    }
    if (_notesController.text != (state.notes ?? '')) {
      _notesController.text = state.notes ?? '';
    }

    return Scaffold(
      appBar: _buildAppBar(theme, state),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Entry Number
                  _buildEntryNumberField(theme, notifier),
                  const SizedBox(height: 16),

                  // Description
                  _buildDescriptionField(theme, notifier),
                  const SizedBox(height: 16),

                  // Post Date
                  _buildDatePicker(theme, state, notifier),
                  const SizedBox(height: 16),

                  // Reference
                  _buildReferenceField(theme, notifier),
                  const SizedBox(height: 16),

                  // Notes
                  _buildNotesField(theme, notifier),
                  const SizedBox(height: 24),

                  // Lines Header
                  _buildLinesHeader(theme, state),
                  const SizedBox(height: 12),

                  // Journal Entry Lines
                  ...state.lines.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: JournalEntryLineWidget(
                        key: ValueKey(entry.value.id),
                        lineId: entry.value.id,
                        index: entry.key,
                        accountId: entry.value.accountId,
                        accountName: entry.value.accountName,
                        accountType: entry.value.accountType,
                        debit: entry.value.debit,
                        credit: entry.value.credit,
                        memo: entry.value.memo,
                        canRemove: state.lines.length > 2,
                        onRemove: () => notifier.removeLine(entry.value.id),
                        onAccountSelected: (account) =>
                            notifier.updateLineAccount(entry.value.id, account),
                        onDebitChanged: (value) =>
                            notifier.updateLineDebit(entry.value.id, value),
                        onCreditChanged: (value) =>
                            notifier.updateLineCredit(entry.value.id, value),
                        onMemoChanged: (memo) =>
                            notifier.updateLineMemo(entry.value.id, memo),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Add Line Button
                  _buildAddLineButton(theme, notifier),
                  const SizedBox(height: 24),

                  // Balance Indicator
                  _buildBalanceIndicator(theme, state),
                  const SizedBox(height: 24),

                  // Error Message
                  if (state.errorMessage != null)
                    _buildErrorMessage(theme, state),

                  // Action Buttons
                  _buildActionButtons(theme, state, notifier),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, JournalEntryEditorState state) {
    return AppBar(
      title: Text(
        state.isEditing ? '编辑凭证' : '新建凭证',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => _handleCancel(),
      ),
      actions: [
        if (state.isEditing && state.isPosted)
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showHistory(),
            tooltip: '查看历史',
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) => _handleMenuAction(value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'reset',
              child: ListTile(
                leading: Icon(Icons.refresh),
                title: Text('重置表单'),
              ),
            ),
            if (state.isEditing && !state.isPosted)
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete),
                  title: Text('删除凭证'),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEntryNumberField(ThemeData theme, notifier) {
    return TextField(
      controller: _entryNumberController,
      decoration: InputDecoration(
        labelText: '凭证号',
        prefixIcon: const Icon(Icons.numbers),
        hintText: '自动生成',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onChanged: notifier.setEntryNumber,
    );
  }

  Widget _buildDescriptionField(ThemeData theme, notifier) {
    return TextField(
      controller: _descriptionController,
      decoration: InputDecoration(
        labelText: '摘要',
        prefixIcon: const Icon(Icons.description_outlined),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onChanged: notifier.setDescription,
      maxLines: 2,
    );
  }

  Widget _buildDatePicker(ThemeData theme, state, notifier) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: state.postDate,
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          notifier.setPostDate(picked);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '日期',
          prefixIcon: const Icon(Icons.calendar_today),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          DateFormat('yyyy年MM月dd日').format(state.postDate),
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }

  Widget _buildReferenceField(ThemeData theme, notifier) {
    return TextField(
      controller: _referenceController,
      decoration: InputDecoration(
        labelText: '参考号（可选）',
        prefixIcon: const Icon(Icons.tag),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onChanged: notifier.setReference,
    );
  }

  Widget _buildNotesField(ThemeData theme, notifier) {
    return TextField(
      controller: _notesController,
      decoration: InputDecoration(
        labelText: '备注（可选）',
        prefixIcon: const Icon(Icons.notes),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onChanged: notifier.setNotes,
      maxLines: 3,
    );
  }

  Widget _buildLinesHeader(ThemeData theme, state) {
    return Row(
      children: [
        Text(
          '分录明细',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${state.lines.length} 条',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddLineButton(ThemeData theme, notifier) {
    return OutlinedButton.icon(
      onPressed: notifier.addLine,
      icon: const Icon(Icons.add),
      label: const Text('添加分录'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildBalanceIndicator(ThemeData theme, JournalEntryEditorState state) {
    final isBalanced = state.isBalanced;
    final balanceColor = isBalanced ? Colors.green : theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isBalanced
            ? Colors.green.withOpacity(0.1)
            : theme.colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: balanceColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBalanceColumn(
                theme,
                label: '借方合计',
                value: state.totalDebits,
                color: Colors.orange,
              ),
              Container(
                width: 1,
                height: 40,
                color: theme.colorScheme.outlineVariant,
              ),
              _buildBalanceColumn(
                theme,
                label: '贷方合计',
                value: state.totalCredits,
                color: Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isBalanced ? Icons.check_circle : Icons.error_outline,
                color: balanceColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isBalanced
                    ? '借贷平衡 ✓'
                    : '差额: ¥${state.balance.abs().toStringAsFixed(2)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: balanceColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceColumn(
    ThemeData theme, {
    required String label,
    required double value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '¥${value.toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(ThemeData theme, JournalEntryEditorState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber,
            color: theme.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              state.errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme, state, notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Save button
        FilledButton.icon(
          onPressed: (state.isValid && !state.isSaving)
              ? () async => await _handleSave()
              : null,
          icon: state.isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save),
          label: Text(state.isSaving ? '保存中...' : '保存'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Post button (only if saved and not posted)
        if (state.entryId != null && !state.isPosted)
          OutlinedButton.icon(
            onPressed: !state.isSaving
                ? () async => await _handlePost()
                : null,
            icon: const Icon(Icons.post_add),
            label: const Text('过账'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

        // Posted indicator
        if (state.isPosted)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  '已过账',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _handleSave() async {
    final notifier = ref.read(journalEntryEditorProvider.notifier);
    final success = await notifier.save();

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('凭证已保存'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // Stay on page to allow posting
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(notifier.state.errorMessage ?? '保存失败'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handlePost() async {
    final notifier = ref.read(journalEntryEditorProvider.notifier);
    final success = await notifier.post();

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('凭证已过账'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleCancel() {
    final state = ref.read(journalEntryEditorProvider);
    
    if (state.description.isNotEmpty || state.lines.any((l) => l.hasAccount)) {
      // Show confirmation dialog if form has data
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认退出'),
          content: const Text('未保存的数据将丢失，是否继续？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('退出'),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'reset':
        _resetForm();
        break;
      case 'delete':
        _deleteEntry();
        break;
    }
  }

  void _resetForm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置表单'),
        content: const Text('确定要重置表单吗？所有未保存的数据将丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(journalEntryEditorProvider.notifier).reset();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('表单已重置'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }

  void _deleteEntry() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除凭证'),
        content: const Text('确定要删除此凭证吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final state = ref.read(journalEntryEditorProvider);
              if (state.entryId != null) {
                try {
                  final db = ref.read(databaseProvider);
                  await db.journalEntriesDao.deleteEntry(state.entryId!);
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('凭证已删除'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('删除失败: $e'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showHistory() {
    // TODO: Implement history view
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('历史记录功能即将上线'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}