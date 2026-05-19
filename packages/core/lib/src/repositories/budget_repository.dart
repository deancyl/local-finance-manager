import '../models/budget.dart';

/// Repository interface for budget operations.
abstract class BudgetRepository {
  /// Gets all budgets.
  Future<List<Budget>> getAll();

  /// Gets a budget by ID.
  Future<Budget?> getById(String id);

  /// Gets active budgets.
  Future<List<Budget>> getActive();

  /// Gets budgets for a category.
  Future<List<Budget>> getByCategory(String categoryId);

  /// Gets budgets for the current period.
  Future<List<Budget>> getCurrentPeriod();

  /// Creates a new budget.
  Future<Budget> create(Budget budget);

  /// Updates an existing budget.
  Future<Budget> update(Budget budget);

  /// Deletes a budget.
  Future<void> delete(String id);

  /// Gets the spent amount for a budget in the current period.
  Future<double> getSpentAmount(String budgetId);

  /// Gets the remaining amount for a budget in the current period.
  Future<double> getRemainingAmount(String budgetId);

  /// Gets the progress percentage for a budget.
  Future<double> getProgress(String budgetId);
}