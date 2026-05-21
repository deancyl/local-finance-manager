import 'package:equatable/equatable.dart';
import 'package:decimal/decimal.dart';
import 'account.dart';

/// Enum representing the liquidity type for balance sheet items.
enum LiquidityType {
  current,
  nonCurrent,
}

/// Balance sheet item representing a single account in the balance sheet.
///
/// Represents an account with its balance in the balance sheet report.
/// Supports hierarchical structure via [children] for displaying
/// nested account structures.
class BalanceSheetItem extends Equatable {
  final int accountId;
  final String accountName;
  final AccountType accountType;
  final LiquidityType liquidityType;
  final int balanceNum;   // 余额分子 (numerator for balance amount)
  final int denom;        // 分母 (denominator)
  final int? parentId;
  final List<BalanceSheetItem>? children;

  const BalanceSheetItem({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.liquidityType,
    required this.balanceNum,
    required this.denom,
    this.parentId,
    this.children,
  });

  /// Converts the balance amount to a Decimal.
  Decimal get toDecimal => Decimal.fromInt(balanceNum) / Decimal.fromInt(denom);

  /// Returns true if this account has a debit balance.
  bool get isDebitBalance => balanceNum > 0;

  /// Returns true if this account has a credit balance.
  bool get isCreditBalance => balanceNum < 0;

  /// Returns the absolute balance as Decimal.
  Decimal get absoluteBalance => toDecimal.abs();

  /// Returns true if this is a current asset/liability.
  bool get isCurrent => liquidityType == LiquidityType.current;

  /// Returns true if this is a non-current asset/liability.
  bool get isNonCurrent => liquidityType == LiquidityType.nonCurrent;

  /// Creates a copy of this balance sheet item with the given fields replaced.
  BalanceSheetItem copyWith({
    int? accountId,
    String? accountName,
    AccountType? accountType,
    LiquidityType? liquidityType,
    int? balanceNum,
    int? denom,
    int? parentId,
    List<BalanceSheetItem>? children,
  }) {
    return BalanceSheetItem(
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      accountType: accountType ?? this.accountType,
      liquidityType: liquidityType ?? this.liquidityType,
      balanceNum: balanceNum ?? this.balanceNum,
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
        liquidityType,
        balanceNum,
        denom,
        parentId,
        children,
      ];
}

/// Balance sheet section representing a major section (assets, liabilities, or equity).
///
/// Contains a list of items and the total for the section.
class BalanceSheetSection extends Equatable {
  final String title;  // 资产/负债/所有者权益 (Assets/Liabilities/Equity)
  final List<BalanceSheetItem> items;
  final int totalNum;  // 总额分子 (numerator for total amount)
  final int denom;     // 分母 (denominator)

  const BalanceSheetSection({
    required this.title,
    required this.items,
    required this.totalNum,
    required this.denom,
  });

  /// Converts the total amount to a Decimal.
  Decimal get totalDecimal => Decimal.fromInt(totalNum) / Decimal.fromInt(denom);

  /// Returns the absolute total as Decimal.
  Decimal get absoluteTotal => totalDecimal.abs();

  /// Creates a copy of this balance sheet section with the given fields replaced.
  BalanceSheetSection copyWith({
    String? title,
    List<BalanceSheetItem>? items,
    int? totalNum,
    int? denom,
  }) {
    return BalanceSheetSection(
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

/// Balance sheet report model.
///
/// Represents a balance sheet report showing assets, liabilities, and equity
/// as of a specific date. Amounts are stored as fractions (numerator/denominator)
/// to avoid floating point precision issues.
class BalanceSheet extends Equatable {
  final DateTime asOfDate;  // 截止日期 (as of date)
  final BalanceSheetSection assets;
  final BalanceSheetSection liabilities;
  final BalanceSheetSection equity;
  final bool isBalanced;
  final DateTime generatedAt;

  const BalanceSheet({
    required this.asOfDate,
    required this.assets,
    required this.liabilities,
    required this.equity,
    required this.isBalanced,
    required this.generatedAt,
  });

  /// Returns the accounting equation: Assets = Liabilities + Equity.
  /// Returns true if the equation balances.
  bool get verifyBalance {
    final assetsTotal = assets.totalDecimal;
    final liabilitiesTotal = liabilities.totalDecimal;
    final equityTotal = equity.totalDecimal;
    return assetsTotal == liabilitiesTotal + equityTotal;
  }

  /// Returns the difference if the balance sheet is not balanced.
  Decimal get difference {
    final assetsTotal = assets.totalDecimal;
    final liabilitiesTotal = liabilities.totalDecimal;
    final equityTotal = equity.totalDecimal;
    final diff = assetsTotal - (liabilitiesTotal + equityTotal);
    return diff.abs();
  }

  /// Creates a copy of this balance sheet with the given fields replaced.
  BalanceSheet copyWith({
    DateTime? asOfDate,
    BalanceSheetSection? assets,
    BalanceSheetSection? liabilities,
    BalanceSheetSection? equity,
    bool? isBalanced,
    DateTime? generatedAt,
  }) {
    return BalanceSheet(
      asOfDate: asOfDate ?? this.asOfDate,
      assets: assets ?? this.assets,
      liabilities: liabilities ?? this.liabilities,
      equity: equity ?? this.equity,
      isBalanced: isBalanced ?? this.isBalanced,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }

  @override
  List<Object?> get props => [
        asOfDate,
        assets,
        liabilities,
        equity,
        isBalanced,
        generatedAt,
      ];
}
