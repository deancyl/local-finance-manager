import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

/// Bottom sheet for displaying journal entry details.
class JournalEntryDetailSheet extends ConsumerStatefulWidget {
  final String entryId;
  final VoidCallback? onEdit;
  final VoidCallback? onPost;
  final VoidCallback? onDelete;

  const JournalEntryDetailSheet({
    super.key,
    required this.entryId,
    this.onEdit,
    this.onPost,
    this.onDelete,
  });

  @override
  ConsumerState<JournalEntryDetailSheet> createState() => _JournalEntryDetailSheetState();
}

class _JournalEntryDetailSheetState extends ConsumerState<JournalEntryDetailSheet> {
  JournalEntryWithLines? _entryWithLines;
  Map<String, Account> _accounts = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  Future<void> _loadEntry() async {
    try {
      final db = ref.read(databaseProvider);

      // Load entry with lines
      final entryWithLines = await db.journalEntriesDao.getJournalEntryWithLines(widget.entryId);
      if (entryWithLines == null) {
        setState(() {
          _isLoading = false;
          _error = '凭证不存在';
        });
        return;
      }

      // Load accounts for lines
      final accountIds = entryWithLines.lines.map((l) => l.accountId).toSet();
      final accounts = <String, Account>{};
      for (final accountId in accountIds) {
        final account = await db.accountsDao.getById(accountId);
        if (account != null) {
          accounts[accountId] = account;
        }
      }

      setState(() {
        _entryWithLines = entryWithLines;
        _accounts = accounts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '加载失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorState(theme)
                    : _buildContent(theme),
          ),

          // Action buttons
          if (!_isLoading && _error == null && _entryWithLines != null)
            _buildActionButtons(theme, bottomPadding),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final entry = _entryWithLines!.entry;
    final lines = _entryWithLines!.lines;
    final dateFormat = DateFormat('yyyy年MM月dd日');

    // Calculate totals
    double totalDebits = 0;
    double totalCredits = 0;
    for (final line in lines) {
      final debit = line.debitDenom != 0
          ? line.debitNum / line.debitDenom
          : line.debitNum.toDouble();
      final credit = line.creditDenom != 0
          ? line.creditNum / line.creditDenom
          : line.creditNum.toDouble();
      totalDebits += debit;
      totalCredits += credit;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(theme, entry),
          const SizedBox(height: 20),

          // Status and date
          _buildStatusRow(theme, entry, dateFormat),
          const SizedBox(height: 16),

          // Description
          if (entry.description != null && entry.description!.isNotEmpty) ...[
            Text(
              '摘要',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              entry.description!,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Reference
          if (entry.reference != null && entry.reference!.isNotEmpty) ...[
            _buildInfoRow(
              theme,
              label: '参考号',
              value: entry.reference!,
              icon: Icons.tag,
            ),
            const SizedBox(height: 12),
          ],

          // Notes
          if (entry.notes != null && entry.notes!.isNotEmpty) ...[
            _buildInfoRow(
              theme,
              label: '备注',
              value: entry.notes!,
              icon: Icons.notes,
            ),
            const SizedBox(height: 16),
          ],

          // Divider
          const Divider(height: 32),

          // Lines header
          Row(
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
                  '${lines.length} 条',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Lines list
          ...lines.asMap().entries.map((entry) {
            return _buildLineItem(theme, entry.key + 1, entry.value);
          }),

          const SizedBox(height: 16),

          // Totals
          _buildTotalsCard(theme, totalDebits, totalCredits),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, JournalEntry entry) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            entry.entryNumber ?? '',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(ThemeData theme, JournalEntry entry, DateFormat dateFormat) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: entry.isPosted
                ? Colors.green.withOpacity(0.15)
                : theme.colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                entry.isPosted ? Icons.check_circle : Icons.edit_document,
                size: 14,
                color: entry.isPosted
                    ? Colors.green
                    : theme.colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: 4),
              Text(
                entry.isPosted ? '已过账' : '草稿',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: entry.isPosted
                      ? Colors.green
                      : theme.colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          Icons.calendar_today,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          dateFormat.format(DateTime.fromMillisecondsSinceEpoch(entry.postDate)),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLineItem(ThemeData theme, int index, JournalEntryLine line) {
    final account = _accounts[line.accountId];
    final accountName = account?.name ?? '未知账户';
    final accountType = account?.accountType ?? '';

    // Calculate amounts
    final debit = line.debitDenom != 0
        ? line.debitNum / line.debitDenom
        : line.debitNum.toDouble();
    final credit = line.creditDenom != 0
        ? line.creditNum / line.creditDenom
        : line.creditNum.toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Index and account
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      accountName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (accountType.isNotEmpty)
                      Text(
                        _getAccountTypeLabel(accountType),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Row 2: Debit/Credit amounts
          const SizedBox(height: 8),
          Row(
            children: [
              // Debit
              Expanded(
                child: debit > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '借 ¥${debit.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'monospace',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // Credit
              Expanded(
                child: credit > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '贷 ¥${credit.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'monospace',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),

          // Memo
          if (line.memo != null && line.memo!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              line.memo!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalsCard(ThemeData theme, double totalDebits, double totalCredits) {
    final isBalanced = (totalDebits - totalCredits).abs() < 0.01;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isBalanced
            ? Colors.green.withOpacity(0.1)
            : theme.colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBalanced
              ? Colors.green.withOpacity(0.3)
              : theme.colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTotalColumn(
                theme,
                label: '借方合计',
                amount: totalDebits,
                color: Colors.orange,
              ),
              Container(
                width: 1,
                height: 40,
                color: theme.colorScheme.outlineVariant,
              ),
              _buildTotalColumn(
                theme,
                label: '贷方合计',
                amount: totalCredits,
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
                color: isBalanced ? Colors.green : theme.colorScheme.error,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isBalanced ? '借贷平衡' : '差额: ¥${(totalDebits - totalCredits).abs().toStringAsFixed(2)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isBalanced ? Colors.green : theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalColumn(
    ThemeData theme, {
    required String label,
    required double amount,
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
            '¥${amount.toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme, double bottomPadding) {
    final entry = _entryWithLines!.entry;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Posted entry: show message
          if (entry.isPosted)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    color: Colors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '已过账凭证不可修改',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

          // Draft entry: show action buttons
          if (!entry.isPosted) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('编辑'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onPost,
                    icon: const Icon(Icons.post_add, size: 18),
                    label: const Text('过账'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: widget.onDelete,
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                label: Text(
                  '删除凭证',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getAccountTypeLabel(String type) {
    const labels = {
      'ASSET': '资产',
      'LIABILITY': '负债',
      'EQUITY': '权益',
      'INCOME': '收入',
      'EXPENSE': '支出',
    };
    return labels[type] ?? type;
  }
}
