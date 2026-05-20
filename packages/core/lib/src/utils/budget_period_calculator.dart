import '../models/budget.dart';

/// Utility class for calculating budget period boundaries.
/// Uses calendar boundaries: MONTHLY = 1st to last day, YEARLY = Jan 1 to Dec 31.
class BudgetPeriodCalculator {
  /// Returns (start, end) DateTime tuple for budget's current period.
  /// 
  /// For MONTHLY: 1st day of month 00:00:00 to last day 23:59:59.999
  /// For YEARLY: Jan 1 00:00:00 to Dec 31 23:59:59.999
  /// For CUSTOM: Uses provided startDate and endDate
  static (DateTime, DateTime) getCurrentPeriodBounds(
    BudgetPeriod period,
    DateTime referenceDate, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    switch (period) {
      case BudgetPeriod.monthly:
        // Calendar month: 1st to last day
        final start = DateTime(referenceDate.year, referenceDate.month, 1, 0, 0, 0, 0);
        // Last day of month = day 0 of next month
        final end = DateTime(referenceDate.year, referenceDate.month + 1, 0, 23, 59, 59, 999);
        return (start, end);
        
      case BudgetPeriod.yearly:
        // Calendar year: Jan 1 to Dec 31
        final start = DateTime(referenceDate.year, 1, 1, 0, 0, 0, 0);
        final end = DateTime(referenceDate.year, 12, 31, 23, 59, 59, 999);
        return (start, end);
        
      case BudgetPeriod.custom:
        if (customStart == null || customEnd == null) {
          throw ArgumentError('Custom period requires start and end dates');
        }
        return (customStart, customEnd);
    }
  }
  
  /// Check if a date falls within budget's current period.
  static bool isWithinPeriod(DateTime date, Budget budget) {
    final now = DateTime.now();
    final (start, end) = getCurrentPeriodBounds(
      budget.period,
      now,
      customStart: budget.startDate,
      customEnd: budget.endDate,
    );
    return (date.isAfter(start) || date.isAtSameMomentAs(start)) &&
           (date.isBefore(end) || date.isAtSameMomentAs(end));
  }
  
  /// Get the period label for display.
  static String getPeriodLabel(BudgetPeriod period, DateTime referenceDate) {
    switch (period) {
      case BudgetPeriod.monthly:
        return '${referenceDate.year}年${referenceDate.month}月';
      case BudgetPeriod.yearly:
        return '${referenceDate.year}年';
      case BudgetPeriod.custom:
        return '自定义周期';
    }
  }
  
  /// Calculate days remaining in current period.
  static int getDaysRemaining(BudgetPeriod period, DateTime referenceDate, {
    DateTime? customEnd,
  }) {
    final (_, end) = getCurrentPeriodBounds(
      period,
      referenceDate,
      customEnd: customEnd,
    );
    final now = DateTime.now();
    final remaining = end.difference(now).inDays;
    return remaining > 0 ? remaining : 0;
  }
  
  /// Calculate total days in current period.
  static int getTotalDaysInPeriod(BudgetPeriod period, DateTime referenceDate, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final (start, end) = getCurrentPeriodBounds(
      period,
      referenceDate,
      customStart: customStart,
      customEnd: customEnd,
    );
    return end.difference(start).inDays + 1;
  }
}