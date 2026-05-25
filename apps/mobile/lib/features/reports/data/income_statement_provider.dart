import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decimal/decimal.dart';

import 'package:database/database.dart' hide Account, AccountBalanceRaw;
import 'package:core/core.dart';
import '../../accounts/data/account_provider.dart';

// ============================================================
// DATE RANGE STATE PROVIDERS
// ============================================================

/// Start date for income statement filtering (null = all time)
final incomeStatementStartDateProvider = StateProvider<DateTime?>((ref) => null);

/// End date for income statement filtering (null = up to now)
final incomeStatementEndDateProvider = StateProvider<DateTime?>((ref) => null);

/// Period comparison type provider
final incomeStatementComparisonTypeProvider = StateProvider<PeriodComparisonType>((ref) => PeriodComparisonType.none);

/// Custom comparison start date (for custom period comparison)
final incomeStatementComparisonStartDateProvider = StateProvider<DateTime?>((ref) => null);

/// Custom comparison end date (for custom period comparison)
final incomeStatementComparisonEndDateProvider = StateProvider<DateTime?>((ref) => null);

// ============================================================
// INCOME STATEMENT DATA PROVIDER
// ============================================================

/// Provider for income statement data with date range filtering and period comparison
final incomeStatementProvider = AsyncNotifierProvider<IncomeStatementNotifier, IncomeStatementWithComparison?>(
  () => IncomeStatementNotifier(),
);

/// Notifier for managing income statement state
class IncomeStatementNotifier extends AsyncNotifier<IncomeStatementWithComparison?> {
  late final LocalFinanceDatabase _db;
  late final IncomeStatementCalculator _calculator;

  @override
  IncomeStatementWithComparison? build() {
    _db = ref.watch(databaseProvider);
    _calculator = IncomeStatementCalculator();
    
    // Initial load
    _fetch();
    
    return null;
  }

  /// Fetch income statement data from database
  Future<IncomeStatementWithComparison> _fetch() async {
    final startDate = ref.read(incomeStatementStartDateProvider);
    final endDate = ref.read(incomeStatementEndDateProvider);
    final comparisonType = ref.read(incomeStatementComparisonTypeProvider);

    // Get all accounts
    final accountsData = await _db.accountsDao.getAll();
    
    // Convert database Account to core Account model
    final accounts = accountsData.map((acc) => Account(
      id: acc.id,
      name: acc.name,
      accountType: AccountType.values.firstWhere(
        (e) => e.code == acc.accountType,
        orElse: () => AccountType.asset,
      ),
      parentId: acc.parentId,
      commodityId: acc.commodityId,
      code: acc.code,
      description: acc.description,
      isPlaceholder: acc.isPlaceholder,
      isHidden: acc.isHidden,
      sortOrder: acc.sortOrder,
      createdAt: DateTime.fromMillisecondsSinceEpoch(acc.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(acc.updatedAt),
      version: acc.version,
    )).toList();

    // Get raw balances from the new DAO
    final rawBalances = await _db.incomeStatementDao.getIncomeStatementBalances(
      startDate: startDate,
      endDate: endDate,
    );

    // Convert to core AccountBalanceRaw
    final balances = rawBalances.map((raw) {
      return AccountBalanceRaw(
        accountId: raw.accountId,
        debitNum: raw.expenseNum, // expense is debit
        creditNum: raw.incomeNum, // income is credit
        denom: raw.denom,
      );
    }).toList();

    // Calculate current period income statement
    final currentStatement = await _calculator.calculate(
      accounts: accounts,
      balances: balances,
      startDate: startDate ?? DateTime(1970, 1, 1),
      endDate: endDate ?? DateTime.now(),
    );

    // Calculate comparison period if needed
    IncomeStatement? previousStatement;
    if (comparisonType != PeriodComparisonType.none) {
      final comparisonDates = _getComparisonDates(
        startDate ?? DateTime(1970, 1, 1),
        endDate ?? DateTime.now(),
        comparisonType,
      );

      if (comparisonDates != null) {
        final previousBalances = await _db.incomeStatementDao.getIncomeStatementBalances(
          startDate: comparisonDates.$1,
          endDate: comparisonDates.$2,
        );

        final prevBalances = previousBalances.map((raw) {
          return AccountBalanceRaw(
            accountId: raw.accountId,
            debitNum: raw.expenseNum,
            creditNum: raw.incomeNum,
            denom: raw.denom,
          );
        }).toList();

        previousStatement = await _calculator.calculate(
          accounts: accounts,
          balances: prevBalances,
          startDate: comparisonDates.$1,
          endDate: comparisonDates.$2,
        );
      }
    }

    // Create result with comparison
    final result = IncomeStatementWithComparison(
      current: currentStatement,
      previous: previousStatement,
      comparisonType: comparisonType,
    );

    // Update state
    state = AsyncValue.data(result);
    
    return result;
  }

  /// Get comparison dates based on comparison type
  (DateTime, DateTime)? _getComparisonDates(
    DateTime currentStart,
    DateTime currentEnd,
    PeriodComparisonType comparisonType,
  ) {
    switch (comparisonType) {
      case PeriodComparisonType.none:
        return null;
      case PeriodComparisonType.previousMonth:
        // Previous month with same length as current period
        final periodLength = currentEnd.difference(currentStart);
        final prevEnd = DateTime(currentStart.year, currentStart.month, currentStart.day)
            .subtract(const Duration(seconds: 1));
        final prevStart = prevEnd.subtract(periodLength);
        return (prevStart, prevEnd);
      case PeriodComparisonType.previousQuarter:
        // Same quarter last year
        final quarter = (currentStart.month - 1) ~/ 3;
        final prevYear = currentStart.year - 1;
        final prevStart = DateTime(prevYear, quarter * 3 + 1, 1);
        final prevEnd = DateTime(prevYear, quarter * 3 + 4, 1).subtract(const Duration(seconds: 1));
        return (prevStart, prevEnd);
      case PeriodComparisonType.previousYear:
        // Same period last year
        final prevStart = DateTime(currentStart.year - 1, currentStart.month, currentStart.day);
        final prevEnd = DateTime(currentEnd.year - 1, currentEnd.month, currentEnd.day, 
            currentEnd.hour, currentEnd.minute, currentEnd.second);
        return (prevStart, prevEnd);
      case PeriodComparisonType.custom:
        // Use custom dates from providers
        final customStart = ref.read(incomeStatementComparisonStartDateProvider);
        final customEnd = ref.read(incomeStatementComparisonEndDateProvider);
        if (customStart != null && customEnd != null) {
          return (customStart, customEnd);
        }
        return null;
    }
  }

  /// Refresh income statement data
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      await _fetch();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Set date range and refresh
  Future<void> setDateRange(DateTime? start, DateTime? end) async {
    ref.read(incomeStatementStartDateProvider.notifier).state = start;
    ref.read(incomeStatementEndDateProvider.notifier).state = end;
    await refresh();
  }

  /// Set comparison type and refresh
  Future<void> setComparisonType(PeriodComparisonType type) async {
    ref.read(incomeStatementComparisonTypeProvider.notifier).state = type;
    await refresh();
  }

  /// Set custom comparison dates and refresh
  Future<void> setCustomComparisonDates(DateTime? start, DateTime? end) async {
    ref.read(incomeStatementComparisonStartDateProvider.notifier).state = start;
    ref.read(incomeStatementComparisonEndDateProvider.notifier).state = end;
    await refresh();
  }
}

// ============================================================
// MONTHLY TREND PROVIDER
// ============================================================

/// Provider for monthly income statement trend data
final incomeStatementMonthlyTrendProvider = FutureProvider<List<MonthlyIncomeStatementData>>((ref) async {
  final db = ref.watch(databaseProvider);
  final startDate = ref.watch(incomeStatementStartDateProvider);
  final endDate = ref.watch(incomeStatementEndDateProvider);

  final monthlyData = await db.incomeStatementDao.getMonthlyIncomeStatement(
    startDate: startDate ?? DateTime.now().subtract(const Duration(days: 365)),
    endDate: endDate ?? DateTime.now(),
  );

  return monthlyData.map((data) => MonthlyIncomeStatementData(
    monthLabel: data.monthLabel,
    revenue: (Decimal.fromInt(data.revenueNum) / Decimal.fromInt(data.denom)).toDecimal(),
    expenses: (Decimal.fromInt(data.expenseNum) / Decimal.fromInt(data.denom)).toDecimal(),
    netIncome: (Decimal.fromInt(data.netIncomeNum) / Decimal.fromInt(data.denom)).toDecimal(),
  )).toList();
});

/// Monthly income statement data for charts
class MonthlyIncomeStatementData {
  final String monthLabel;
  final Decimal revenue;
  final Decimal expenses;
  final Decimal netIncome;

  MonthlyIncomeStatementData({
    required this.monthLabel,
    required this.revenue,
    required this.expenses,
    required this.netIncome,
  });
}
