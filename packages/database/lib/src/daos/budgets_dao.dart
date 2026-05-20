part of '../database.dart';

/// Data Access Object for budgets.
@DriftAccessor(tables: [Budgets, Splits, Transactions, Accounts])
class BudgetsDao extends DatabaseAccessor<LocalFinanceDatabase> 
    with _$BudgetsDaoMixin, _$TransactionsDaoMixin, _$AccountsDaoMixin {
  BudgetsDao(super.db);

  /// Gets all budgets (not deleted).
  Future<List<Budget>> getAll() {
    return (select(budgets)..where((b) => b.deletedAt.isNull())).get();
  }

  /// Gets a budget by ID.
  Future<Budget?> getById(String id) {
    return (select(budgets)..where((b) => b.id.equals(id))).getSingleOrNull();
  }

  /// Gets active budgets.
  Future<List<Budget>> getActive() {
    return (select(budgets)..where((b) => b.isActive.equals(true) & b.deletedAt.isNull())).get();
  }

  /// Gets budgets for a category.
  Future<List<Budget>> getByCategory(String categoryId) {
    return (select(budgets)..where((b) => b.categoryId.equals(categoryId) & b.deletedAt.isNull())).get();
  }

  /// Creates a new budget.
  Future<String> create(BudgetsCompanion budget) async {
    await into(budgets).insert(budget);
    return budget.id.value;
  }

  /// Updates an existing budget.
  Future<void> updateBudget(BudgetsCompanion budget) async {
    await (update(budgets)..where((b) => b.id.equals(budget.id.value))).write(budget);
  }

  /// Soft deletes a budget.
  Future<void> deleteBudget(String id) async {
    await (update(budgets)..where((b) => b.id.equals(id)))
        .write(BudgetsCompanion(deletedAt: Value(DateTime.now())));
  }

  /// Watches active budgets.
  Stream<List<Budget>> watchActive() {
    return (select(budgets)..where((b) => b.isActive.equals(true) & b.deletedAt.isNull())).watch();
  }

  /// Watches all budgets (not deleted).
  Stream<List<Budget>> watchAll() {
    return (select(budgets)..where((b) => b.deletedAt.isNull())).watch();
  }

  /// Calculate spent amount for budget in current period.
  /// Only counts EXPENSE splits with matching categoryId.
  /// 
  /// Parameters:
  /// - categoryId: The category to filter splits by
  /// - startMs: Start of period in milliseconds since epoch
  /// - endMs: End of period in milliseconds since epoch
  Future<int> calculateSpentAmountNum({
    required String? categoryId,
    required int startMs,
    required int endMs,
  }) async {
    // If no categoryId, sum all expense splits in period
    if (categoryId == null) {
      final query = selectOnly(splits).join([
        innerJoin(transactions, transactions.id.equalsExp(splits.transactionId)),
        innerJoin(accounts, accounts.id.equalsExp(splits.accountId)),
      ])
        ..where(
          transactions.postDate.isBetweenValues(startMs, endMs) &
          accounts.accountType.equals('EXPENSE') &
          transactions.deletedAt.isNull()
        );
      
      final totalValueNum = splits.valueNum.sum();
      query.addColumns([totalValueNum]);
      
      final result = await query.getSingle();
      return result.read(totalValueNum) ?? 0;
    }
    
    // Query: categoryId matches AND postDate in range AND account type is EXPENSE
    final query = selectOnly(splits).join([
      innerJoin(transactions, transactions.id.equalsExp(splits.transactionId)),
      innerJoin(accounts, accounts.id.equalsExp(splits.accountId)),
    ])
      ..where(
        splits.categoryId.equals(categoryId) &
        transactions.postDate.isBetweenValues(startMs, endMs) &
        accounts.accountType.equals('EXPENSE') &
        transactions.deletedAt.isNull()
      );
    
    // Sum valueNum (expense splits have positive value)
    final totalValueNum = splits.valueNum.sum();
    query.addColumns([totalValueNum]);
    
    final result = await query.getSingle();
    return result.read(totalValueNum) ?? 0;
  }

  /// Watch spent amount (reactive updates).
  Stream<int> watchSpentAmountNum({
    required String? categoryId,
    required int startMs,
    required int endMs,
  }) {
    // If no categoryId, sum all expense splits in period
    if (categoryId == null) {
      final query = selectOnly(splits).join([
        innerJoin(transactions, transactions.id.equalsExp(splits.transactionId)),
        innerJoin(accounts, accounts.id.equalsExp(splits.accountId)),
      ])
        ..where(
          transactions.postDate.isBetweenValues(startMs, endMs) &
          accounts.accountType.equals('EXPENSE') &
          transactions.deletedAt.isNull()
        );
      
      final totalValueNum = splits.valueNum.sum();
      query.addColumns([totalValueNum]);
      
      return query.map((row) => row.read(totalValueNum) ?? 0).watchSingle();
    }
    
    final query = selectOnly(splits).join([
      innerJoin(transactions, transactions.id.equalsExp(splits.transactionId)),
      innerJoin(accounts, accounts.id.equalsExp(splits.accountId)),
    ])
      ..where(
        splits.categoryId.equals(categoryId) &
        transactions.postDate.isBetweenValues(startMs, endMs) &
        accounts.accountType.equals('EXPENSE') &
        transactions.deletedAt.isNull()
      );
    
    final totalValueNum = splits.valueNum.sum();
    query.addColumns([totalValueNum]);
    
    return query.map((row) => row.read(totalValueNum) ?? 0).watchSingle();
  }

  /// Get progress percentage (can exceed 1.0 if over budget).
  Future<double> getProgress({
    required int budgetAmountNum,
    required int budgetAmountDenom,
    required String? categoryId,
    required int startMs,
    required int endMs,
  }) async {
    final spentNum = await calculateSpentAmountNum(
      categoryId: categoryId,
      startMs: startMs,
      endMs: endMs,
    );
    final budgetAmount = budgetAmountNum / budgetAmountDenom;
    if (budgetAmount <= 0) return 0.0;
    final spent = spentNum / 100.0; // Convert cents to yuan
    return spent / budgetAmount;
  }
}