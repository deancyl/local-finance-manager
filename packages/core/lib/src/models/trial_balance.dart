import 'package:equatable/equatable.dart';
import 'package:decimal/decimal.dart';
import 'account.dart';

/// Enum representing which side a balance is on.
enum BalanceSide {
  debit,
  credit,
}

/// Account balance entry in a trial balance report.
///
/// Represents the debit and credit totals for a single account
/// in the trial balance. Supports hierarchical structure via
/// [children] for displaying nested account structures.
class AccountBalance extends Equatable {
  final String accountId;
  final String accountName;
  final AccountType accountType;
  final int debitNum;   // 借方金额分子 (numerator for debit amount)
  final int creditNum;  // 贷方金额分子 (numerator for credit amount)
  final int denom;      // 分母 (denominator)
  final String? parentId;
  final List<AccountBalance>? children;

  const AccountBalance({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.debitNum,
    required this.creditNum,
    required this.denom,
    this.parentId,
    this.children,
  });

  /// Converts the debit amount to a Decimal.
  Decimal get debitDecimal => Decimal.fromInt(debitNum) / Decimal.fromInt(denom);

  /// Converts the credit amount to a Decimal.
  Decimal get creditDecimal => Decimal.fromInt(creditNum) / Decimal.fromInt(denom);

  /// Returns true if this account has a debit balance.
  bool get isDebitBalance => debitNum > creditNum;

  /// Returns true if this account has a credit balance.
  bool get isCreditBalance => creditNum > debitNum;

  /// Returns the balance side (debit or credit).
  BalanceSide get balanceSide => isDebitBalance ? BalanceSide.debit : BalanceSide.credit;

  /// Returns the net balance as Decimal.
  Decimal get netBalance {
    if (isDebitBalance) {
      return debitDecimal - creditDecimal;
    } else {
      return creditDecimal - debitDecimal;
    }
  }

  /// Creates a copy of this account balance with the given fields replaced.
  AccountBalance copyWith({
    int? accountId,
    String? accountName,
    AccountType? accountType,
    int? debitNum,
    int? creditNum,
    int? denom,
    int? parentId,
    List<AccountBalance>? children,
  }) {
    return AccountBalance(
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      accountType: accountType ?? this.accountType,
      debitNum: debitNum ?? this.debitNum,
      creditNum: creditNum ?? this.creditNum,
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
        debitNum,
        creditNum,
        denom,
        parentId,
        children,
      ];
}

/// Trial balance report model.
///
/// Represents a trial balance report showing all accounts and their
/// debit/credit balances. Amounts are stored as fractions (numerator/denominator)
/// to avoid floating point precision issues.
class TrialBalance extends Equatable {
  final List<AccountBalance> accounts;
  final int totalDebits;   // 分数表示 (valueNum) - numerator for total debits
  final int totalCredits;  // 分数表示 (valueNum) - numerator for total credits
  final int commonDenom;   // 公分母 (common denominator)
  final bool isBalanced;
  final DateTime generatedAt;
  final DateTime? startDate;
  final DateTime? endDate;

  const TrialBalance({
    required this.accounts,
    required this.totalDebits,
    required this.totalCredits,
    required this.commonDenom,
    required this.isBalanced,
    required this.generatedAt,
    this.startDate,
    this.endDate,
  });

  /// Converts the total debits to a Decimal.
  Decimal get totalDebitsDecimal =>
      Decimal.fromInt(totalDebits) / Decimal.fromInt(commonDenom);

  /// Converts the total credits to a Decimal.
  Decimal get totalCreditsDecimal =>
      Decimal.fromInt(totalCredits) / Decimal.fromInt(commonDenom);

  /// Returns the difference between debits and credits.
  Decimal get difference {
    final diff = totalDebitsDecimal - totalCreditsDecimal;
    return diff.abs();
  }

  /// Creates a copy of this trial balance with the given fields replaced.
  TrialBalance copyWith({
    List<AccountBalance>? accounts,
    int? totalDebits,
    int? totalCredits,
    int? commonDenom,
    bool? isBalanced,
    DateTime? generatedAt,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return TrialBalance(
      accounts: accounts ?? this.accounts,
      totalDebits: totalDebits ?? this.totalDebits,
      totalCredits: totalCredits ?? this.totalCredits,
      commonDenom: commonDenom ?? this.commonDenom,
      isBalanced: isBalanced ?? this.isBalanced,
      generatedAt: generatedAt ?? this.generatedAt,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  @override
  List<Object?> get props => [
        accounts,
        totalDebits,
        totalCredits,
        commonDenom,
        isBalanced,
        generatedAt,
        startDate,
        endDate,
      ];
}
