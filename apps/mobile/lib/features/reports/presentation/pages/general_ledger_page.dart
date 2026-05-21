import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:core/core.dart';
import 'package:decimal/decimal.dart';

import '../../data/general_ledger_provider.dart';

/// General Ledger report page with account selector and date range filtering.
///
/// Displays all transactions for a selected account with running balance.
class GeneralLedgerPage extends ConsumerStatefulWidget {
  final String? initialAccountId;

  const GeneralLedgerPage({super.key, this.initialAccountId});

  @override
  ConsumerState<GeneralLedgerPage> createState() => _GeneralLedgerPageState();
}

class _GeneralLedgerPageState extends ConsumerState<GeneralLedgerPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    // Set default date range to current year
    final now = DateTime.now();
    _startDate = DateTime(now.year, 1, 1);
    _endDate = DateTime(now.year, 12, 31, 23, 59, 59, 999);
    _selectedAccountId = widget.initialAccountId;

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (_selectedAccountId != null) {
      await ref.read(generalLedgerProvider.notifier).setAccount(_selectedAccountId);
      await ref.read(generalLedgerProvider.notifier).setDateRange(_startDate, _endDate);
    }
  }

  Future<void> _selectAccount() async {
    final accountsAsync = ref.read(generalLedgerAccountsProvider);

    accountsAsync.when(
      data: (accounts) async {
        final selected = await showDialog<Account>(
          context: context,
          builder: (context) => _AccountSelectorDialog(
            accounts: accounts,
            selectedAccountId: _selectedAccountId,
          ),
        );

        if (selected != null) {
          setState(() {
            _selectedAccountId = selected.id;
          });
          await _loadData();
        }
      },
      loading: () {},
      error: (_, __) {},
    );
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day);
      });
      await _loadData();
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null) {
      setState(() {
        _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59, 999);
      });
      await _loadData();
    }
  }

  Future<void> _handleRefresh() async {
    await ref.read(generalLedgerProvider.notifier).refresh();
  }

  void _handleExport() {
    // TODO: Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导出功能开发中...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final generalLedgerAsync = ref.watch(generalLedgerProvider);
    final accountsAsync = ref.watch(generalLedgerAccountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('总账'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _handleExport,
            tooltip: '导出',
          ),
        ],
      ),
      body: Column(
        children: [
          // Account selector and date range
          _buildFilters(context, accountsAsync),

          // Content
          Expanded(
            child: generalLedgerAsync.when(
              data: (generalLedger) {
                if (generalLedger == null) {
                  return _buildSelectAccountPrompt(context);
                }
                return _buildContent(context, generalLedger);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorState(context, error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context, AsyncValue<List<Account>> accountsAsync) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Account selector
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '选择账户',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _selectAccount,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outline,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: accountsAsync.when(
                      data: (accounts) {
                        final selected = accounts.where((a) => a.id == _selectedAccountId).firstOrNull;
                        return Text(
                          selected != null
                              ? '${selected.code != null ? '${selected.code} - ' : ''}${selected.name}'
                              : '请选择账户',
                          style: theme.textTheme.bodyMedium,
                        );
                      },
                      loading: () => const Text('加载中...'),
                      error: (_, __) => const Text('请选择账户'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Date range selector
          Row(
            children: [
              Icon(
                Icons.date_range,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '日期范围',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Start date
              Expanded(
                child: InkWell(
                  onTap: _selectStartDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _startDate != null
                              ? dateFormat.format(_startDate!)
                              : '开始日期',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // End date
              Expanded(
                child: InkWell(
                  onTap: _selectEndDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _endDate != null
                              ? dateFormat.format(_endDate!)
                              : '结束日期',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectAccountPrompt(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '请选择账户查看总账',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '选择一个账户以查看该账户的所有交易记录',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, GeneralLedger generalLedger) {
    if (generalLedger.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 12, bottom: 12),
        child: Column(
          children: [
            // Account header
            _buildAccountHeader(context, generalLedger),

            const SizedBox(height: 12),

            // Summary card
            _buildSummaryCard(context, generalLedger),

            const SizedBox(height: 12),

            // Entries table
            _buildEntriesTable(context, generalLedger),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountHeader(BuildContext context, GeneralLedger generalLedger) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getAccountTypeIcon(generalLedger.accountType),
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  generalLedger.accountName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${generalLedger.accountCode ?? ''} ${generalLedger.accountType.labelZh}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, GeneralLedger generalLedger) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '期间汇总',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Opening balance
              Expanded(
                child: _buildSummaryItem(
                  context,
                  label: '期初余额',
                  amount: generalLedger.openingBalanceDecimal,
                  color: theme.colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 12),
              // Total debits
              Expanded(
                child: _buildSummaryItem(
                  context,
                  label: '借方合计',
                  amount: generalLedger.totalDebitsDecimal,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              // Total credits
              Expanded(
                child: _buildSummaryItem(
                  context,
                  label: '贷方合计',
                  amount: generalLedger.totalCreditsDecimal,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 12),
              // Closing balance
              Expanded(
                child: _buildSummaryItem(
                  context,
                  label: '期末余额',
                  amount: generalLedger.closingBalanceDecimal,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context, {
    required String label,
    required Decimal amount,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '¥${_formatDecimal(amount)}',
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEntriesTable(BuildContext context, GeneralLedger generalLedger) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MM-dd');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    '日期',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '摘要',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    '借方',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    '贷方',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    '余额',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table rows
          ...generalLedger.entries.asMap().entries.map((entry) {
            final index = entry.key;
            final ledgerEntry = entry.value;
            final isEven = index % 2 == 0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isEven
                    ? theme.colorScheme.surface
                    : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(
                      dateFormat.format(ledgerEntry.date),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ledgerEntry.description ?? '',
                          style: theme.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (ledgerEntry.reference != null)
                          Text(
                            '凭证: ${ledgerEntry.reference}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: ledgerEntry.isDebit
                        ? Text(
                            _formatDecimal(ledgerEntry.debitDecimal),
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : const SizedBox(),
                  ),
                  SizedBox(
                    width: 70,
                    child: ledgerEntry.isCredit
                        ? Text(
                            _formatDecimal(ledgerEntry.creditDecimal),
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.secondary,
                            ),
                          )
                        : const SizedBox(),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      _formatDecimal(ledgerEntry.balanceDecimal),
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Bottom rounded corner
          if (generalLedger.entries.isNotEmpty)
            const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '该期间无交易记录',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '所选账户在指定日期范围内没有交易',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _handleRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getAccountTypeIcon(AccountType type) {
    switch (type) {
      case AccountType.asset:
        return Icons.account_balance_wallet;
      case AccountType.liability:
        return Icons.credit_card;
      case AccountType.equity:
        return Icons.pie_chart;
      case AccountType.income:
        return Icons.trending_up;
      case AccountType.expense:
        return Icons.trending_down;
    }
  }

  String _formatDecimal(Decimal value) {
    final str = value.toString();
    if (str.contains('.')) {
      final parts = str.split('.');
      final decimal = parts[1].padRight(2, '0').substring(0, 2);
      return '${parts[0]}.$decimal';
    }
    return '$str.00';
  }
}

/// Account selector dialog for general ledger.
class _AccountSelectorDialog extends StatelessWidget {
  final List<Account> accounts;
  final String? selectedAccountId;

  const _AccountSelectorDialog({
    required this.accounts,
    this.selectedAccountId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Group accounts by type
    final accountsByType = <AccountType, List<Account>>{};
    for (final account in accounts) {
      accountsByType.putIfAbsent(account.accountType, () => []).add(account);
    }

    const typeOrder = [
      AccountType.asset,
      AccountType.liability,
      AccountType.equity,
      AccountType.income,
      AccountType.expense,
    ];

    return AlertDialog(
      title: const Text('选择账户'),
      contentPadding: const EdgeInsets.only(top: 16, bottom: 8),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView(
          children: typeOrder.map((type) {
            final typeAccounts = accountsByType[type];
            if (typeAccounts == null || typeAccounts.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    type.labelZh,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...typeAccounts.map((account) => ListTile(
                  leading: Icon(
                    _getAccountTypeIcon(type),
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(account.name),
                  subtitle: account.code != null ? Text(account.code!) : null,
                  trailing: selectedAccountId == account.id
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(account),
                )),
                const Divider(),
              ],
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }

  IconData _getAccountTypeIcon(AccountType type) {
    switch (type) {
      case AccountType.asset:
        return Icons.account_balance_wallet;
      case AccountType.liability:
        return Icons.credit_card;
      case AccountType.equity:
        return Icons.pie_chart;
      case AccountType.income:
        return Icons.trending_up;
      case AccountType.expense:
        return Icons.trending_down;
    }
  }
}
