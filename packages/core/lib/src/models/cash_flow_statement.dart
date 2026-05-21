import 'package:equatable/equatable.dart';
import 'package:decimal/decimal.dart';

/// Cash flow activity type following standard accounting conventions.
///
/// Cash flow statements are divided into three main categories:
/// - Operating: Day-to-day business activities
/// - Investing: Purchase and sale of long-term assets
/// - Financing: Borrowing and equity transactions
enum CashFlowActivityType {
  operating('OPERATING', '经营活动'),
  investing('INVESTING', '投资活动'),
  financing('FINANCING', '筹资活动');

  final String code;
  final String labelZh;

  const CashFlowActivityType(this.code, this.labelZh);
}

/// Cash flow item representing a single line item in the cash flow statement.
///
/// Represents a specific cash inflow or outflow with integer amounts
/// to avoid floating point precision issues.
class CashFlowItem extends Equatable {
  final String id;
  final String name;
  final CashFlowActivityType activityType;
  final int amountNum; // 金额分子 (numerator for amount)
  final int denom; // 分母 (denominator)
  final bool isInflow; // true = inflow, false = outflow
  final String? description;
  final List<CashFlowItem>? children;

  const CashFlowItem({
    required this.id,
    required this.name,
    required this.activityType,
    required this.amountNum,
    required this.denom,
    required this.isInflow,
    this.description,
    this.children,
  });

  /// Converts the amount to a Decimal.
  Decimal get amountDecimal =>
      (Decimal.fromInt(amountNum) / Decimal.fromInt(denom)).toDecimal();

  /// Returns the absolute amount as Decimal.
  Decimal get absoluteAmount => amountDecimal.abs();

  /// Returns the signed amount (positive for inflow, negative for outflow).
  Decimal get signedAmount => isInflow ? amountDecimal : -amountDecimal;

  /// Creates a copy of this cash flow item with the given fields replaced.
  CashFlowItem copyWith({
    String? id,
    String? name,
    CashFlowActivityType? activityType,
    int? amountNum,
    int? denom,
    bool? isInflow,
    String? description,
    List<CashFlowItem>? children,
  }) {
    return CashFlowItem(
      id: id ?? this.id,
      name: name ?? this.name,
      activityType: activityType ?? this.activityType,
      amountNum: amountNum ?? this.amountNum,
      denom: denom ?? this.denom,
      isInflow: isInflow ?? this.isInflow,
      description: description ?? this.description,
      children: children ?? this.children,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        activityType,
        amountNum,
        denom,
        isInflow,
        description,
        children,
      ];
}

/// Cash flow section representing a major category (Operating, Investing, Financing).
///
/// Contains a list of items and the net cash flow for the section.
class CashFlowSection extends Equatable {
  final CashFlowActivityType activityType;
  final String title;
  final List<CashFlowItem> items;
  final int totalInflowNum; // 流入合计分子
  final int totalOutflowNum; // 流出合计分子
  final int netCashFlowNum; // 净现金流分子
  final int denom; // 分母

  const CashFlowSection({
    required this.activityType,
    required this.title,
    required this.items,
    required this.totalInflowNum,
    required this.totalOutflowNum,
    required this.netCashFlowNum,
    required this.denom,
  });

  /// Converts the total inflow to a Decimal.
  Decimal get totalInflowDecimal =>
      (Decimal.fromInt(totalInflowNum) / Decimal.fromInt(denom)).toDecimal();

  /// Converts the total outflow to a Decimal.
  Decimal get totalOutflowDecimal =>
      (Decimal.fromInt(totalOutflowNum) / Decimal.fromInt(denom)).toDecimal();

  /// Converts the net cash flow to a Decimal.
  Decimal get netCashFlowDecimal =>
      (Decimal.fromInt(netCashFlowNum) / Decimal.fromInt(denom)).toDecimal();

  /// Returns true if net cash flow is positive.
  bool get isPositiveNetFlow => netCashFlowNum > 0;

  /// Returns true if net cash flow is negative.
  bool get isNegativeNetFlow => netCashFlowNum < 0;

  /// Returns the absolute net cash flow as Decimal.
  Decimal get absoluteNetCashFlow => netCashFlowDecimal.abs();

  /// Creates a copy of this cash flow section with the given fields replaced.
  CashFlowSection copyWith({
    CashFlowActivityType? activityType,
    String? title,
    List<CashFlowItem>? items,
    int? totalInflowNum,
    int? totalOutflowNum,
    int? netCashFlowNum,
    int? denom,
  }) {
    return CashFlowSection(
      activityType: activityType ?? this.activityType,
      title: title ?? this.title,
      items: items ?? this.items,
      totalInflowNum: totalInflowNum ?? this.totalInflowNum,
      totalOutflowNum: totalOutflowNum ?? this.totalOutflowNum,
      netCashFlowNum: netCashFlowNum ?? this.netCashFlowNum,
      denom: denom ?? this.denom,
    );
  }

  @override
  List<Object?> get props => [
        activityType,
        title,
        items,
        totalInflowNum,
        totalOutflowNum,
        netCashFlowNum,
        denom,
      ];
}

/// Cash flow statement report model.
///
/// Represents a cash flow statement showing operating, investing, and financing
/// activities. Uses the indirect method starting from net income and adjusting
/// for non-cash items and working capital changes.
///
/// Amounts are stored as fractions (numerator/denominator) to avoid
/// floating point precision issues.
class CashFlowStatement extends Equatable {
  final DateTime startDate;
  final DateTime endDate;
  final CashFlowSection operating;
  final CashFlowSection investing;
  final CashFlowSection financing;
  final int beginningCashNum; // 期初现金分子
  final int netChangeInCashNum; // 现金净变动分子
  final int endingCashNum; // 期末现金分子
  final int denom; // 分母
  final DateTime generatedAt;

  const CashFlowStatement({
    required this.startDate,
    required this.endDate,
    required this.operating,
    required this.investing,
    required this.financing,
    required this.beginningCashNum,
    required this.netChangeInCashNum,
    required this.endingCashNum,
    required this.denom,
    required this.generatedAt,
  });

  /// Converts the beginning cash to a Decimal.
  Decimal get beginningCashDecimal =>
      (Decimal.fromInt(beginningCashNum) / Decimal.fromInt(denom)).toDecimal();

  /// Converts the net change in cash to a Decimal.
  Decimal get netChangeInCashDecimal =>
      (Decimal.fromInt(netChangeInCashNum) / Decimal.fromInt(denom)).toDecimal();

  /// Converts the ending cash to a Decimal.
  Decimal get endingCashDecimal =>
      (Decimal.fromInt(endingCashNum) / Decimal.fromInt(denom)).toDecimal();

  /// Returns true if net change in cash is positive.
  bool get isPositiveNetChange => netChangeInCashNum > 0;

  /// Returns true if net change in cash is negative.
  bool get isNegativeNetChange => netChangeInCashNum < 0;

  /// Returns the absolute net change as Decimal.
  Decimal get absoluteNetChange => netChangeInCashDecimal.abs();

  /// Returns the total cash inflows across all activities.
  Decimal get totalInflows {
    final operatingInflow = operating.totalInflowDecimal;
    final investingInflow = investing.totalInflowDecimal;
    final financingInflow = financing.totalInflowDecimal;
    return operatingInflow + investingInflow + financingInflow;
  }

  /// Returns the total cash outflows across all activities.
  Decimal get totalOutflows {
    final operatingOutflow = operating.totalOutflowDecimal;
    final investingOutflow = investing.totalOutflowDecimal;
    final financingOutflow = financing.totalOutflowDecimal;
    return operatingOutflow + investingOutflow + financingOutflow;
  }

  /// Creates a copy of this cash flow statement with the given fields replaced.
  CashFlowStatement copyWith({
    DateTime? startDate,
    DateTime? endDate,
    CashFlowSection? operating,
    CashFlowSection? investing,
    CashFlowSection? financing,
    int? beginningCashNum,
    int? netChangeInCashNum,
    int? endingCashNum,
    int? denom,
    DateTime? generatedAt,
  }) {
    return CashFlowStatement(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      operating: operating ?? this.operating,
      investing: investing ?? this.investing,
      financing: financing ?? this.financing,
      beginningCashNum: beginningCashNum ?? this.beginningCashNum,
      netChangeInCashNum: netChangeInCashNum ?? this.netChangeInCashNum,
      endingCashNum: endingCashNum ?? this.endingCashNum,
      denom: denom ?? this.denom,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }

  @override
  List<Object?> get props => [
        startDate,
        endDate,
        operating,
        investing,
        financing,
        beginningCashNum,
        netChangeInCashNum,
        endingCashNum,
        denom,
        generatedAt,
      ];
}
