part of '../database.dart';

/// Data Access Object for investment transactions.
@DriftAccessor(tables: [InvestmentTransactions])
class InvestmentTransactionsDao extends DatabaseAccessor<LocalFinanceDatabase>
    with _$InvestmentTransactionsDaoMixin {
  InvestmentTransactionsDao(super.db);

  /// Get all transactions for an account.
  Future<List<InvestmentTransaction>> getTransactionsForAccount(
    String accountId, {
    int? limit,
    int? offset,
  }) {
    final query = select(investmentTransactions)
      ..where((t) => t.accountId.equals(accountId))
      ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)]);
    
    if (limit != null) {
      query.limit(limit, offset: offset);
    }
    
    return query.get();
  }

  /// Get all transactions for a specific holding.
  Future<List<InvestmentTransaction>> getTransactionsForHolding(
    String holdingId,
  ) {
    return (select(investmentTransactions)
          ..where((t) => t.holdingId.equals(holdingId))
          ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)]))
        .get();
  }

  /// Watch transactions for an account.
  Stream<List<InvestmentTransaction>> watchTransactionsForAccount(
    String accountId,
  ) {
    return (select(investmentTransactions)
          ..where((t) => t.accountId.equals(accountId))
          ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)]))
        .watch();
  }

  /// Get a single transaction by ID.
  Future<InvestmentTransaction?> getTransactionById(String id) {
    return (select(investmentTransactions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert a new transaction.
  Future<void> insertTransaction(InvestmentTransactionsCompanion transaction) {
    return into(investmentTransactions).insert(transaction);
  }

  /// Update an existing transaction.
  Future<void> updateTransaction(InvestmentTransactionsCompanion transaction) {
    return (update(investmentTransactions)
          ..where((t) => t.id.equals(transaction.id.value)))
        .write(transaction);
  }

  /// Delete a transaction.
  Future<void> deleteTransaction(String id) {
    return (delete(investmentTransactions)..where((t) => t.id.equals(id)))
        .go();
  }

  /// Get transactions by type for an account.
  Future<List<InvestmentTransaction>> getTransactionsByType(
    String accountId,
    String transactionType,
  ) {
    return (select(investmentTransactions)
          ..where((t) =>
              t.accountId.equals(accountId) &
              t.transactionType.equals(transactionType))
          ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)]))
        .get();
  }

  /// Get dividend transactions for an account.
  Future<List<InvestmentTransaction>> getDividendTransactions(
    String accountId,
  ) {
    return getTransactionsByType(accountId, 'dividend');
  }

  /// Get buy transactions for an account.
  Future<List<InvestmentTransaction>> getBuyTransactions(String accountId) {
    return getTransactionsByType(accountId, 'buy');
  }

  /// Get sell transactions for an account.
  Future<List<InvestmentTransaction>> getSellTransactions(String accountId) {
    return getTransactionsByType(accountId, 'sell');
  }

  /// Get total dividends received for an account.
  Future<double> getTotalDividends(String accountId) async {
    final dividends = await getDividendTransactions(accountId);
    double total = 0;
    for (final d in dividends) {
      total += d.amountNum / d.amountDenom;
    }
    return total;
  }

  /// Get transactions for a date range.
  Future<List<InvestmentTransaction>> getTransactionsForDateRange(
    String accountId,
    DateTime start,
    DateTime end,
  ) {
    return (select(investmentTransactions)
          ..where((t) =>
              t.accountId.equals(accountId) &
              t.transactionDate.isBiggerOrEqualValue(start.millisecondsSinceEpoch) &
              t.transactionDate.isSmallerOrEqualValue(end.millisecondsSinceEpoch))
          ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)]))
        .get();
  }

  /// Calculate realized gains for an account (from sell transactions).
  Future<double> getRealizedGains(String accountId) async {
    final sellTransactions = await getSellTransactions(accountId);
    double realizedGain = 0;
    
    for (final sell in sellTransactions) {
      if (sell.quantityNum != null && sell.priceNum != null) {
        final saleProceeds = (sell.amountNum / sell.amountDenom);
        // Note: Realized gain calculation would need to match with original buy cost
        // This is a simplified version
        realizedGain += saleProceeds;
      }
    }
    
    return realizedGain;
  }
}
