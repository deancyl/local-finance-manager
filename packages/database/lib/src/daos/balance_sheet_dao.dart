part of '../database.dart';

/// Data Access Object for balance sheet queries with hierarchy support.
///
/// Provides specialized queries for generating balance sheet reports:
/// - Account balances as of a specific date
/// - Hierarchical account structure with aggregated balances
/// - Liquidity-based grouping (current/non-current)
/// - Multi-currency support with conversion
@DriftAccessor(tables: [Accounts, Splits, Transactions, Commodities])
class BalanceSheetDao extends DatabaseAccessor<LocalFinanceDatabase> with _$BalanceSheetDaoMixin {
  BalanceSheetDao(super.db);

  /// Gets account balances as of a specific date for balance sheet.
  ///
  /// Returns hierarchical balance data with:
  /// - Account info (id, name, type, liquidity)
  /// - Balance numerator and denominator
  /// - Parent account reference
  ///
  /// Filters out:
  /// - Deleted transactions
  /// - Hidden accounts
  /// - Transactions after the as-of date
  Future<List<BalanceSheetAccountData>> getAccountBalancesAsOfDate(DateTime asOfDate) async {
    final asOfDateMs = asOfDate.millisecondsSinceEpoch;

    final query = selectOnly(accounts)
      ..join([
        leftOuterJoin(
          splits,
          splits.accountId.equalsExp(accounts.id),
        ),
        leftOuterJoin(
          transactions,
          transactions.id.equalsExp(splits.transactionId) &
              transactions.deletedAt.isNull() &
              transactions.postDate.isSmallerOrEqualValue(asOfDateMs),
        ),
      ])
      ..where(accounts.isHidden.equals(false));

    // Add columns
    query.addColumns([
      accounts.id,
      accounts.name,
      accounts.accountType,
      accounts.parentId,
      accounts.commodityId,
      accounts.liquidityType,
      splits.valueNum.sum(),
      splits.valueDenom,
    ]);

    // Group by account
    query.groupBy([
      accounts.id,
      accounts.name,
      accounts.accountType,
      accounts.parentId,
      accounts.commodityId,
      accounts.liquidityType,
      splits.valueDenom,
    ]);

    final results = await query.get();

    return results.map((row) {
      return BalanceSheetAccountData(
        accountId: row.read(accounts.id)!,
        accountName: row.read(accounts.name)!,
        accountType: row.read(accounts.accountType)!,
        parentId: row.read(accounts.parentId),
        commodityId: row.read(accounts.commodityId)!,
        liquidityType: row.read(accounts.liquidityType) ?? 'current',
        balanceNum: row.read(splits.valueNum.sum()) ?? 0,
        denom: row.read(splits.valueDenom) ?? 1,
      );
    }).toList();
  }

  /// Gets accounts by type with their balances as of a specific date.
  ///
  /// Parameters:
  /// - [accountType]: The account type to filter (ASSET, LIABILITY, EQUITY)
  /// - [asOfDate]: The date for which to calculate balances
  ///
  /// Returns list of accounts with balances for the specified type.
  Future<List<BalanceSheetAccountData>> getAccountsByType(
    String accountType,
    DateTime asOfDate,
  ) async {
    final balances = await getAccountBalancesAsOfDate(asOfDate);
    return balances.where((b) => b.accountType == accountType).toList();
  }

  /// Gets hierarchical account structure for a specific account type.
  ///
  /// Returns accounts organized in a tree structure with:
  /// - Root accounts at the top level
  /// - Child accounts nested under their parents
  /// - Aggregated balances for parent accounts
  ///
  /// Parameters:
  /// - [accountType]: The account type to build hierarchy for
  /// - [asOfDate]: The date for which to calculate balances
  Future<List<BalanceSheetHierarchyNode>> getAccountHierarchy(
    String accountType,
    DateTime asOfDate,
  ) async {
    // Get all accounts of this type
    final accountsData = await (select(accounts)
          ..where((a) =>
              a.accountType.equals(accountType) &
              a.isHidden.equals(false)))
        .get();

    // Get balances
    final balances = await getAccountBalancesAsOfDate(asOfDate);
    final balanceMap = <String, BalanceSheetAccountData>{
      for (final b in balances.where((b) => b.accountType == accountType))
        b.accountId: b,
    };

    // Build account map
    final accountMap = <String, Account>{
      for (final a in accountsData) a.id: a,
    };

    // Find root accounts (no parent or parent is of different type)
    final rootAccounts = accountsData.where((a) {
      if (a.parentId == null) return true;
      final parent = accountMap[a.parentId];
      return parent == null || parent.accountType != accountType;
    }).toList();

    // Build hierarchy recursively
    return rootAccounts.map((account) {
      return _buildHierarchyNode(
        account,
        accountMap,
        balanceMap,
        accountType,
      );
    }).toList();
  }

  /// Recursively builds a hierarchy node with children.
  BalanceSheetHierarchyNode _buildHierarchyNode(
    Account account,
    Map<String, Account> accountMap,
    Map<String, BalanceSheetAccountData> balanceMap,
    String accountType,
  ) {
    // Find children
    final children = accountMap.values
        .where((a) =>
            a.parentId == account.id &&
            a.accountType == accountType &&
            !a.isHidden)
        .toList();

    // Build child nodes recursively
    final childNodes = children
        .map((child) => _buildHierarchyNode(
              child,
              accountMap,
              balanceMap,
              accountType,
            ))
        .toList();

    // Get balance for this account
    final balance = balanceMap[account.id];

    // Calculate aggregated balance (this account + children)
    int aggregatedBalanceNum = balance?.balanceNum ?? 0;
    int aggregatedDenom = balance?.denom ?? 1;

    if (childNodes.isNotEmpty) {
      // Find common denominator
      for (final child in childNodes) {
        aggregatedDenom = _lcm(aggregatedDenom, child.denom);
      }

      // Scale and add child balances
      for (final child in childNodes) {
        final scale = aggregatedDenom ~/ child.denom;
        aggregatedBalanceNum += child.aggregatedBalanceNum * scale;
      }
    }

    return BalanceSheetHierarchyNode(
      accountId: account.id,
      accountName: account.name,
      accountType: account.accountType,
      parentId: account.parentId,
      commodityId: account.commodityId,
      liquidityType: account.liquidityType ?? 'current',
      balanceNum: balance?.balanceNum ?? 0,
      denom: balance?.denom ?? 1,
      aggregatedBalanceNum: aggregatedBalanceNum,
      aggregatedDenom: aggregatedDenom,
      children: childNodes.isEmpty ? null : childNodes,
    );
  }

  /// Gets balances grouped by liquidity type.
  ///
  /// Returns a map with:
  /// - 'current': List of current assets/liabilities
  /// - 'non_current': List of non-current assets/liabilities
  ///
  /// Parameters:
  /// - [accountType]: The account type (ASSET or LIABILITY)
  /// - [asOfDate]: The date for which to calculate balances
  Future<Map<String, List<BalanceSheetAccountData>>> getBalancesByLiquidity(
    String accountType,
    DateTime asOfDate,
  ) async {
    final balances = await getAccountsByType(accountType, asOfDate);

    final result = <String, List<BalanceSheetAccountData>>{
      'current': [],
      'non_current': [],
    };

    for (final balance in balances) {
      if (balance.liquidityType == 'current') {
        result['current']!.add(balance);
      } else {
        result['non_current']!.add(balance);
      }
    }

    return result;
  }

  /// Gets retained earnings (income - expenses) as of a specific date.
  ///
  /// This is used to calculate the "本期利润" (current period profit)
  /// which is automatically added to the equity section.
  ///
  /// Parameters:
  /// - [asOfDate]: The date for which to calculate retained earnings
  ///
  /// Returns the net income (income - expenses) as of the date.
  Future<RetainedEarningsData> getRetainedEarnings(DateTime asOfDate) async {
    final asOfDateMs = asOfDate.millisecondsSinceEpoch;

    // Get income balances
    final incomeQuery = selectOnly(splits)
      ..join([
        innerJoin(accounts, accounts.id.equalsExp(splits.accountId)),
        innerJoin(
          transactions,
          transactions.id.equalsExp(splits.transactionId) &
              transactions.deletedAt.isNull() &
              transactions.postDate.isSmallerOrEqualValue(asOfDateMs),
        ),
      ])
      ..where(accounts.accountType.equals('INCOME'));

    incomeQuery.addColumns([splits.valueNum.sum(), splits.valueDenom]);
    incomeQuery.groupBy([splits.valueDenom]);

    final incomeResults = await incomeQuery.get();
    int incomeNum = 0;
    int incomeDenom = 1;
    for (final row in incomeResults) {
      incomeDenom = _lcm(incomeDenom, row.read(splits.valueDenom) ?? 1);
    }
    for (final row in incomeResults) {
      final scale = incomeDenom ~/ (row.read(splits.valueDenom) ?? 1);
      incomeNum += (row.read(splits.valueNum.sum()) ?? 0) * scale;
    }

    // Get expense balances
    final expenseQuery = selectOnly(splits)
      ..join([
        innerJoin(accounts, accounts.id.equalsExp(splits.accountId)),
        innerJoin(
          transactions,
          transactions.id.equalsExp(splits.transactionId) &
              transactions.deletedAt.isNull() &
              transactions.postDate.isSmallerOrEqualValue(asOfDateMs),
        ),
      ])
      ..where(accounts.accountType.equals('EXPENSE'));

    expenseQuery.addColumns([splits.valueNum.sum(), splits.valueDenom]);
    expenseQuery.groupBy([splits.valueDenom]);

    final expenseResults = await expenseQuery.get();
    int expenseNum = 0;
    int expenseDenom = 1;
    for (final row in expenseResults) {
      expenseDenom = _lcm(expenseDenom, row.read(splits.valueDenom) ?? 1);
    }
    for (final row in expenseResults) {
      final scale = expenseDenom ~/ (row.read(splits.valueDenom) ?? 1);
      expenseNum += (row.read(splits.valueNum.sum()) ?? 0) * scale;
    }

    // Calculate retained earnings: Income - Expense
    // In double-entry:
    // - Income accounts normally have credit balances (positive = revenue)
    // - Expense accounts normally have debit balances (positive = expense)
    // Retained earnings = Income credit balance - Expense debit balance

    final commonDenom = _lcm(incomeDenom, expenseDenom);
    final incomeScaled = incomeNum * (commonDenom ~/ incomeDenom);
    final expenseScaled = expenseNum * (commonDenom ~/ expenseDenom);

    // Income is credit (negative in our system), Expense is debit (positive)
    // Net income = -incomeNum - expenseNum (since income is stored as negative)
    final retainedEarningsNum = -incomeScaled - expenseScaled;

    return RetainedEarningsData(
      incomeNum: incomeScaled.abs(),
      expenseNum: expenseScaled.abs(),
      retainedEarningsNum: retainedEarningsNum,
      denom: commonDenom,
    );
  }

  /// Gets commodity info for currency conversion.
  ///
  /// Returns commodity mnemonic and decimal places for formatting.
  Future<Commodity?> getCommodity(String commodityId) async {
    return (select(commodities)..where((c) => c.id.equals(commodityId)))
        .getSingleOrNull();
  }

  /// Watches account balances as of a specific date.
  ///
  /// Returns a stream that emits whenever balances change.
  Stream<List<BalanceSheetAccountData>> watchAccountBalancesAsOfDate(DateTime asOfDate) {
    final asOfDateMs = asOfDate.millisecondsSinceEpoch;

    final query = selectOnly(accounts)
      ..join([
        leftOuterJoin(
          splits,
          splits.accountId.equalsExp(accounts.id),
        ),
        leftOuterJoin(
          transactions,
          transactions.id.equalsExp(splits.transactionId) &
              transactions.deletedAt.isNull() &
              transactions.postDate.isSmallerOrEqualValue(asOfDateMs),
        ),
      ])
      ..where(accounts.isHidden.equals(false));

    query.addColumns([
      accounts.id,
      accounts.name,
      accounts.accountType,
      accounts.parentId,
      accounts.commodityId,
      accounts.liquidityType,
      splits.valueNum.sum(),
      splits.valueDenom,
    ]);

    query.groupBy([
      accounts.id,
      accounts.name,
      accounts.accountType,
      accounts.parentId,
      accounts.commodityId,
      accounts.liquidityType,
      splits.valueDenom,
    ]);

    return query.map((row) {
      return BalanceSheetAccountData(
        accountId: row.read(accounts.id)!,
        accountName: row.read(accounts.name)!,
        accountType: row.read(accounts.accountType)!,
        parentId: row.read(accounts.parentId),
        commodityId: row.read(accounts.commodityId)!,
        liquidityType: row.read(accounts.liquidityType) ?? 'current',
        balanceNum: row.read(splits.valueNum.sum()) ?? 0,
        denom: row.read(splits.valueDenom) ?? 1,
      );
    }).watch();
  }

  /// Calculate the Least Common Multiple of two numbers.
  int _lcm(int a, int b) {
    if (a == 0 || b == 0) return 1;
    return (a * b).abs() ~/ _gcd(a, b);
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

/// Account data for balance sheet with balance information.
class BalanceSheetAccountData {
  final String accountId;
  final String accountName;
  final String accountType;
  final String? parentId;
  final String commodityId;
  final String liquidityType;
  final int balanceNum;
  final int denom;

  const BalanceSheetAccountData({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    this.parentId,
    required this.commodityId,
    required this.liquidityType,
    required this.balanceNum,
    required this.denom,
  });

  /// Gets the balance as a decimal value.
  double get balance => balanceNum / denom.toDouble();

  /// Returns true if this is a current asset/liability.
  bool get isCurrent => liquidityType == 'current';

  /// Returns true if this is a non-current asset/liability.
  bool get isNonCurrent => liquidityType == 'non_current';
}

/// Hierarchical node for balance sheet account structure.
class BalanceSheetHierarchyNode {
  final String accountId;
  final String accountName;
  final String accountType;
  final String? parentId;
  final String commodityId;
  final String liquidityType;
  final int balanceNum;
  final int denom;
  final int aggregatedBalanceNum;
  final int aggregatedDenom;
  final List<BalanceSheetHierarchyNode>? children;

  const BalanceSheetHierarchyNode({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    this.parentId,
    required this.commodityId,
    required this.liquidityType,
    required this.balanceNum,
    required this.denom,
    required this.aggregatedBalanceNum,
    required this.aggregatedDenom,
    this.children,
  });

  /// Gets the balance as a decimal value.
  double get balance => balanceNum / denom.toDouble();

  /// Gets the aggregated balance as a decimal value.
  double get aggregatedBalance => aggregatedBalanceNum / aggregatedDenom.toDouble();

  /// Returns true if this node has children.
  bool get hasChildren => children != null && children!.isNotEmpty;

  /// Returns true if this is a current asset/liability.
  bool get isCurrent => liquidityType == 'current';

  /// Returns true if this is a non-current asset/liability.
  bool get isNonCurrent => liquidityType == 'non_current';
}

/// Retained earnings data (income - expenses).
class RetainedEarningsData {
  final int incomeNum;
  final int expenseNum;
  final int retainedEarningsNum;
  final int denom;

  const RetainedEarningsData({
    required this.incomeNum,
    required this.expenseNum,
    required this.retainedEarningsNum,
    required this.denom,
  });

  /// Gets income as a decimal value.
  double get income => incomeNum / denom.toDouble();

  /// Gets expense as a decimal value.
  double get expense => expenseNum / denom.toDouble();

  /// Gets retained earnings as a decimal value.
  double get retainedEarnings => retainedEarningsNum / denom.toDouble();
}
