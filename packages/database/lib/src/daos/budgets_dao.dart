import 'package:drift/drift.dart';

import '../tables/budgets.dart';
import '../database.dart';

part 'budgets_dao.g.dart';

/// Data Access Object for budgets.
@DriftAccessor(tables: [Budgets])
class BudgetsDao extends DatabaseAccessor<LocalFinanceDatabase> with _$BudgetsDaoMixin {
  BudgetsDao(super.db);

  /// Gets all budgets.
  Future<List<Budget>> getAll() => select(budgets).get();

  /// Gets a budget by ID.
  Future<Budget?> getById(String id) {
    return (select(budgets)..where((b) => b.id.equals(id))).getSingleOrNull();
  }

  /// Gets active budgets.
  Future<List<Budget>> getActive() {
    return (select(budgets)..where((b) => b.isActive.equals(true))).get();
  }

  /// Gets budgets for a category.
  Future<List<Budget>> getByCategory(String categoryId) {
    return (select(budgets)..where((b) => b.categoryId.equals(categoryId))).get();
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

  /// Deletes a budget.
  Future<void> deleteBudget(String id) async {
    await (delete(budgets)..where((b) => b.id.equals(id))).go();
  }

  /// Watches active budgets.
  Stream<List<Budget>> watchActive() {
    return (select(budgets)..where((b) => b.isActive.equals(true))).watch();
  }
}