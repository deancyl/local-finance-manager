import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';
import 'package:finance_app/features/recurring/data/recurring_provider.dart';
import 'package:finance_app/features/transactions/data/transaction_provider.dart';

/// Forecast granularity options
enum ForecastGranularity {
  daily,
  weekly,
  monthly,
}

/// A single forecast data point
class ForecastPoint {
  final DateTime date;
  final double projectedBalance;
  final double projectedIncome;
  final double projectedExpense;
  final double confidenceLower;
  final double confidenceUpper;
  final List<ForecastTransaction> transactions;

  ForecastPoint({
    required this.date,
    required this.projectedBalance,
    required this.projectedIncome,
    required this.projectedExpense,
    required this.confidenceLower,
    required this.confidenceUpper,
    required this.transactions,
  });
}

/// A projected transaction in the forecast
class ForecastTransaction {
  final String name;
  final double amount;
  final DateTime date;
  final bool isRecurring;
  final String? recurringId;
  final bool isIncome;

  ForecastTransaction({
    required this.name,
    required this.amount,
    required this.date,
    required this.isRecurring,
    this.recurringId,
    required this.isIncome,
  });
}

/// Alert threshold configuration
class AlertThreshold {
  final double amount;
  final bool isEnabled;

  AlertThreshold({
    required this.amount,
    this.isEnabled = true,
  });
}

/// Complete cash flow forecast result
class CashFlowForecast {
  final List<ForecastPoint> points;
  final double startingBalance;
  final double endingBalance;
  final double totalProjectedIncome;
  final double totalProjectedExpense;
  final int daysCovered;
  final List<AlertEvent> alerts;

  CashFlowForecast({
    required this.points,
    required this.startingBalance,
    required this.endingBalance,
    required this.totalProjectedIncome,
    required this.totalProjectedExpense,
    required this.daysCovered,
    required this.alerts,
  });
}

/// Alert event when balance falls below threshold
class AlertEvent {
  final DateTime date;
  final double balance;
  final double threshold;
  final String message;

  AlertEvent({
    required this.date,
    required this.balance,
    required this.threshold,
    required this.message,
  });
}

/// State for forecast parameters
class ForecastParams {
  final int monthsAhead;
  final ForecastGranularity granularity;
  final AlertThreshold? alertThreshold;

  const ForecastParams({
    this.monthsAhead = 3,
    this.granularity = ForecastGranularity.weekly,
    this.alertThreshold,
  });

  ForecastParams copyWith({
    int? monthsAhead,
    ForecastGranularity? granularity,
    AlertThreshold? alertThreshold,
  }) {
    return ForecastParams(
      monthsAhead: monthsAhead ?? this.monthsAhead,
      granularity: granularity ?? this.granularity,
      alertThreshold: alertThreshold ?? this.alertThreshold,
    );
  }
}

/// Provider for forecast parameters
final forecastParamsProvider = StateProvider<ForecastParams>((ref) {
  return const ForecastParams();
});

/// Provider for cash flow forecast data
final cashFlowForecastProvider = FutureProvider<CashFlowForecast?>((ref) async {
  final params = ref.watch(forecastParamsProvider);
  final db = ref.watch(databaseProvider);
  
  // Get current account balances
  final balancesAsync = ref.watch(accountBalancesProvider);
  final balances = balancesAsync.when(
    data: (b) => b,
    loading: () => <String, double>{},
    error: (_, __) => <String, double>{},
  );
  
  // Get active recurring transactions
  final recurringAsync = ref.watch(activeRecurringTransactionsProvider);
  final recurring = recurringAsync.when(
    data: (r) => r.cast<RecurringTransaction>(),
    loading: () => <RecurringTransaction>[],
    error: (_, __) => <RecurringTransaction>[],
  );
  
  // Get historical transactions for average calculations
  final transactionsAsync = ref.watch(transactionsProvider);
  final transactions = transactionsAsync.when(
    data: (t) => t,
    loading: () => [],
    error: (_, __) => [],
  );
  
  // Get all accounts to determine asset accounts
  final accountsAsync = ref.watch(accountsProvider);
  final accounts = accountsAsync.when(
    data: (a) => a.cast<Account>(),
    loading: () => <Account>[],
    error: (_, __) => <Account>[],
  );
  
  // Calculate starting balance (sum of asset accounts)
  double startingBalance = 0;
  for (final account in accounts) {
    if (account.accountType == 'ASSET' && !account.isPlaceholder) {
      startingBalance += balances[account.id] ?? 0;
    }
  }
  
  // Calculate historical averages for income and expense
  final historicalAverages = await _calculateHistoricalAverages(
    db: db,
    accounts: accounts,
    monthsLookback: 3,
  );
  
  // Generate forecast points
  final forecast = _generateForecast(
    startingBalance: startingBalance,
    recurringTransactions: recurring,
    historicalAverages: historicalAverages,
    params: params,
  );
  
  return forecast;
});

/// Historical average income/expense data
class HistoricalAverages {
  final double averageDailyIncome;
  final double averageDailyExpense;
  final double incomeStdDev;
  final double expenseStdDev;
  
  HistoricalAverages({
    required this.averageDailyIncome,
    required this.averageDailyExpense,
    required this.incomeStdDev,
    required this.expenseStdDev,
  });
}

/// Calculate historical averages from past transactions
Future<HistoricalAverages> _calculateHistoricalAverages({
  required LocalFinanceDatabase db,
  required List<Account> accounts,
  required int monthsLookback,
}) async {
  final now = DateTime.now();
  final startDate = DateTime(now.year, now.month - monthsLookback, 1);
  
  // Get all splits in the lookback period
  final splits = await db.transactionsDao.getAllSplits();
  
  // Create account type lookup
  final accountTypes = <String, String>{
    for (final acc in accounts) acc.id: acc.accountType,
  };
  
  // Calculate daily totals
  final dailyIncome = <DateTime, double>{};
  final dailyExpense = <DateTime, double>{};
  
  for (final split in splits) {
    final transaction = await db.transactionsDao.getById(split.transactionId);
    if (transaction == null) continue;
    
    final postDate = DateTime.fromMillisecondsSinceEpoch(transaction.postDate);
    if (postDate.isBefore(startDate)) continue;
    
    final dateOnly = DateTime(postDate.year, postDate.month, postDate.day);
    final accountType = accountTypes[split.accountId] ?? 'ASSET';
    final amount = split.valueNum.toDouble() / split.valueDenom.toDouble();
    
    if (accountType == 'INCOME') {
      dailyIncome[dateOnly] = (dailyIncome[dateOnly] ?? 0) + amount.abs();
    } else if (accountType == 'EXPENSE') {
      dailyExpense[dateOnly] = (dailyExpense[dateOnly] ?? 0) + amount.abs();
    }
  }
  
  // Calculate averages
  final daysInPeriod = DateTime.now().difference(startDate).inDays + 1;
  final totalIncome = dailyIncome.values.fold(0.0, (sum, v) => sum + v);
  final totalExpense = dailyExpense.values.fold(0.0, (sum, v) => sum + v);
  
  final avgDailyIncome = totalIncome / daysInPeriod;
  final avgDailyExpense = totalExpense / daysInPeriod;
  
  // Calculate standard deviations for confidence intervals
  double incomeVariance = 0;
  double expenseVariance = 0;
  
  for (final amount in dailyIncome.values) {
    incomeVariance += (amount - avgDailyIncome) * (amount - avgDailyIncome);
  }
  for (final amount in dailyExpense.values) {
    expenseVariance += (amount - avgDailyExpense) * (amount - avgDailyExpense);
  }
  
  final incomeStdDev = dailyIncome.isNotEmpty 
      ? sqrt(incomeVariance / dailyIncome.length) 
      : avgDailyIncome * 0.5;
  final expenseStdDev = dailyExpense.isNotEmpty 
      ? sqrt(expenseVariance / dailyExpense.length) 
      : avgDailyExpense * 0.5;
  
  return HistoricalAverages(
    averageDailyIncome: avgDailyIncome,
    averageDailyExpense: avgDailyExpense,
    incomeStdDev: incomeStdDev,
    expenseStdDev: expenseStdDev,
  );
}

/// Generate forecast points for the specified period
CashFlowForecast _generateForecast({
  required double startingBalance,
  required List<RecurringTransaction> recurringTransactions,
  required HistoricalAverages historicalAverages,
  required ForecastParams params,
}) {
  final now = DateTime.now();
  final endDate = DateTime(now.year, now.month + params.monthsAhead, now.day);
  final points = <ForecastPoint>[];
  final alerts = <AlertEvent>[];
  
  double currentBalance = startingBalance;
  double totalProjectedIncome = 0;
  double totalProjectedExpense = 0;
  
  // Generate recurring transaction projections
  final recurringProjections = <ForecastTransaction>[];
  for (final recurring in recurringTransactions) {
    if (!recurring.isActive) continue;
    
    final projections = _projectRecurringTransaction(recurring, now, endDate);
    recurringProjections.addAll(projections);
  }
  
  // Sort projections by date
  recurringProjections.sort((a, b) => a.date.compareTo(b.date));
  
  // Generate forecast points based on granularity
  DateTime currentDate = DateTime(now.year, now.month, now.day);
  int dayIndex = 0;
  
  while (currentDate.isBefore(endDate)) {
    // Get transactions for this period
    final periodTransactions = recurringProjections.where((t) {
      if (params.granularity == ForecastGranularity.daily) {
        return t.date.year == currentDate.year &&
               t.date.month == currentDate.month &&
               t.date.day == currentDate.day;
      } else if (params.granularity == ForecastGranularity.weekly) {
        final weekStart = currentDate.subtract(Duration(days: currentDate.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 7));
        return t.date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
               t.date.isBefore(weekEnd);
      } else {
        return t.date.year == currentDate.year &&
               t.date.month == currentDate.month;
      }
    }).toList();
    
    // Calculate period totals
    double periodIncome = 0;
    double periodExpense = 0;
    
    for (final t in periodTransactions) {
      if (t.isIncome) {
        periodIncome += t.amount;
      } else {
        periodExpense += t.amount;
      }
    }
    
    // Add variable income/expense estimates based on historical averages
    final daysInPeriod = params.granularity == ForecastGranularity.daily 
        ? 1 
        : params.granularity == ForecastGranularity.weekly 
            ? 7 
            : 30;
    
    // Add estimated variable income/expense (subtract recurring from historical)
    final recurringIncomeInPeriod = periodTransactions
        .where((t) => t.isIncome)
        .fold(0.0, (sum, t) => sum + t.amount);
    final recurringExpenseInPeriod = periodTransactions
        .where((t) => !t.isIncome)
        .fold(0.0, (sum, t) => sum + t.amount);
    
    final estimatedVariableIncome = 
        (historicalAverages.averageDailyIncome * daysInPeriod - recurringIncomeInPeriod)
        .clamp(0, double.infinity);
    final estimatedVariableExpense = 
        (historicalAverages.averageDailyExpense * daysInPeriod - recurringExpenseInPeriod)
        .clamp(0, double.infinity);
    
    periodIncome += estimatedVariableIncome;
    periodExpense += estimatedVariableExpense;
    
    // Update running balance
    currentBalance += periodIncome - periodExpense;
    
    // Calculate confidence interval
    final confidenceRange = (historicalAverages.incomeStdDev + historicalAverages.expenseStdDev) * 
        daysInPeriod * 1.5; // 1.5 std devs for ~85% confidence
    
    // Create forecast point
    points.add(ForecastPoint(
      date: currentDate,
      projectedBalance: currentBalance,
      projectedIncome: periodIncome,
      projectedExpense: periodExpense,
      confidenceLower: currentBalance - confidenceRange,
      confidenceUpper: currentBalance + confidenceRange,
      transactions: periodTransactions,
    ));
    
    totalProjectedIncome += periodIncome;
    totalProjectedExpense += periodExpense;
    
    // Check for alert threshold
    if (params.alertThreshold != null && params.alertThreshold!.isEnabled) {
      if (currentBalance < params.alertThreshold!.amount) {
        alerts.add(AlertEvent(
          date: currentDate,
          balance: currentBalance,
          threshold: params.alertThreshold!.amount,
          message: '余额低于阈值 ¥${params.alertThreshold!.amount.toStringAsFixed(2)}',
        ));
      }
    }
    
    // Move to next period based on granularity
    if (params.granularity == ForecastGranularity.daily) {
      currentDate = currentDate.add(const Duration(days: 1));
    } else if (params.granularity == ForecastGranularity.weekly) {
      currentDate = currentDate.add(const Duration(days: 7));
    } else {
      currentDate = DateTime(currentDate.year, currentDate.month + 2, 1);
    }
    
    dayIndex++;
  }
  
  return CashFlowForecast(
    points: points,
    startingBalance: startingBalance,
    endingBalance: currentBalance,
    totalProjectedIncome: totalProjectedIncome,
    totalProjectedExpense: totalProjectedExpense,
    daysCovered: endDate.difference(now).inDays,
    alerts: alerts,
  );
}

/// Project a recurring transaction into the future
List<ForecastTransaction> _projectRecurringTransaction(
  RecurringTransaction recurring,
  DateTime startDate,
  DateTime endDate,
) {
  final projections = <ForecastTransaction>[];
  
  // Parse recurring transaction amount
  final amount = recurring.valueNum.toDouble() / recurring.valueDenom.toDouble();
  
  // Determine if this is income or expense based on amount sign
  // Positive = expense (money going out), Negative = income (money coming in)
  // This follows double-entry convention where:
  // - Expense accounts increase with debit (positive)
  // - Income accounts increase with credit (negative)
  final isIncome = amount < 0;
  final absAmount = amount.abs();
  
  // Get the next occurrence date
  DateTime nextDate = DateTime.fromMillisecondsSinceEpoch(recurring.nextDate);
  
  // Check if there's an end date
  final recurringEndDate = recurring.endDate != null
      ? DateTime.fromMillisecondsSinceEpoch(recurring.endDate!)
      : null;
  
  // Generate projections
  while (nextDate.isBefore(endDate)) {
    if (nextDate.isAfter(startDate) || nextDate.isAtSameMomentAs(startDate)) {
      // Check end date
      if (recurringEndDate != null && nextDate.isAfter(recurringEndDate)) {
        break;
      }
      
      // Check max occurrences
      if (recurring.maxOccurrences != null && 
          projections.length >= recurring.maxOccurrences!) {
        break;
      }
      
      projections.add(ForecastTransaction(
        name: recurring.name,
        amount: absAmount,
        date: nextDate,
        isRecurring: true,
        recurringId: recurring.id,
        isIncome: isIncome,
      ));
    }
    
    // Calculate next occurrence based on frequency
    nextDate = _calculateNextOccurrence(nextDate, recurring);
  }
  
  return projections;
}

/// Calculate the next occurrence date for a recurring transaction
DateTime _calculateNextOccurrence(DateTime current, RecurringTransaction recurring) {
  switch (recurring.frequency) {
    case 'daily':
      return current.add(Duration(days: recurring.interval));
    case 'weekly':
      return current.add(Duration(days: 7 * recurring.interval));
    case 'monthly':
      return DateTime(
        current.year,
        current.month + recurring.interval,
        recurring.dayOfMonth ?? current.day,
      );
    case 'yearly':
      return DateTime(
        current.year + recurring.interval,
        recurring.monthOfYear ?? current.month,
        recurring.dayOfMonth ?? current.day,
      );
    default:
      return current.add(Duration(days: recurring.interval));
  }
}
