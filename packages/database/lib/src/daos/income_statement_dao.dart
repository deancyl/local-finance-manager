part of '../database.dart';

/// Data Access Object for income statement queries.
///
/// Provides optimized queries for generating income statement reports
/// with period comparison support.
@DriftAccessor(tables: [Splits, Accounts, Transactions])
class IncomeStatementDao extends DatabaseAccessor<LocalFinanceDatabase> with _$IncomeStatementDaoMixin {
  IncomeStatementDao(super.db);

  /// Gets account balances for income statement within a date range.
  ///
  /// Returns balances for INCOME and EXPENSE accounts only.
  /// Uses integer arithmetic to avoid floating point precision issues.
  /// Filters out deleted transactions and placeholder accounts.
  Future<List<IncomeStatementAccountBalance>> getIncomeStatementBalances({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = selectOnly(splits)
      ..join([
        innerJoin(accounts, accounts.id.equalsExp(splits.accountId)),
        innerJoin(transactions, transactions.id.equalsExp(splits.transactionId)),
      ])
      ..where(
        transactions.deletedAt.isNull() &
        accounts.isPlaceholder.equals(false) &
        (accounts.accountType.equals('INCOME') | accounts.accountType.equals('EXPENSE')),
      );

    // Apply date range filter
    if (startDate != null) {
      final startMs = startDate.millisecondsSinceEpoch;
      query.where(transactions.postDate.isBiggerOrEqualValue(startMs));
    }
    if (endDate != null) {
      final endMs = endDate.millisecondsSinceEpoch;
      query.where(transactions.postDate.isSmallerOrEqualValue(endMs));
    }

    // Add columns for grouping and aggregation
    query.addColumns([
      accounts.id,
      accounts.name,
      accounts.accountType,
      accounts.parentId,
      splits.valueNum.sum(),
      splits.valueDenom,
    ]);

    // Group by account
    query.groupBy([accounts.id, accounts.name, accounts.accountType, accounts.parentId, splits.valueDenom]);

    final results = await query.get();

    return results.map((row) {
      final totalNum = row.read(splits.valueNum.sum()) ?? 0;
      // In double-entry bookkeeping:
      // - Income: Credit is positive, Debit is negative
      // - Expense: Debit is positive, Credit is negative
      // For income statement, we want:
      // - Income: positive values represent income (credit - debit)
      // - Expense: positive values represent expense (debit - credit)
      final accountType = row.read(accounts.accountType)!;
      final int incomeAmount;
      final int expenseAmount;

      if (accountType == 'INCOME') {
        // Income account: positive totalNum means credit > debit (income)
        // We negate because income is represented as negative in the DB
        incomeAmount = -totalNum;
        expenseAmount = 0;
      } else {
        // Expense account: positive totalNum means debit > credit (expense)
        incomeAmount = 0;
        expenseAmount = totalNum;
      }

      return IncomeStatementAccountBalance(
        accountId: row.read(accounts.id)!,
        accountName: row.read(accounts.name)!,
        accountType: accountType,
        parentId: row.read(accounts.parentId),
        incomeNum: incomeAmount,
        expenseNum: expenseAmount,
        denom: row.read(splits.valueDenom) ?? 1,
      );
    }).toList();
  }

  /// Gets aggregated totals for income and expenses within a date range.
  ///
  /// Returns a summary with total revenue and total expenses.
  /// Useful for period comparison headers.
  Future<IncomeStatementSummary> getIncomeStatementSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final balances = await getIncomeStatementBalances(
      startDate: startDate,
      endDate: endDate,
    );

    int totalRevenueNum = 0;
    int totalExpenseNum = 0;
    int commonDenom = 1;

    // Find common denominator
    for (final balance in balances) {
      commonDenom = _lcm(commonDenom, balance.denom);
    }

    // Aggregate totals
    for (final balance in balances) {
      final scale = commonDenom ~/ balance.denom;
      totalRevenueNum += balance.incomeNum * scale;
      totalExpenseNum += balance.expenseNum * scale;
    }

    // Net income = Revenue - Expenses
    final netIncomeNum = totalRevenueNum - totalExpenseNum;

    return IncomeStatementSummary(
      totalRevenueNum: totalRevenueNum,
      totalExpenseNum: totalExpenseNum,
      netIncomeNum: netIncomeNum,
      denom: commonDenom,
    );
  }

  /// Gets all income and expense accounts with their hierarchy.
  ///
  /// Returns accounts ordered by type and sort order.
  Future<List<IncomeStatementAccount>> getIncomeExpenseAccounts() async {
    final query = select(accounts)
      ..where((a) =>
          a.accountType.equals('INCOME') | a.accountType.equals('EXPENSE'))
      ..orderBy([(a) => OrderingTerm.asc(a.accountType), (a) => OrderingTerm.asc(a.sortOrder)]);

    final results = await query.get();

    return results.map((acc) => IncomeStatementAccount(
      id: acc.id,
      name: acc.name,
      accountType: acc.accountType,
      parentId: acc.parentId,
      isPlaceholder: acc.isPlaceholder,
      isHidden: acc.isHidden,
      sortOrder: acc.sortOrder,
    )).toList();
  }

  /// Gets monthly income statement data for trend analysis.
  ///
  /// Returns monthly totals for revenue and expenses.
  Future<List<MonthlyIncomeStatement>> getMonthlyIncomeStatement({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startMs = startDate.millisecondsSinceEpoch;
    final endMs = endDate.millisecondsSinceEpoch;

    final query = customSelect(
      '''
      SELECT 
        strftime('%Y-%m', datetime(t.post_date / 1000, 'unixepoch')) AS month_label,
        SUM(CASE WHEN a.account_type = 'INCOME' THEN -s.value_num ELSE 0 END) AS income_num,
        SUM(CASE WHEN a.account_type = 'EXPENSE' THEN s.value_num ELSE 0 END) AS expense_num,
        100 AS denom
      FROM splits s
      INNER JOIN transactions t ON t.id = s.transaction_id
      INNER JOIN accounts a ON a.id = s.account_id
      WHERE t.post_date >= ?1 
        AND t.post_date <= ?2
        AND t.deleted_at IS NULL
        AND a.is_placeholder = 0
        AND (a.account_type = 'INCOME' OR a.account_type = 'EXPENSE')
      GROUP BY month_label
      ORDER BY month_label ASC
      ''',
      variables: [Variable.withInt(startMs), Variable.withInt(endMs)],
      readsFrom: {transactions, splits, accounts},
    );

    final results = await query.get();

    return results.map((row) {
      final incomeNum = row.read<int>('income_num') ?? 0;
      final expenseNum = row.read<int>('expense_num') ?? 0;
      final denom = row.read<int>('denom') ?? 100;

      return MonthlyIncomeStatement(
        monthLabel: row.read<String>('month_label')!,
        revenueNum: incomeNum,
        expenseNum: expenseNum,
        netIncomeNum: incomeNum - expenseNum,
        denom: denom,
      );
    }).toList();
  }

  /// Calculate the Least Common Multiple of two numbers.
  int _lcm(int a, int b) {
    if (a == 0 || b == 0) return 1;
    return (a * b) ~/ _gcd(a, b);
  }

  /// Calculate the Greatest Common Divisor of two numbers.
  int _gcd(int a, int b) {
    a = a.abs();
    b = b.abs();
    while (b != 0) {
      final temp = b;
      b = a % b;
      a = temp;
    }
    return a;
  }
}

/// Account balance for income statement report.
class IncomeStatementAccountBalance {
  final String accountId;
  final String accountName;
  final String accountType;
  final String? parentId;
  final int incomeNum;
  final int expenseNum;
  final int denom;

  IncomeStatementAccountBalance({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    this.parentId,
    required this.incomeNum,
    required this.expenseNum,
    required this.denom,
  });

  /// Gets the income amount as decimal.
  double get income => incomeNum / denom.toDouble();

  /// Gets the expense amount as decimal.
  double get expense => expenseNum / denom.toDouble();
}

/// Summary totals for income statement.
class IncomeStatementSummary {
  final int totalRevenueNum;
  final int totalExpenseNum;
  final int netIncomeNum;
  final int denom;

  IncomeStatementSummary({
    required this.totalRevenueNum,
    required this.totalExpenseNum,
    required this.netIncomeNum,
    required this.denom,
  });

  /// Gets total revenue as decimal.
  double get totalRevenue => totalRevenueNum / denom.toDouble();

  /// Gets total expenses as decimal.
  double get totalExpenses => totalExpenseNum / denom.toDouble();

  /// Gets net income as decimal.
  double get netIncome => netIncomeNum / denom.toDouble();

  /// Returns true if there's a profit.
  bool get isProfit => netIncomeNum > 0;

  /// Returns true if there's a loss.
  bool get isLoss => netIncomeNum < 0;
}

/// Account info for income statement hierarchy.
class IncomeStatementAccount {
  final String id;
  final String name;
  final String accountType;
  final String? parentId;
  final bool isPlaceholder;
  final bool isHidden;
  final int sortOrder;

  IncomeStatementAccount({
    required this.id,
    required this.name,
    required this.accountType,
    this.parentId,
    required this.isPlaceholder,
    required this.isHidden,
    required this.sortOrder,
  });
}

/// Monthly income statement data for trend analysis.
class MonthlyIncomeStatement {
  final String monthLabel;
  final int revenueNum;
  final int expenseNum;
  final int netIncomeNum;
  final int denom;

  MonthlyIncomeStatement({
    required this.monthLabel,
    required this.revenueNum,
    required this.expenseNum,
    required this.netIncomeNum,
    required this.denom,
  });

  /// Gets revenue as decimal.
  double get revenue => revenueNum / denom.toDouble();

  /// Gets expenses as decimal.
  double get expenses => expenseNum / denom.toDouble();

  /// Gets net income as decimal.
  double get netIncome => netIncomeNum / denom.toDouble();
}
