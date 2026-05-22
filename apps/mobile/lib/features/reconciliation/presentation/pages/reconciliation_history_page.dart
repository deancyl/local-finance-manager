import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;

import 'package:core/core.dart';
import 'package:database/database.dart' hide Account;
import '../../data/reconciliation_provider.dart';
import '../../../accounts/data/account_provider.dart';
import 'reconciliation_detail_page.dart';

/// Page showing history of completed reconciliations.
/// 
/// Features:
/// - Account selector to filter by account
/// - List of past reconciliations with dates and balances
/// - Click to view reconciliation details
class ReconciliationHistoryPage extends ConsumerStatefulWidget {
  const ReconciliationHistoryPage({super.key});

  @override
  ConsumerState<ReconciliationHistoryPage> createState() => _ReconciliationHistoryPageState();
}

class _ReconciliationHistoryPageState extends ConsumerState<ReconciliationHistoryPage> {
  String? _selectedAccountId;
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(reconcilableAccountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('对账历史'),
      ),
      body: Column(
        children: [
          // Account selector
          _buildAccountSelector(accounts),
          
          // Reconciliations list
          Expanded(
            child: _selectedAccountId == null
                ? _buildSelectAccountPrompt()
                : _buildReconciliationsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSelector(List<Account> accounts) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: DropdownButtonFormField<String>(
        value: _selectedAccountId,
        decoration: const InputDecoration(
          labelText: '选择账户',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.account_balance_wallet),
        ),
        items: [
          const DropdownMenuItem(
            value: null,
            child: Text('全部账户'),
          ),
          ...accounts.map((account) => DropdownMenuItem(
            value: account.id,
            child: Text(account.name),
          )),
        ],
        onChanged: (value) {
          setState(() {
            _selectedAccountId = value;
          });
        },
      ),
    );
  }

  Widget _buildSelectAccountPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 24),
          Text(
            '选择账户查看对账历史',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '从上方下拉菜单选择一个账户',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReconciliationsList() {
    final db = ref.watch(databaseProvider);
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadReconciliations(db),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text('加载失败: ${snapshot.error}'),
              ],
            ),
          );
        }

        final reconciliations = snapshot.data ?? [];

        if (reconciliations.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          itemCount: reconciliations.length,
          itemBuilder: (context, index) {
            final rec = reconciliations[index];
            return _buildReconciliationTile(rec);
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadReconciliations(LocalFinanceDatabase db) async {
    if (_selectedAccountId == null) {
      return [];
    }

    // Query splits that are reconciled for this account
    // Group by reconcile date to show reconciliation sessions
    final query = db.select(db.splits).join([
      drift.innerJoin(db.transactions, db.transactions.id.equalsExp(db.splits.transactionId)),
      drift.innerJoin(db.accounts, db.accounts.id.equalsExp(db.splits.accountId)),
    ])
      ..where(db.splits.accountId.equals(_selectedAccountId) & 
              db.splits.reconcileState.equals('y') &
              db.splits.reconcileDate.isNotNull())
      ..orderBy([drift.OrderingTerm.desc(db.splits.reconcileDate)]);

    final results = await query.get();

    // Group by reconcile date (same date = same reconciliation session)
    final Map<int, Map<String, dynamic>> sessions = {};
    
    for (final row in results) {
      final split = row.readTable(db.splits);
      final transaction = row.readTable(db.transactions);
      final account = row.readTable(db.accounts);
      
      final reconcileDate = split.reconcileDate;
      if (reconcileDate == null) continue;

      // Group by date (ignore time)
      final dateKey = DateTime.fromMillisecondsSinceEpoch(reconcileDate)
          .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
          .millisecondsSinceEpoch;

      if (!sessions.containsKey(dateKey)) {
        sessions[dateKey] = {
          'reconcileDate': reconcileDate,
          'accountId': account.id,
          'accountName': account.name,
          'splits': <Map<String, dynamic>>[],
          'totalNum': 0,
          'totalDenom': 1,
        };
      }

      final session = sessions[dateKey]!;
      (session['splits'] as List).add({
        'splitId': split.id,
        'transactionId': transaction.id,
        'description': transaction.description,
        'postDate': transaction.postDate,
        'valueNum': split.valueNum,
        'valueDenom': split.valueDenom,
        'memo': split.memo,
      });

      // Add to total using integer arithmetic
      final currentNum = session['totalNum'] as int;
      final currentDenom = session['totalDenom'] as int;
      final commonDenom = currentDenom * split.valueDenom;
      session['totalNum'] = currentNum * split.valueDenom + split.valueNum * currentDenom;
      session['totalDenom'] = commonDenom;
    }

    // Convert to list and sort by date descending
    return sessions.values.toList()
      ..sort((a, b) => (b['reconcileDate'] as int).compareTo(a['reconcileDate'] as int));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 24),
          Text(
            '暂无对账记录',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '该账户还没有完成过对账',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReconciliationTile(Map<String, dynamic> rec) {
    final reconcileDate = DateTime.fromMillisecondsSinceEpoch(rec['reconcileDate'] as int);
    final totalNum = rec['totalNum'] as int;
    final totalDenom = rec['totalDenom'] as int;
    final total = totalNum / totalDenom.toDouble();
    final splits = rec['splits'] as List;
    final accountName = rec['accountName'] as String;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.check_circle,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          _dateFormat.format(reconcileDate),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('账户: $accountName'),
            Text('已对账交易: ${splits.length} 笔'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _currencyFormat.format(total),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: total >= 0 ? Colors.green : Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '对账余额',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReconciliationDetailPage(
                reconciliationData: rec,
              ),
            ),
          );
        },
      ),
    );
  }
}
