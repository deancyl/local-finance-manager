import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';
import 'currency_conversion_service.dart';

/// Period type for balance history aggregation
enum BalanceHistoryPeriod {
  monthly,
  quarterly,
  yearly,
}

/// Period filter state provider
final balanceHistoryPeriodProvider = StateProvider<BalanceHistoryPeriod>((ref) {
  return BalanceHistoryPeriod.monthly;
});

/// Date range for balance history (defaults to last 12 months)
final balanceHistoryDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  final startDate = DateTime(now.year, now.month - 11, 1);
  final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
  return DateTimeRange(start: startDate, end: endDate);
});

/// Simple date range class
class DateTimeRange {
  final DateTime start;
  final DateTime end;
  
  const DateTimeRange({required this.start, required this.end});
}

/// Balance history data point
class BalanceHistoryPoint {
  final DateTime date;
  final String label; // "2026-05", "2026-Q2", "2026"
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;
  
  const BalanceHistoryPoint({
    required this.date,
    required this.label,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
  });
  
  /// Net worth growth percentage compared to previous period
  double growthPercentage(BalanceHistoryPoint? previous) {
    if (previous == null || previous.netWorth == 0) return 0.0;
    return ((netWorth - previous.netWorth) / previous.netWorth.abs()) * 100;
  }
}

/// Comparison data for previous period
class BalanceComparison {
  final BalanceHistoryPoint current;
  final BalanceHistoryPoint? previous;
  final double assetChange;
  final double liabilityChange;
  final double netWorthChange;
  final double netWorthGrowthPercent;
  
  const BalanceComparison({
    required this.current,
    this.previous,
    required this.assetChange,
    required this.liabilityChange,
    required this.netWorthChange,
    required this.netWorthGrowthPercent,
  });
}

/// Provider for balance history data
final balanceHistoryProvider = FutureProvider<List<BalanceHistoryPoint>>((ref) async {
  final db = ref.watch(databaseProvider);
  final dateRange = ref.watch(balanceHistoryDateRangeProvider);
  final period = ref.watch(balanceHistoryPeriodProvider);
  final currencyService = ref.watch(currencyConversionServiceProvider);
  final targetCurrency = ref.read(reportCurrencyProvider);
  
  // Get all accounts
  final accounts = await (db.select(db.accounts)).get();
  final accountMap = <String, Account>{for (var a in accounts) a.id: a};
  
  // Generate period endpoints based on period type
  final periods = _generatePeriods(dateRange.start, dateRange.end, period);
  
  // Calculate balances at each period endpoint
  final historyPoints = <BalanceHistoryPoint>[];
  
  for (final periodEnd in periods) {
    final balances = await _calculateBalancesAsOfDate(
      db,
      accountMap,
      periodEnd,
      currencyService,
      targetCurrency,
    );
    
    final totalAssets = balances['ASSET'] ?? 0.0;
    final totalLiabilities = balances['LIABILITY'] ?? 0.0;
    final netWorth = totalAssets - totalLiabilities.abs();
    
    historyPoints.add(BalanceHistoryPoint(
      date: periodEnd,
      label: _formatPeriodLabel(periodEnd, period),
      totalAssets: totalAssets,
      totalLiabilities: totalLiabilities,
      netWorth: netWorth,
    ));
  }
  
  return historyPoints;
});

/// Provider for comparison with previous period
final balanceComparisonProvider = FutureProvider<BalanceComparison?>((ref) async {
  final historyAsync = ref.watch(balanceHistoryProvider);
  
  return historyAsync.when(
    data: (history) {
      if (history.isEmpty) return null;
      
      final current = history.last;
      final previous = history.length > 1 ? history[history.length - 2] : null;
      
      return BalanceComparison(
        current: current,
        previous: previous,
        assetChange: previous != null 
            ? current.totalAssets - previous.totalAssets 
            : 0.0,
        liabilityChange: previous != null 
            ? current.totalLiabilities - previous.totalLiabilities 
            : 0.0,
        netWorthChange: previous != null 
            ? current.netWorth - previous.netWorth 
            : 0.0,
        netWorthGrowthPercent: current.growthPercentage(previous),
      );
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Generate period endpoints for the date range
List<DateTime> _generatePeriods(DateTime start, DateTime end, BalanceHistoryPeriod period) {
  final periods = <DateTime>[];
  
  switch (period) {
    case BalanceHistoryPeriod.monthly:
      var current = DateTime(start.year, start.month, 1);
      while (current.isBefore(end) || current.isAtSameMomentAs(DateTime(end.year, end.month, 1))) {
        // End of month
        final monthEnd = DateTime(current.year, current.month + 1, 0, 23, 59, 59, 999);
        periods.add(monthEnd);
        current = DateTime(current.year, current.month + 1, 1);
      }
      break;
      
    case BalanceHistoryPeriod.quarterly:
      // Start from the beginning of the quarter containing start date
      var current = DateTime(start.year, ((start.month - 1) ~/ 3) * 3 + 1, 1);
      while (current.isBefore(end) || current.isAtSameMomentAs(DateTime(end.year, end.month, 1))) {
        // End of quarter
        final quarterEndMonth = ((current.month - 1) ~/ 3) * 3 + 3;
        final quarterEnd = DateTime(current.year, quarterEndMonth + 1, 0, 23, 59, 59, 999);
        periods.add(quarterEnd);
        current = DateTime(current.year, current.month + 3, 1);
      }
      break;
      
    case BalanceHistoryPeriod.yearly:
      var current = DateTime(start.year, 1, 1);
      while (current.year <= end.year) {
        // End of year
        final yearEnd = DateTime(current.year, 12, 31, 23, 59, 59, 999);
        periods.add(yearEnd);
        current = DateTime(current.year + 1, 1, 1);
      }
      break;
  }
  
  return periods;
}

/// Format period label based on period type
String _formatPeriodLabel(DateTime date, BalanceHistoryPeriod period) {
  switch (period) {
    case BalanceHistoryPeriod.monthly:
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    case BalanceHistoryPeriod.quarterly:
      final quarter = ((date.month - 1) ~/ 3) + 1;
      return '${date.year}-Q$quarter';
    case BalanceHistoryPeriod.yearly:
      return '${date.year}';
  }
}

/// Calculate total balances by account type as of a specific date
Future<Map<String, double>> _calculateBalancesAsOfDate(
  LocalFinanceDatabase db,
  Map<String, Account> accountMap,
  DateTime asOfDate,
  CurrencyConversionService currencyService,
  String targetCurrency,
) async {
  final balances = <String, double>{
    'ASSET': 0.0,
    'LIABILITY': 0.0,
    'EQUITY': 0.0,
    'INCOME': 0.0,
    'EXPENSE': 0.0,
  };
  
  final asOfDateMs = asOfDate.millisecondsSinceEpoch;
  
  // Get all splits with transactions before or on asOfDate
  final splits = await (db.select(db.splits)).get();
  
  // Get all transactions to filter by date
  final transactions = await (db.select(db.transactions)
    ..where((t) => t.postDate.isSmallerOrEqual(asOfDateMs))
    ..where((t) => t.deletedAt.isNull()))
    .get();
  
  final transactionMap = <String, Transaction>{
    for (var t in transactions) t.id: t,
  };
  
  // Calculate balance for each account
  final accountBalances = <String, double>{};
  
  for (final split in splits) {
    final transaction = transactionMap[split.transactionId];
    if (transaction == null) continue;
    
    final account = accountMap[split.accountId];
    if (account == null) continue;
    
    // Convert value to double
    final value = split.valueNum.toDouble() / split.valueDenom.toDouble();
    
    // Apply accounting sign convention
    final adjustedValue = _applyAccountTypeSign(account.accountType, value);
    
    accountBalances[account.id] = (accountBalances[account.id] ?? 0.0) + adjustedValue;
  }
  
  // Aggregate by account type with currency conversion
  for (final entry in accountBalances.entries) {
    final accountId = entry.key;
    final balance = entry.value;
    final account = accountMap[accountId];
    
    if (account == null) continue;
    
    // Convert to target currency if needed
    double convertedBalance = balance;
    if (account.commodityId != targetCurrency) {
      convertedBalance = await currencyService.convertOrDefault(
        balance,
        account.commodityId,
        targetCurrency,
      );
    }
    
    // Sum by account type
    final accountType = account.accountType.toUpperCase();
    if (balances.containsKey(accountType)) {
      balances[accountType] = balances[accountType]! + convertedBalance;
    }
  }
  
  return balances;
}

/// Applies accounting sign convention based on account type
double _applyAccountTypeSign(String accountType, double value) {
  switch (accountType.toUpperCase()) {
    case 'ASSET':
    case 'EXPENSE':
      // Debit increases balance
      return value;
    case 'LIABILITY':
    case 'EQUITY':
    case 'INCOME':
      // Credit increases balance (so debit decreases)
      return -value;
    default:
      return value;
  }
}

/// Notifier for managing balance history state
class BalanceHistoryNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  
  BalanceHistoryNotifier(this._ref) : super(const AsyncValue.data(null));
  
  /// Set period type and refresh
  Future<void> setPeriod(BalanceHistoryPeriod period) async {
    _ref.read(balanceHistoryPeriodProvider.notifier).state = period;
    // Invalidate the provider to trigger refresh
    _ref.invalidate(balanceHistoryProvider);
  }
  
  /// Set custom date range and refresh
  Future<void> setDateRange(DateTime start, DateTime end) async {
    _ref.read(balanceHistoryDateRangeProvider.notifier).state = DateTimeRange(
      start: start,
      end: end,
    );
    // Invalidate the provider to trigger refresh
    _ref.invalidate(balanceHistoryProvider);
  }
  
  /// Set to last N months
  Future<void> setLastMonths(int months) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month - months + 1, 1);
    final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    await setDateRange(startDate, endDate);
  }
  
  /// Set to last N years
  Future<void> setLastYears(int years) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year - years + 1, 1, 1);
    final endDate = DateTime(now.year, 12, 31, 23, 59, 59, 999);
    await setDateRange(startDate, endDate);
  }
}

final balanceHistoryNotifierProvider = StateNotifierProvider<BalanceHistoryNotifier, AsyncValue<void>>((ref) {
  return BalanceHistoryNotifier(ref);
});
