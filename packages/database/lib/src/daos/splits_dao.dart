part of '../database.dart';

/// Data Access Object for splits with balance query methods.
@DriftAccessor(tables: [Splits, Accounts, Transactions])
class SplitsDao extends DatabaseAccessor<LocalFinanceDatabase> with _$SplitsDaoMixin {
  SplitsDao(super.db);

  /// Gets all splits for an account within a date range.
  /// Filters out splits from deleted transactions.
  Future<List<Split>> getSplitsForAccount(
    String accountId, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final query = select(splits).join([
      innerJoin(transactions, transactions.id.equalsExp(splits.transactionId)),
    ])
      ..where(splits.accountId.equals(accountId) & transactions.deletedAt.isNull());

    // Apply date range filter
    if (startDate != null) {
      final startMs = startDate.millisecondsSinceEpoch;
      query.where(transactions.postDate.isBiggerOrEqualValue(startMs));
    }
    if (endDate != null) {
      final endMs = endDate.millisecondsSinceEpoch;
      query.where(transactions.postDate.isSmallerOrEqualValue(endMs));
    }

    query.orderBy([OrderingTerm.asc(transactions.postDate)]);

    return query.map((row) => row.readTable(splits)).get();
  }

  /// Gets account balances grouped by account for trial balance calculation.
  /// Returns raw balance data (numerator and denominator) to avoid floating point.
  /// Filters out deleted transactions.
  Future<List<AccountBalanceRaw>> getAccountBalances({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = selectOnly(splits)
      ..join([
        innerJoin(accounts, accounts.id.equalsExp(splits.accountId)),
        innerJoin(transactions, transactions.id.equalsExp(splits.transactionId)),
      ])
      ..where(transactions.deletedAt.isNull());

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
      splits.valueNum.sum(),
      splits.valueDenom,
    ]);

    // Group by account
    query.groupBy([accounts.id, accounts.name, accounts.accountType, splits.valueDenom]);

    final results = await query.get();

    return results.map((row) {
      return AccountBalanceRaw(
        accountId: row.read(accounts.id)!,
        accountName: row.read(accounts.name)!,
        accountType: row.read(accounts.accountType)!,
        totalNum: row.read(splits.valueNum.sum()) ?? 0,
        valueDenom: row.read(splits.valueDenom) ?? 1,
      );
    }).toList();
  }

  /// Gets total debits and credits for balance verification.
  /// Returns raw totals (numerator and denominator) to avoid floating point.
  /// Filters out deleted transactions.
  Future<BalanceTotals> getBalanceTotals({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = selectOnly(splits)
      ..join([
        innerJoin(transactions, transactions.id.equalsExp(splits.transactionId)),
      ])
      ..where(transactions.deletedAt.isNull());

    // Apply date range filter
    if (startDate != null) {
      final startMs = startDate.millisecondsSinceEpoch;
      query.where(transactions.postDate.isBiggerOrEqualValue(startMs));
    }
    if (endDate != null) {
      final endMs = endDate.millisecondsSinceEpoch;
      query.where(transactions.postDate.isSmallerOrEqualValue(endMs));
    }

    // Add columns for sum aggregation
    query.addColumns([
      splits.valueNum.sum(),
    ]);

    final result = await query.getSingle();
    final totalNum = result.read(splits.valueNum.sum()) ?? 0;

    // In double-entry bookkeeping:
    // - Debits are positive values (assets, expenses)
    // - Credits are negative values (liabilities, income, equity)
    // Total debits = sum of positive values
    // Total credits = absolute sum of negative values
    return BalanceTotals(
      totalDebitsNum: totalNum > 0 ? totalNum : 0,
      totalCreditsNum: totalNum < 0 ? totalNum.abs() : 0,
      valueDenom: 1,
    );
  }

  /// Gets account balances as of a specific date (for balance sheet).
  /// Returns raw balance data (numerator and denominator) to avoid floating point.
  /// Filters out deleted transactions.
  Future<List<AccountBalanceRaw>> getAccountBalancesAsOfDate(DateTime asOfDate) async {
    final asOfDateMs = asOfDate.millisecondsSinceEpoch;

    final query = selectOnly(splits)
      ..join([
        innerJoin(accounts, accounts.id.equalsExp(splits.accountId)),
        innerJoin(transactions, transactions.id.equalsExp(splits.transactionId)),
      ])
      ..where(transactions.deletedAt.isNull() & transactions.postDate.isSmallerOrEqualValue(asOfDateMs));

    // Add columns for grouping and aggregation
    query.addColumns([
      accounts.id,
      accounts.name,
      accounts.accountType,
      splits.valueNum.sum(),
      splits.valueDenom,
    ]);

    // Group by account
    query.groupBy([accounts.id, accounts.name, accounts.accountType, splits.valueDenom]);

    final results = await query.get();

    return results.map((row) {
      return AccountBalanceRaw(
        accountId: row.read(accounts.id)!,
        accountName: row.read(accounts.name)!,
        accountType: row.read(accounts.accountType)!,
        totalNum: row.read(splits.valueNum.sum()) ?? 0,
        valueDenom: row.read(splits.valueDenom) ?? 1,
      );
    }).toList();
  }

  /// Gets account balances grouped by liquidity type (for balance sheet).
  /// Returns a map of liquidity type to list of account balances.
  /// Filters out deleted transactions.
  Future<Map<LiquidityType, List<AccountBalanceRaw>>> getBalancesByLiquidity(DateTime asOfDate) async {
    final balances = await getAccountBalancesAsOfDate(asOfDate);

    // Get liquidity type for each account
    final Map<LiquidityType, List<AccountBalanceRaw>> result = {
      LiquidityType.current: [],
      LiquidityType.fixed: [],
    };

    // Query account liquidity types
    final accountQuery = select(accounts)..where((tbl) => accounts.id.isIn(balances.map((b) => b.accountId)));
    final accountResults = await accountQuery.get();

    final liquidityMap = <String, String?>{};
    for (final account in accountResults) {
      liquidityMap[account.id] = account.liquidityType;
    }

    // Group balances by liquidity type
    for (final balance in balances) {
      final liquidityStr = liquidityMap[balance.accountId] ?? 'current';
      final liquidity = LiquidityType.fromString(liquidityStr);
      result[liquidity]!.add(balance);
    }

    return result;
  }

  /// Gets splits with transaction info for general ledger report.
  /// Returns splits for a specific account with transaction details.
  /// Filters out deleted transactions.
  Future<List<GeneralLedgerSplitData>> getSplitsWithTransactionInfo(
    String accountId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = selectOnly(splits)
      ..join([
        innerJoin(transactions, transactions.id.equalsExp(splits.transactionId)),
      ])
      ..where(splits.accountId.equals(accountId) & transactions.deletedAt.isNull());

    // Apply date range filter
    if (startDate != null) {
      final startMs = startDate.millisecondsSinceEpoch;
      query.where(transactions.postDate.isBiggerOrEqualValue(startMs));
    }
    if (endDate != null) {
      final endMs = endDate.millisecondsSinceEpoch;
      query.where(transactions.postDate.isSmallerOrEqualValue(endMs));
    }

    // Add columns
    query.addColumns([
      splits.id,
      splits.transactionId,
      splits.accountId,
      transactions.postDate,
      transactions.description,
      transactions.referenceNum,
      splits.memo,
      splits.valueNum,
      splits.valueDenom,
    ]);

    // Order by date ascending for running balance calculation
    query.orderBy([OrderingTerm.asc(transactions.postDate)]);

    final results = await query.get();

    return results.map((row) {
      return GeneralLedgerSplitData(
        splitId: row.read(splits.id)!,
        transactionId: row.read(splits.transactionId)!,
        accountId: row.read(splits.accountId)!,
        postDate: row.read(transactions.postDate)!,
        description: row.read(transactions.description),
        reference: row.read(transactions.referenceNum),
        memo: row.read(splits.memo),
        valueNum: row.read(splits.valueNum)!,
        valueDenom: row.read(splits.valueDenom) ?? 1,
      );
    }).toList();
  }

  /// Gets all splits with transaction info before a specific date.
  /// Used for calculating opening balance.
  Future<List<GeneralLedgerSplitData>> getSplitsWithTransactionInfoBeforeDate(
    String accountId,
    DateTime beforeDate,
  ) async {
    final beforeMs = beforeDate.millisecondsSinceEpoch;

    final query = selectOnly(splits)
      ..join([
        innerJoin(transactions, transactions.id.equalsExp(splits.transactionId)),
      ])
      ..where(
        splits.accountId.equals(accountId) &
        transactions.deletedAt.isNull() &
        transactions.postDate.isSmallerThanValue(beforeMs),
      );

    // Add columns
    query.addColumns([
      splits.id,
      splits.transactionId,
      splits.accountId,
      transactions.postDate,
      transactions.description,
      transactions.referenceNum,
      splits.memo,
      splits.valueNum,
      splits.valueDenom,
    ]);

    final results = await query.get();

    return results.map((row) {
      return GeneralLedgerSplitData(
        splitId: row.read(splits.id)!,
        transactionId: row.read(splits.transactionId)!,
        accountId: row.read(splits.accountId)!,
        postDate: row.read(transactions.postDate)!,
        description: row.read(transactions.description),
        reference: row.read(transactions.referenceNum),
        memo: row.read(splits.memo),
        valueNum: row.read(splits.valueNum)!,
        valueDenom: row.read(splits.valueDenom) ?? 1,
      );
    }).toList();
  }
}

/// Raw account balance data with integer values to avoid floating point.
class AccountBalanceRaw {
  final String accountId;
  final String accountName;
  final String accountType;
  final int totalNum;
  final int valueDenom;

  AccountBalanceRaw({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.totalNum,
    required this.valueDenom,
  });

  /// Gets the balance as a decimal value (for display purposes only).
  double get balance => totalNum / valueDenom.toDouble();
}

/// Balance totals for trial balance verification.
class BalanceTotals {
  final int totalDebitsNum;
  final int totalCreditsNum;
  final int valueDenom;

  BalanceTotals({
    required this.totalDebitsNum,
    required this.totalCreditsNum,
    required this.valueDenom,
  });

  /// Gets total debits as decimal (for display purposes only).
  double get totalDebits => totalDebitsNum / valueDenom.toDouble();

  /// Gets total credits as decimal (for display purposes only).
  double get totalCredits => totalCreditsNum / valueDenom.toDouble();

  /// Checks if debits equal credits (balanced).
  bool get isBalanced => totalDebitsNum == totalCreditsNum;
}

/// Liquidity type for balance sheet classification.
enum LiquidityType {
  current,
  fixed;

  /// Parses a string to LiquidityType.
  static LiquidityType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'current':
        return LiquidityType.current;
      case 'fixed':
        return LiquidityType.fixed;
      default:
        return LiquidityType.current;
    }
  }
}

/// Split data with transaction info for general ledger report.
class GeneralLedgerSplitData {
  final String splitId;
  final String transactionId;
  final String accountId;
  final int postDate;
  final String? description;
  final String? reference;
  final String? memo;
  final int valueNum;
  final int valueDenom;

  GeneralLedgerSplitData({
    required this.splitId,
    required this.transactionId,
    required this.accountId,
    required this.postDate,
    this.description,
    this.reference,
    this.memo,
    required this.valueNum,
    required this.valueDenom,
  });

  /// Returns the date as DateTime.
  DateTime get date => DateTime.fromMillisecondsSinceEpoch(postDate);

  /// Returns the value as a decimal (for display purposes).
  double get value => valueNum / valueDenom.toDouble();
}
