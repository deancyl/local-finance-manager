import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:core/core.dart' show BudgetPeriod, BudgetPeriodCalculator;

import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

/// Provider for all budgets (not deleted).
final budgetsProvider = StreamProvider<List<Budget>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.budgetsDao.watchAll();
});

/// Provider for active budgets only.
final activeBudgetsProvider = Provider<List<Budget>>((ref) {
  final budgets = ref.watch(budgetsProvider);
  return budgets.when(
    data: (list) => list.where((b) => b.isActive).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Helper model for budget with spending data.
class BudgetWithSpending {
  final Budget budget;
  final double spentAmount;
  final double remainingAmount;
  final double progress;
  
  BudgetWithSpending({
    required this.budget,
    required this.spentAmount,
    required this.remainingAmount,
    required this.progress,
  });
}

/// Provider for budget with calculated spending.
final budgetWithSpendingProvider = FutureProvider.family<BudgetWithSpending, String>((ref, budgetId) async {
  final db = ref.watch(databaseProvider);
  final budget = await db.budgetsDao.getById(budgetId);
  if (budget == null) throw Exception('Budget not found');
  
  // Calculate period bounds
  final now = DateTime.now();
  final (start, end) = BudgetPeriodCalculator.getCurrentPeriodBounds(
    _parseBudgetPeriod(budget.period),
    now,
    customStart: _intToDateTime(budget.startDate),
    customEnd: budget.endDate != null ? _intToDateTime(budget.endDate!) : null,
  );
  
  final startMs = start.millisecondsSinceEpoch;
  final endMs = end.millisecondsSinceEpoch;
  
  // Calculate spending
  final spentNum = await db.budgetsDao.calculateSpentAmountNum(
    categoryId: budget.categoryId,
    startMs: startMs,
    endMs: endMs,
  );
  
  final spent = spentNum / 100.0; // Convert cents to yuan
  final budgetAmount = budget.amountNum / budget.amountDenom;
  final remaining = budgetAmount - spent;
  final progress = budgetAmount > 0 ? spent / budgetAmount : 0.0;
  
  return BudgetWithSpending(
    budget: budget,
    spentAmount: spent,
    remainingAmount: remaining,
    progress: progress,
  );
});

/// Watch budget spending (reactive).
final budgetSpendingStreamProvider = StreamProvider.family<double, Budget>((ref, budget) async* {
  final db = ref.watch(databaseProvider);
  
  // Calculate period bounds
  final now = DateTime.now();
  final (start, end) = BudgetPeriodCalculator.getCurrentPeriodBounds(
    _parseBudgetPeriod(budget.period),
    now,
    customStart: _intToDateTime(budget.startDate),
    customEnd: budget.endDate != null ? _intToDateTime(budget.endDate!) : null,
  );
  
  final startMs = start.millisecondsSinceEpoch;
  final endMs = end.millisecondsSinceEpoch;
  
  yield* db.budgetsDao.watchSpentAmountNum(
    categoryId: budget.categoryId,
    startMs: startMs,
    endMs: endMs,
  ).map((spentNum) => spentNum / 100.0);
});

/// Budget state notifier for CRUD operations.
class BudgetNotifier extends StateNotifier<AsyncValue<void>> {
  final LocalFinanceDatabase _db;

  BudgetNotifier(this._db) : super(const AsyncValue.data(null));

  Future<void> createBudget({
    required String name,
    required int amountNum,
    required String currencyId,
    required String period,
    required int startDate,
    String? categoryId,
    int? endDate,
    bool isActive = true,
    bool alertEnabled = true,
    bool alertAt50 = true,
    bool alertAt75 = true,
    bool alertAt90 = true,
    bool alertAt100 = true,
  }) async {
    state = const AsyncValue.loading();
    try {
      final id = const Uuid().v4();
      final now = DateTime.now();
      
      await _db.into(_db.budgets).insert(
        BudgetsCompanion.insert(
          id: id,
          name: name,
          categoryId: drift.Value(categoryId),
          amountNum: amountNum,
          amountDenom: drift.Value(100), // Store as cents
          currencyId: currencyId,
          period: period,
          startDate: startDate,
          endDate: drift.Value(endDate),
          isActive: drift.Value(isActive),
          alertEnabled: drift.Value(alertEnabled),
          alertAt50: drift.Value(alertAt50),
          alertAt75: drift.Value(alertAt75),
          alertAt90: drift.Value(alertAt90),
          alertAt100: drift.Value(alertAt100),
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now,
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateBudget(Budget budget) async {
    state = const AsyncValue.loading();
    try {
      await (_db.update(_db.budgets)..where((b) => b.id.equals(budget.id))).write(
        BudgetsCompanion(
          name: drift.Value(budget.name),
          categoryId: drift.Value(budget.categoryId),
          amountNum: drift.Value(budget.amountNum),
          amountDenom: drift.Value(budget.amountDenom),
          period: drift.Value(budget.period),
          startDate: drift.Value(budget.startDate),
          endDate: drift.Value(budget.endDate),
          isActive: drift.Value(budget.isActive),
          alertEnabled: drift.Value(budget.alertEnabled),
          alertAt50: drift.Value(budget.alertAt50),
          alertAt75: drift.Value(budget.alertAt75),
          alertAt90: drift.Value(budget.alertAt90),
          alertAt100: drift.Value(budget.alertAt100),
          updatedAt: drift.Value(DateTime.now()),
          version: drift.Value(budget.version + 1),
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteBudget(String id) async {
    state = const AsyncValue.loading();
    try {
      // Soft delete (set deletedAt)
      await (_db.update(_db.budgets)..where((b) => b.id.equals(id))).write(
        BudgetsCompanion(
          deletedAt: drift.Value(DateTime.now()),
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final budgetNotifierProvider = StateNotifierProvider<BudgetNotifier, AsyncValue<void>>((ref) {
  final db = ref.watch(databaseProvider);
  return BudgetNotifier(db);
});

// Helper functions
BudgetPeriod _parseBudgetPeriod(String period) {
  switch (period) {
    case 'MONTHLY':
      return BudgetPeriod.monthly;
    case 'YEARLY':
      return BudgetPeriod.yearly;
    case 'CUSTOM':
      return BudgetPeriod.custom;
    default:
      return BudgetPeriod.monthly;
  }
}

DateTime _intToDateTime(int ms) {
  return DateTime.fromMillisecondsSinceEpoch(ms);
}