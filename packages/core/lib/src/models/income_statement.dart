import 'package:equatable/equatable.dart';
import 'package:decimal/decimal.dart';
import 'account.dart';

/// Income statement item representing a single revenue or expense account.
///
/// Represents an account with its amount in the income statement report.
/// Supports hierarchical structure via [children] for displaying
/// nested account structures.
class IncomeStatementItem extends Equatable {
  final String accountId;
  final String accountName;
  final AccountType accountType; // INCOME or EXPENSE
  final int amountNum; // 金额分子 (numerator for amount)
  final int denom; // 分母 (denominator)
  final String? parentId;
  final List<IncomeStatementItem>? children;

  const IncomeStatementItem({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.amountNum,
    required this.denom,
    this.parentId,
    this.children,
  });

  /// Converts the amount to a Decimal.
  Decimal get amountDecimal =>
      (Decimal.fromInt(amountNum) / Decimal.fromInt(denom)).toDecimal();

  /// Returns true if this is an income account.
  bool get isIncome => accountType == AccountType.income;

  /// Returns true if this is an expense account.
  bool get isExpense => accountType == AccountType.expense;

  /// Returns the absolute amount as Decimal.
  Decimal get absoluteAmount => amountDecimal.abs();

  /// Creates a copy of this income statement item with the given fields replaced.
  IncomeStatementItem copyWith({
    String? accountId,
    String? accountName,
    AccountType? accountType,
    int? amountNum,
    int? denom,
    String? parentId,
    List<IncomeStatementItem>? children,
  }) {
    return IncomeStatementItem(
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      accountType: accountType ?? this.accountType,
      amountNum: amountNum ?? this.amountNum,
      denom: denom ?? this.denom,
      parentId: parentId ?? this.parentId,
      children: children ?? this.children,
    );
  }

  @override
  List<Object?> get props => [
        accountId,
        accountName,
        accountType,
        amountNum,
        denom,
        parentId,
        children,
      ];
}

/// Income statement section representing a major section (revenues or expenses).
///
/// Contains a list of items and the total for the section.
class IncomeStatementSection extends Equatable {
  final String title; // 收入/费用 (Revenues/Expenses)
  final List<IncomeStatementItem> items;
  final int totalNum; // 合计分子 (numerator for total amount)
  final int denom; // 分母 (denominator)

  const IncomeStatementSection({
    required this.title,
    required this.items,
    required this.totalNum,
    required this.denom,
  });

  /// Converts the total amount to a Decimal.
  Decimal get totalDecimal =>
      (Decimal.fromInt(totalNum) / Decimal.fromInt(denom)).toDecimal();

  /// Returns the absolute total as Decimal.
  Decimal get absoluteTotal => totalDecimal.abs();

  /// Creates a copy of this income statement section with the given fields replaced.
  IncomeStatementSection copyWith({
    String? title,
    List<IncomeStatementItem>? items,
    int? totalNum,
    int? denom,
  }) {
    return IncomeStatementSection(
      title: title ?? this.title,
      items: items ?? this.items,
      totalNum: totalNum ?? this.totalNum,
      denom: denom ?? this.denom,
    );
  }

  @override
  List<Object?> get props => [
        title,
        items,
        totalNum,
        denom,
      ];
}

/// Income statement report model.
///
/// Represents an income statement report showing revenues, expenses,
/// and net income for a specific period. Amounts are stored as fractions
/// (numerator/denominator) to avoid floating point precision issues.
class IncomeStatement extends Equatable {
  final DateTime startDate;
  final DateTime endDate;
  final IncomeStatementSection revenues;
  final IncomeStatementSection expenses;
  final int netIncomeNum; // 净利润分子 (numerator for net income)
  final int denom; // 分母 (denominator)
  final DateTime generatedAt;

  const IncomeStatement({
    required this.startDate,
    required this.endDate,
    required this.revenues,
    required this.expenses,
    required this.netIncomeNum,
    required this.denom,
    required this.generatedAt,
  });

  /// Converts the net income amount to a Decimal.
  Decimal get netIncomeDecimal =>
      (Decimal.fromInt(netIncomeNum) / Decimal.fromInt(denom)).toDecimal();

  /// Returns true if there is a profit (net income > 0).
  bool get isProfit => netIncomeNum > 0;

  /// Returns true if there is a loss (net income < 0).
  bool get isLoss => netIncomeNum < 0;

  /// Returns true if net income is zero.
  bool get isBreakEven => netIncomeNum == 0;

  /// Returns the absolute net income as Decimal.
  Decimal get absoluteNetIncome => netIncomeDecimal.abs();

  /// Returns the gross profit (total revenues).
  Decimal get grossProfit => revenues.totalDecimal;

  /// Returns the total expenses.
  Decimal get totalExpenses => expenses.totalDecimal;

  /// Creates a copy of this income statement with the given fields replaced.
  IncomeStatement copyWith({
    DateTime? startDate,
    DateTime? endDate,
    IncomeStatementSection? revenues,
    IncomeStatementSection? expenses,
    int? netIncomeNum,
    int? denom,
    DateTime? generatedAt,
  }) {
    return IncomeStatement(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      revenues: revenues ?? this.revenues,
      expenses: expenses ?? this.expenses,
      netIncomeNum: netIncomeNum ?? this.netIncomeNum,
      denom: denom ?? this.denom,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }

  @override
  List<Object?> get props => [
        startDate,
        endDate,
        revenues,
        expenses,
        netIncomeNum,
        denom,
        generatedAt,
      ];
}

/// Income statement with period comparison support.
///
/// Extends the base IncomeStatement with comparison data for a previous period.
class IncomeStatementWithComparison extends Equatable {
  final IncomeStatement current;
  final IncomeStatement? previous;
  final PeriodComparisonType comparisonType;

  const IncomeStatementWithComparison({
    required this.current,
    this.previous,
    this.comparisonType = PeriodComparisonType.none,
  });

  /// Returns true if comparison data is available.
  bool get hasComparison => previous != null && comparisonType != PeriodComparisonType.none;

  /// Returns the revenue change amount (current - previous).
  /// Positive means increase, negative means decrease.
  Decimal get revenueChange {
    if (!hasComparison) return Decimal.zero;
    return current.revenues.totalDecimal - previous!.revenues.totalDecimal;
  }

  /// Returns the expense change amount (current - previous).
  /// Positive means increase, negative means decrease.
  Decimal get expenseChange {
    if (!hasComparison) return Decimal.zero;
    return current.expenses.totalDecimal - previous!.expenses.totalDecimal;
  }

  /// Returns the net income change amount (current - previous).
  Decimal get netIncomeChange {
    if (!hasComparison) return Decimal.zero;
    return current.netIncomeDecimal - previous!.netIncomeDecimal;
  }

  /// Returns the revenue change percentage.
  /// Returns null if previous revenue was zero.
  double? get revenueChangePercent {
    if (!hasComparison) return null;
    final prevRevenue = previous!.revenues.totalDecimal;
    if (prevRevenue == Decimal.zero) return null;
    final change = revenueChange;
    return (change / prevRevenue).toDouble() * 100;
  }

  /// Returns the expense change percentage.
  /// Returns null if previous expense was zero.
  double? get expenseChangePercent {
    if (!hasComparison) return null;
    final prevExpense = previous!.expenses.totalDecimal;
    if (prevExpense == Decimal.zero) return null;
    final change = expenseChange;
    return (change / prevExpense).toDouble() * 100;
  }

  /// Returns the net income change percentage.
  /// Returns null if previous net income was zero.
  double? get netIncomeChangePercent {
    if (!hasComparison) return null;
    final prevNetIncome = previous!.netIncomeDecimal;
    if (prevNetIncome == Decimal.zero) return null;
    final change = netIncomeChange;
    return (change / prevNetIncome).toDouble() * 100;
  }

  /// Returns a formatted comparison period label.
  String get comparisonPeriodLabel {
    switch (comparisonType) {
      case PeriodComparisonType.none:
        return '';
      case PeriodComparisonType.previousMonth:
        return '上月';
      case PeriodComparisonType.previousQuarter:
        return '上季度';
      case PeriodComparisonType.previousYear:
        return '去年同期';
      case PeriodComparisonType.custom:
        return '对比期间';
    }
  }

  /// Creates a copy with the given fields replaced.
  IncomeStatementWithComparison copyWith({
    IncomeStatement? current,
    IncomeStatement? previous,
    PeriodComparisonType? comparisonType,
  }) {
    return IncomeStatementWithComparison(
      current: current ?? this.current,
      previous: previous ?? this.previous,
      comparisonType: comparisonType ?? this.comparisonType,
    );
  }

  @override
  List<Object?> get props => [current, previous, comparisonType];
}

/// Type of period comparison for income statement.
enum PeriodComparisonType {
  none,
  previousMonth,
  previousQuarter,
  previousYear,
  custom,
}
