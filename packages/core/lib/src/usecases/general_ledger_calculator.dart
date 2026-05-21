import '../models/general_ledger.dart';
import '../models/account.dart';

/// Calculator for generating general ledger reports.
///
/// Uses integer arithmetic (fractions) for precise calculations,
/// avoiding floating point precision issues.
class GeneralLedgerCalculator {
  /// Calculate general ledger for a single account.
  ///
  /// Parameters:
  /// - [account]: The account to generate the ledger for
  /// - [splits]: Raw split data with transaction info for this account
  /// - [openingBalanceNum]: Opening balance numerator (balance before start date)
  /// - [openingBalanceDenom]: Opening balance denominator
  /// - [startDate]: Optional start date for filtering transactions
  /// - [endDate]: Optional end date for filtering transactions
  ///
  /// Returns a [GeneralLedger] containing all entries with running balance.
  Future<GeneralLedger> calculate({
    required Account account,
    required List<GeneralLedgerSplitRaw> splits,
    int openingBalanceNum = 0,
    int openingBalanceDenom = 1,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Sort splits by date (ascending)
    final sortedSplits = List<GeneralLedgerSplitRaw>.from(splits)
      ..sort((a, b) => a.postDate.compareTo(b.postDate));

    // Calculate entries with running balance
    final entries = <GeneralLedgerEntry>[];
    
    // Running balance starts with opening balance
    int runningBalanceNum = openingBalanceNum;
    int runningBalanceDenom = openingBalanceDenom;
    
    // Totals for the period
    int totalDebitsNum = 0;
    int totalCreditsNum = 0;
    int commonDenom = 1;

    for (final split in sortedSplits) {
      // Determine debit and credit amounts
      // In double-entry: positive value = credit, negative value = debit
      int debitNum = 0;
      int creditNum = 0;
      
      if (split.valueNum < 0) {
        // Debit (negative value)
        debitNum = split.valueNum.abs();
      } else {
        // Credit (positive value)
        creditNum = split.valueNum;
      }

      // Update running balance
      // Balance = previous balance + credit - debit
      // Since valueNum is negative for debit, positive for credit:
      // Balance = previous balance + valueNum
      runningBalanceDenom = _lcm(runningBalanceDenom, split.valueDenom);
      final scaleRunning = runningBalanceDenom ~/ split.valueDenom;
      runningBalanceNum = runningBalanceNum * (runningBalanceDenom ~/ openingBalanceDenom) + split.valueNum * scaleRunning;

      // Update totals
      commonDenom = _lcm(commonDenom, split.valueDenom);

      // Create entry
      entries.add(GeneralLedgerEntry(
        transactionId: split.transactionId,
        date: split.date,
        description: split.description,
        reference: split.reference,
        memo: split.memo,
        debitNum: debitNum,
        creditNum: creditNum,
        denom: split.valueDenom,
        balanceNum: runningBalanceNum,
        balanceDenom: runningBalanceDenom,
      ));

      // Accumulate totals
      final scaleTotal = commonDenom ~/ split.valueDenom;
      totalDebitsNum += debitNum * scaleTotal;
      totalCreditsNum += creditNum * scaleTotal;
    }

    // Closing balance is the final running balance
    final closingBalanceNum = runningBalanceNum;
    final closingBalanceDenom = runningBalanceDenom;

    return GeneralLedger(
      accountId: account.id,
      accountName: account.name,
      accountCode: account.code,
      accountType: account.accountType,
      entries: entries,
      openingBalanceNum: openingBalanceNum,
      openingBalanceDenom: openingBalanceDenom,
      closingBalanceNum: closingBalanceNum,
      closingBalanceDenom: closingBalanceDenom,
      totalDebitsNum: totalDebitsNum,
      totalCreditsNum: totalCreditsNum,
      commonDenom: commonDenom,
      generatedAt: DateTime.now(),
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Calculate general ledger for multiple accounts (all accounts view).
  ///
  /// Parameters:
  /// - [accounts]: List of accounts to include
  /// - [splitsByAccount]: Map of account ID to list of splits
  /// - [openingBalances]: Map of account ID to opening balance (numerator, denominator)
  /// - [startDate]: Optional start date for filtering
  /// - [endDate]: Optional end date for filtering
  ///
  /// Returns a map from account ID to [GeneralLedger].
  Future<Map<String, GeneralLedger>> calculateAll({
    required List<Account> accounts,
    required Map<String, List<GeneralLedgerSplitRaw>> splitsByAccount,
    Map<String, (int, int)> openingBalances = const {},
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final result = <String, GeneralLedger>{};

    for (final account in accounts) {
      final splits = splitsByAccount[account.id] ?? [];
      final openingBalance = openingBalances[account.id] ?? (0, 1);

      final ledger = await calculate(
        account: account,
        splits: splits,
        openingBalanceNum: openingBalance.$1,
        openingBalanceDenom: openingBalance.$2,
        startDate: startDate,
        endDate: endDate,
      );

      result[account.id] = ledger;
    }

    return result;
  }

  /// Calculate opening balance for an account as of a specific date.
  ///
  /// Parameters:
  /// - [splitsBeforeDate]: Splits for the account before the start date
  ///
  /// Returns a tuple of (numerator, denominator) for the opening balance.
  (int, int) calculateOpeningBalance(List<GeneralLedgerSplitRaw> splitsBeforeDate) {
    if (splitsBeforeDate.isEmpty) {
      return (0, 1);
    }

    // Find common denominator
    int denom = 1;
    for (final split in splitsBeforeDate) {
      denom = _lcm(denom, split.valueDenom);
    }

    // Sum all values
    int totalNum = 0;
    for (final split in splitsBeforeDate) {
      final scale = denom ~/ split.valueDenom;
      totalNum += split.valueNum * scale;
    }

    return (totalNum, denom);
  }

  /// Group splits by transaction.
  ///
  /// Returns a map from transaction ID to list of splits.
  Map<String, List<GeneralLedgerSplitRaw>> groupByTransaction(
    List<GeneralLedgerSplitRaw> splits,
  ) {
    final result = <String, List<GeneralLedgerSplitRaw>>{};

    for (final split in splits) {
      result.putIfAbsent(split.transactionId, () => []).add(split);
    }

    return result;
  }

  /// Verify that the general ledger balances correctly.
  ///
  /// Checks that: Opening Balance + Total Credits - Total Debits = Closing Balance
  bool verifyBalance(GeneralLedger ledger) {
    // Scale all to common denominator
    final commonDenom = _lcm(
      _lcm(ledger.openingBalanceDenom, ledger.closingBalanceDenom),
      ledger.commonDenom,
    );

    final openingScaled = ledger.openingBalanceNum * (commonDenom ~/ ledger.openingBalanceDenom);
    final closingScaled = ledger.closingBalanceNum * (commonDenom ~/ ledger.closingBalanceDenom);
    final debitsScaled = ledger.totalDebitsNum * (commonDenom ~/ ledger.commonDenom);
    final creditsScaled = ledger.totalCreditsNum * (commonDenom ~/ ledger.commonDenom);

    // Opening + Credits - Debits should equal Closing
    final calculatedClosing = openingScaled + creditsScaled - debitsScaled;

    return calculatedClosing == closingScaled;
  }

  /// Calculate the Least Common Multiple of two numbers.
  int _lcm(int a, int b) {
    if (a == 0 || b == 0) return 1;
    return (a * b) ~/ _gcd(a, b);
  }

  /// Calculate the Greatest Common Divisor of two numbers.
  int _gcd(int a, int b) {
    a = a.abs();
    b = b.abs();
    while (b != 0) {
      final temp = b;
      b = a % b;
      a = temp;
    }
    return a;
  }
}
