import 'package:equatable/equatable.dart';
import 'package:decimal/decimal.dart';
import 'account.dart';

/// A single entry in the general ledger for an account.
///
/// Represents one transaction line with date, description, reference,
/// debit/credit amounts, and running balance.
class GeneralLedgerEntry extends Equatable {
  /// Transaction ID this entry belongs to
  final String transactionId;
  
  /// Date of the transaction
  final DateTime date;
  
  /// Transaction description
  final String? description;
  
  /// Reference number (check number, invoice number, etc.)
  final String? reference;
  
  /// Split memo (additional details for this split)
  final String? memo;
  
  /// Debit amount numerator (0 if credit)
  final int debitNum;
  
  /// Credit amount numerator (0 if debit)
  final int creditNum;
  
  /// Denominator for amounts
  final int denom;
  
  /// Running balance numerator after this entry
  final int balanceNum;
  
  /// Denominator for balance
  final int balanceDenom;

  const GeneralLedgerEntry({
    required this.transactionId,
    required this.date,
    this.description,
    this.reference,
    this.memo,
    required this.debitNum,
    required this.creditNum,
    required this.denom,
    required this.balanceNum,
    required this.balanceDenom,
  });

  /// Converts the debit amount to a Decimal.
  Decimal get debitDecimal =>
      (Decimal.fromInt(debitNum) / Decimal.fromInt(denom)).toDecimal();

  /// Converts the credit amount to a Decimal.
  Decimal get creditDecimal =>
      (Decimal.fromInt(creditNum) / Decimal.fromInt(denom)).toDecimal();

  /// Converts the running balance to a Decimal.
  Decimal get balanceDecimal =>
      (Decimal.fromInt(balanceNum) / Decimal.fromInt(balanceDenom)).toDecimal();

  /// Returns true if this entry is a debit.
  bool get isDebit => debitNum > 0;

  /// Returns true if this entry is a credit.
  bool get isCredit => creditNum > 0;

  /// Creates a copy of this entry with the given fields replaced.
  GeneralLedgerEntry copyWith({
    String? transactionId,
    DateTime? date,
    String? description,
    String? reference,
    String? memo,
    int? debitNum,
    int? creditNum,
    int? denom,
    int? balanceNum,
    int? balanceDenom,
  }) {
    return GeneralLedgerEntry(
      transactionId: transactionId ?? this.transactionId,
      date: date ?? this.date,
      description: description ?? this.description,
      reference: reference ?? this.reference,
      memo: memo ?? this.memo,
      debitNum: debitNum ?? this.debitNum,
      creditNum: creditNum ?? this.creditNum,
      denom: denom ?? this.denom,
      balanceNum: balanceNum ?? this.balanceNum,
      balanceDenom: balanceDenom ?? this.balanceDenom,
    );
  }

  @override
  List<Object?> get props => [
        transactionId,
        date,
        description,
        reference,
        memo,
        debitNum,
        creditNum,
        denom,
        balanceNum,
        balanceDenom,
      ];
}

/// General Ledger report model for a single account.
///
/// Shows all transactions for an account within a date range,
/// with running balance calculated for each entry.
class GeneralLedger extends Equatable {
  /// Account ID
  final String accountId;
  
  /// Account name
  final String accountName;
  
  /// Account code (if any)
  final String? accountCode;
  
  /// Account type
  final AccountType accountType;
  
  /// List of ledger entries (transactions)
  final List<GeneralLedgerEntry> entries;
  
  /// Opening balance numerator (balance before start date)
  final int openingBalanceNum;
  
  /// Opening balance denominator
  final int openingBalanceDenom;
  
  /// Closing balance numerator (balance after all entries)
  final int closingBalanceNum;
  
  /// Closing balance denominator
  final int closingBalanceDenom;
  
  /// Total debits numerator for the period
  final int totalDebitsNum;
  
  /// Total credits numerator for the period
  final int totalCreditsNum;
  
  /// Common denominator for totals
  final int commonDenom;
  
  /// Report generation timestamp
  final DateTime generatedAt;
  
  /// Start date of the report period
  final DateTime? startDate;
  
  /// End date of the report period
  final DateTime? endDate;

  const GeneralLedger({
    required this.accountId,
    required this.accountName,
    this.accountCode,
    required this.accountType,
    required this.entries,
    required this.openingBalanceNum,
    required this.openingBalanceDenom,
    required this.closingBalanceNum,
    required this.closingBalanceDenom,
    required this.totalDebitsNum,
    required this.totalCreditsNum,
    required this.commonDenom,
    required this.generatedAt,
    this.startDate,
    this.endDate,
  });

  /// Converts the opening balance to a Decimal.
  Decimal get openingBalanceDecimal =>
      (Decimal.fromInt(openingBalanceNum) / Decimal.fromInt(openingBalanceDenom))
          .toDecimal();

  /// Converts the closing balance to a Decimal.
  Decimal get closingBalanceDecimal =>
      (Decimal.fromInt(closingBalanceNum) / Decimal.fromInt(closingBalanceDenom))
          .toDecimal();

  /// Converts the total debits to a Decimal.
  Decimal get totalDebitsDecimal =>
      (Decimal.fromInt(totalDebitsNum) / Decimal.fromInt(commonDenom))
          .toDecimal();

  /// Converts the total credits to a Decimal.
  Decimal get totalCreditsDecimal =>
      (Decimal.fromInt(totalCreditsNum) / Decimal.fromInt(commonDenom))
          .toDecimal();

  /// Returns true if there are no entries.
  bool get isEmpty => entries.isEmpty;

  /// Returns true if there are entries.
  bool get isNotEmpty => entries.isNotEmpty;

  /// Returns the number of entries.
  int get entryCount => entries.length;

  /// Creates a copy of this general ledger with the given fields replaced.
  GeneralLedger copyWith({
    String? accountId,
    String? accountName,
    String? accountCode,
    AccountType? accountType,
    List<GeneralLedgerEntry>? entries,
    int? openingBalanceNum,
    int? openingBalanceDenom,
    int? closingBalanceNum,
    int? closingBalanceDenom,
    int? totalDebitsNum,
    int? totalCreditsNum,
    int? commonDenom,
    DateTime? generatedAt,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return GeneralLedger(
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      accountCode: accountCode ?? this.accountCode,
      accountType: accountType ?? this.accountType,
      entries: entries ?? this.entries,
      openingBalanceNum: openingBalanceNum ?? this.openingBalanceNum,
      openingBalanceDenom: openingBalanceDenom ?? this.openingBalanceDenom,
      closingBalanceNum: closingBalanceNum ?? this.closingBalanceNum,
      closingBalanceDenom: closingBalanceDenom ?? this.closingBalanceDenom,
      totalDebitsNum: totalDebitsNum ?? this.totalDebitsNum,
      totalCreditsNum: totalCreditsNum ?? this.totalCreditsNum,
      commonDenom: commonDenom ?? this.commonDenom,
      generatedAt: generatedAt ?? this.generatedAt,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  @override
  List<Object?> get props => [
        accountId,
        accountName,
        accountCode,
        accountType,
        entries,
        openingBalanceNum,
        openingBalanceDenom,
        closingBalanceNum,
        closingBalanceDenom,
        totalDebitsNum,
        totalCreditsNum,
        commonDenom,
        generatedAt,
        startDate,
        endDate,
      ];
}

/// Raw split data with transaction info for general ledger calculation.
///
/// Used to pass data from database layer to calculator.
class GeneralLedgerSplitRaw {
  /// Split ID
  final String splitId;
  
  /// Transaction ID
  final String transactionId;
  
  /// Account ID
  final String accountId;
  
  /// Transaction post date (milliseconds since epoch)
  final int postDate;
  
  /// Transaction description
  final String? description;
  
  /// Transaction reference number
  final String? reference;
  
  /// Split memo
  final String? memo;
  
  /// Split value numerator
  final int valueNum;
  
  /// Split value denominator
  final int valueDenom;

  const GeneralLedgerSplitRaw({
    required this.splitId,
    required this.transactionId,
    required this.accountId,
    required this.postDate,
    this.description,
    this.reference,
    this.memo,
    required this.valueNum,
    required this.valueDenom,
  });

  /// Returns the date as DateTime.
  DateTime get date => DateTime.fromMillisecondsSinceEpoch(postDate);

  /// Returns the value as a decimal (for display purposes).
  double get value => valueNum / valueDenom.toDouble();
}
