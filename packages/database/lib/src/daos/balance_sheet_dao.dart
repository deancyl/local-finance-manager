part of '../database.dart';

/// Data Access Object for balance sheet queries with hierarchy support.
///
/// Provides specialized queries for generating balance sheet reports:
/// - Account balances as of a specific date
/// - Hierarchical account structure with aggregated balances
/// - Liquidity-based grouping (current/non-current)
/// - Multi-currency support with conversion
/// - Double-entry bookkeeping support from journal entries
@DriftAccessor(tables: [Accounts, Splits, Transactions, Commodities, JournalEntries, JournalEntryLines])
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

  /// Gets balance sheet data from posted journal entries for double-entry bookkeeping.
  ///
  /// This method calculates account balances using the journal entries
  /// (double-entry bookkeeping approach) instead of splits (single-entry).
  ///
  /// Parameters:
  /// - [asOfDate]: The date for which to calculate balances
  ///
  /// Returns balance sheet data with:
  /// - Assets calculated from posted journal entry debit/credit lines
  /// - Liabilities calculated from posted journal entry lines
  /// - Equity calculated from posted journal entry lines plus retained earnings
  /// - Validation status (whether Assets = Liabilities + Equity)
  ///
  /// Calculation logic:
  /// - Assets: Debit increases, Credit decreases → Balance = Debits - Credits
  /// - Liabilities: Credit increases, Debit decreases → Balance = Credits - Debits
  /// - Equity: Credit increases, Debit decreases → Balance = Credits - Debits
  Future<BalanceSheetFromJournalData> getBalanceSheetFromJournalEntries({
    required DateTime asOfDate,
  }) async {
    final asOfDateMs = asOfDate.millisecondsSinceEpoch;

    // Query posted journal entry lines for balance sheet accounts
    final query = selectOnly(journalEntryLines)
      ..join([
        innerJoin(journalEntries, journalEntries.id.equalsExp(journalEntryLines.journalEntryId) &
            journalEntries.isPosted.equals(true) &
            journalEntries.postDate.isSmallerOrEqualValue(asOfDateMs) &
            journalEntries.deletedAt.isNull()),
        innerJoin(accounts, accounts.id.equalsExp(journalEntryLines.accountId) &
            accounts.isHidden.equals(false) &
            (accounts.accountType.equals('ASSET') |
             accounts.accountType.equals('LIABILITY') |
             accounts.accountType.equals('EQUITY'))),
      ]);

    // Add columns for aggregation
    query.addColumns([
      accounts.id,
      accounts.name,
      accounts.accountType,
      accounts.parentId,
      accounts.commodityId,
      accounts.liquidityType,
      journalEntryLines.debitNum.sum(),
      journalEntryLines.debitDenom,
      journalEntryLines.creditNum.sum(),
      journalEntryLines.creditDenom,
    ]);

    // Group by account
    query.groupBy([
      accounts.id,
      accounts.name,
      accounts.accountType,
      accounts.parentId,
      accounts.commodityId,
      accounts.liquidityType,
      journalEntryLines.debitDenom,
      journalEntryLines.creditDenom,
    ]);

    final results = await query.get();

    // Process results into account balances
    final assetBalances = <BalanceSheetAccountBalance>[];
    final liabilityBalances = <BalanceSheetAccountBalance>[];
    final equityBalances = <BalanceSheetAccountBalance>[];

    for (final row in results) {
      final accountType = row.read(accounts.accountType)!;
      final debitNum = row.read(journalEntryLines.debitNum.sum()) ?? 0;
      final creditNum = row.read(journalEntryLines.creditNum.sum()) ?? 0;
      final debitDenom = row.read(journalEntryLines.debitDenom) ?? 1;
      final creditDenom = row.read(journalEntryLines.creditDenom) ?? 1;

      // Calculate balance based on account type
      // Assets: Debit increases → Balance = Debits - Credits (positive = asset value)
      // Liabilities/Equity: Credit increases → Balance = Credits - Debits (positive = obligation)
      final commonDenom = _lcm(debitDenom, creditDenom);
      final debitScaled = debitNum * (commonDenom ~/ debitDenom);
      final creditScaled = creditNum * (commonDenom ~/ creditDenom);

      int balanceNum;
      if (accountType == 'ASSET') {
        // Asset balance: Debits - Credits (positive = more assets)
        balanceNum = debitScaled - creditScaled;
      } else {
        // Liability/Equity balance: Credits - Debits (positive = more obligations/equity)
        balanceNum = creditScaled - debitScaled;
      }

      final balance = BalanceSheetAccountBalance(
        accountId: row.read(accounts.id)!,
        accountName: row.read(accounts.name)!,
        accountType: accountType,
        parentId: row.read(accounts.parentId),
        commodityId: row.read(accounts.commodityId)!,
        liquidityType: row.read(accounts.liquidityType) ?? 'current',
        debitNum: debitScaled,
        creditNum: creditScaled,
        balanceNum: balanceNum,
        denom: commonDenom,
      );

      switch (accountType) {
        case 'ASSET':
          assetBalances.add(balance);
          break;
        case 'LIABILITY':
          liabilityBalances.add(balance);
          break;
        case 'EQUITY':
          equityBalances.add(balance);
          break;
      }
    }

    // Calculate retained earnings from income statement
    final retainedEarnings = await getRetainedEarnings(asOfDate);

    // Add retained earnings to equity section
    if (retainedEarnings.retainedEarningsNum != 0) {
      equityBalances.add(BalanceSheetAccountBalance(
        accountId: 'retained_earnings',
        accountName: '未分配利润 (Retained Earnings)',
        accountType: 'EQUITY',
        parentId: null,
        commodityId: 'CNY',
        liquidityType: 'current',
        debitNum: 0,
        creditNum: retainedEarnings.retainedEarningsNum > 0 ? retainedEarnings.retainedEarningsNum : 0,
        balanceNum: retainedEarnings.retainedEarningsNum,
        denom: retainedEarnings.denom,
      ));
    }

    // Calculate totals for validation
    int totalAssetsNum = 0;
    int totalLiabilitiesNum = 0;
    int totalEquityNum = 0;
    int assetsDenom = 1;
    int liabilitiesDenom = 1;
    int equityDenom = 1;

    // Find common denominators
    for (final balance in assetBalances) {
      assetsDenom = _lcm(assetsDenom, balance.denom);
    }
    for (final balance in liabilityBalances) {
      liabilitiesDenom = _lcm(liabilitiesDenom, balance.denom);
    }
    for (final balance in equityBalances) {
      equityDenom = _lcm(equityDenom, balance.denom);
    }

    // Calculate totals
    for (final balance in assetBalances) {
      final scale = assetsDenom ~/ balance.denom;
      totalAssetsNum += balance.balanceNum * scale;
    }
    for (final balance in liabilityBalances) {
      final scale = liabilitiesDenom ~/ balance.denom;
      totalLiabilitiesNum += balance.balanceNum * scale;
    }
    for (final balance in equityBalances) {
      final scale = equityDenom ~/ balance.denom;
      totalEquityNum += balance.balanceNum * scale;
    }

    // Common denominator for validation
    final validationDenom = _lcm(assetsDenom, _lcm(liabilitiesDenom, equityDenom));
    final assetsScaled = totalAssetsNum * (validationDenom ~/ assetsDenom);
    final liabilitiesScaled = totalLiabilitiesNum * (validationDenom ~/ liabilitiesDenom);
    final equityScaled = totalEquityNum * (validationDenom ~/ equityDenom);

    // Validate: Assets = Liabilities + Equity
    final differenceNum = assetsScaled - (liabilitiesScaled + equityScaled);
    final isBalanced = differenceNum.abs() < 1; // Allow small rounding difference

    return BalanceSheetFromJournalData(
      asOfDate: asOfDate,
      assetBalances: assetBalances,
      liabilityBalances: liabilityBalances,
      equityBalances: equityBalances,
      totalAssetsNum: assetsScaled,
      totalLiabilitiesNum: liabilitiesScaled,
      totalEquityNum: equityScaled,
      denom: validationDenom,
      isBalanced: isBalanced,
      differenceNum: differenceNum.abs(),
      retainedEarnings: retainedEarnings,
      dataSource: 'double_entry',
    );
  }

  /// Gets account hierarchy from journal entries for balance sheet display.
  ///
  /// Parameters:
  /// - [accountType]: The account type (ASSET, LIABILITY, or EQUITY)
  /// - [asOfDate]: The date for which to calculate balances
  ///
  /// Returns hierarchical structure with aggregated balances for parent accounts.
  Future<List<BalanceSheetHierarchyFromJournalNode>> getAccountHierarchyFromJournalEntries(
    String accountType,
    DateTime asOfDate,
  ) async {
    // Get the balance sheet data
    final balanceSheetData = await getBalanceSheetFromJournalEntries(asOfDate: asOfDate);

    // Get all accounts of this type
    final accountsData = await (select(accounts)
          ..where((a) =>
              a.accountType.equals(accountType) &
              a.isHidden.equals(false)))
        .get();

    // Build account map
    final accountMap = <String, Account>{
      for (final a in accountsData) a.id: a,
    };

    // Build balance map from journal entry calculation
    final balanceMap = <String, BalanceSheetAccountBalance>{};
    final balances = accountType == 'ASSET'
        ? balanceSheetData.assetBalances
        : accountType == 'LIABILITY'
            ? balanceSheetData.liabilityBalances
            : balanceSheetData.equityBalances;

    for (final b in balances) {
      balanceMap[b.accountId] = b;
    }

    // Find root accounts
    final rootAccounts = accountsData.where((a) {
      if (a.parentId == null) return true;
      final parent = accountMap[a.parentId];
      return parent == null || parent.accountType != accountType;
    }).toList();

    // Build hierarchy recursively
    return rootAccounts.map((account) {
      return _buildHierarchyFromJournalNode(
        account,
        accountMap,
        balanceMap,
        accountType,
      );
    }).toList();
  }

  /// Recursively builds hierarchy node from journal entry data.
  BalanceSheetHierarchyFromJournalNode _buildHierarchyFromJournalNode(
    Account account,
    Map<String, Account> accountMap,
    Map<String, BalanceSheetAccountBalance> balanceMap,
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
        .map((child) => _buildHierarchyFromJournalNode(
              child,
              accountMap,
              balanceMap,
              accountType,
            ))
        .toList();

    // Get balance for this account
    final balance = balanceMap[account.id];

    // Calculate aggregated balance
    int aggregatedBalanceNum = balance?.balanceNum ?? 0;
    int aggregatedDebitNum = balance?.debitNum ?? 0;
    int aggregatedCreditNum = balance?.creditNum ?? 0;
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
        aggregatedDebitNum += child.aggregatedDebitNum * scale;
        aggregatedCreditNum += child.aggregatedCreditNum * scale;
      }
    }

    return BalanceSheetHierarchyFromJournalNode(
      accountId: account.id,
      accountName: account.name,
      accountType: account.accountType,
      parentId: account.parentId,
      commodityId: account.commodityId,
      liquidityType: account.liquidityType ?? 'current',
      debitNum: balance?.debitNum ?? 0,
      creditNum: balance?.creditNum ?? 0,
      balanceNum: balance?.balanceNum ?? 0,
      denom: balance?.denom ?? 1,
      aggregatedBalanceNum: aggregatedBalanceNum,
      aggregatedDebitNum: aggregatedDebitNum,
      aggregatedCreditNum: aggregatedCreditNum,
      aggregatedDenom: aggregatedDenom,
      children: childNodes.isEmpty ? null : childNodes,
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

/// Balance sheet account balance from journal entries.
class BalanceSheetAccountBalance {
  final String accountId;
  final String accountName;
  final String accountType;
  final String? parentId;
  final String commodityId;
  final String liquidityType;
  final int debitNum;
  final int creditNum;
  final int balanceNum;
  final int denom;

  const BalanceSheetAccountBalance({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    this.parentId,
    required this.commodityId,
    required this.liquidityType,
    required this.debitNum,
    required this.creditNum,
    required this.balanceNum,
    required this.denom,
  });

  /// Gets the balance as a decimal value.
  double get balance => balanceNum / denom.toDouble();

  /// Gets the debit amount as a decimal value.
  double get debit => debitNum / denom.toDouble();

  /// Gets the credit amount as a decimal value.
  double get credit => creditNum / denom.toDouble();

  /// Returns true if this is a current asset/liability.
  bool get isCurrent => liquidityType == 'current';

  /// Returns true if this is a non-current asset/liability.
  bool get isNonCurrent => liquidityType == 'non_current';
}

/// Complete balance sheet data from journal entries.
class BalanceSheetFromJournalData {
  final DateTime asOfDate;
  final List<BalanceSheetAccountBalance> assetBalances;
  final List<BalanceSheetAccountBalance> liabilityBalances;
  final List<BalanceSheetAccountBalance> equityBalances;
  final int totalAssetsNum;
  final int totalLiabilitiesNum;
  final int totalEquityNum;
  final int denom;
  final bool isBalanced;
  final int differenceNum;
  final RetainedEarningsData retainedEarnings;
  final String dataSource;

  const BalanceSheetFromJournalData({
    required this.asOfDate,
    required this.assetBalances,
    required this.liabilityBalances,
    required this.equityBalances,
    required this.totalAssetsNum,
    required this.totalLiabilitiesNum,
    required this.totalEquityNum,
    required this.denom,
    required this.isBalanced,
    required this.differenceNum,
    required this.retainedEarnings,
    required this.dataSource,
  });

  /// Gets total assets as a decimal value.
  double get totalAssets => totalAssetsNum / denom.toDouble();

  /// Gets total liabilities as a decimal value.
  double get totalLiabilities => totalLiabilitiesNum / denom.toDouble();

  /// Gets total equity as a decimal value.
  double get totalEquity => totalEquityNum / denom.toDouble();

  /// Gets the difference as a decimal value.
  double get difference => differenceNum / denom.toDouble();

  /// Gets the difference as a decimal value.
  double get differenceDecimal => difference;
}

/// Hierarchical node for balance sheet from journal entries.
class BalanceSheetHierarchyFromJournalNode {
  final String accountId;
  final String accountName;
  final String accountType;
  final String? parentId;
  final String commodityId;
  final String liquidityType;
  final int debitNum;
  final int creditNum;
  final int balanceNum;
  final int denom;
  final int aggregatedBalanceNum;
  final int aggregatedDebitNum;
  final int aggregatedCreditNum;
  final int aggregatedDenom;
  final List<BalanceSheetHierarchyFromJournalNode>? children;

  const BalanceSheetHierarchyFromJournalNode({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    this.parentId,
    required this.commodityId,
    required this.liquidityType,
    required this.debitNum,
    required this.creditNum,
    required this.balanceNum,
    required this.denom,
    required this.aggregatedBalanceNum,
    required this.aggregatedDebitNum,
    required this.aggregatedCreditNum,
    required this.aggregatedDenom,
    this.children,
  });

  /// Gets the balance as a decimal value.
  double get balance => balanceNum / denom.toDouble();

  /// Gets the aggregated balance as a decimal value.
  double get aggregatedBalance => aggregatedBalanceNum / aggregatedDenom.toDouble();

  /// Gets the aggregated debit as a decimal value.
  double get aggregatedDebit => aggregatedDebitNum / aggregatedDenom.toDouble();

  /// Gets the aggregated credit as a decimal value.
  double get aggregatedCredit => aggregatedCreditNum / aggregatedDenom.toDouble();

  /// Returns true if this node has children.
  bool get hasChildren => children != null && children!.isNotEmpty;

  /// Returns true if this is a current asset/liability.
  bool get isCurrent => liquidityType == 'current';

  /// Returns true if this is a non-current asset/liability.
  bool get isNonCurrent => liquidityType == 'non_current';
}
