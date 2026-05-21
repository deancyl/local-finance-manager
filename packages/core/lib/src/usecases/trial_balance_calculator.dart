import '../models/trial_balance.dart';
import '../models/account.dart';
import '../models/split.dart';

/// Calculator for generating trial balance reports.
///
/// Uses integer arithmetic (fractions) for precise calculations,
/// avoiding floating point precision issues.
class TrialBalanceCalculator {
  /// Calculate trial balance for all accounts.
  ///
  /// Parameters:
  /// - [accounts]: List of all accounts in the chart of accounts
  /// - [balances]: Raw balances for each account (from database)
  /// - [startDate]: Optional start date for filtering transactions
  /// - [endDate]: Optional end date for filtering transactions
  ///
  /// Returns a [TrialBalance] containing all account balances and totals.
  Future<TrialBalance> calculate({
    required List<Account> accounts,
    required List<AccountBalanceRaw> balances,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Build account lookup map
    final accountMap = <String, Account>{
      for (final account in accounts) account.id: account,
    };

    // Build balance lookup map
    final balanceMap = <String, AccountBalanceRaw>{
      for (final balance in balances) balance.accountId: balance,
    };

    // Build hierarchical structure
    final rootAccounts = accounts.where((a) => a.parentId == null).toList();
    final accountBalances = <AccountBalance>[];

    // Calculate balances for each root account and its children
    for (final account in rootAccounts) {
      if (!account.isHidden) {
        final balance = _buildAccountBalance(
          account,
          accountMap,
          balanceMap,
        );
        accountBalances.add(balance);
      }
    }

    // Calculate totals using LCM for common denominator
    int commonDenom = 1;
    for (final balance in accountBalances) {
      commonDenom = _lcm(commonDenom, balance.denom);
    }

    int totalDebits = 0;
    int totalCredits = 0;

    for (final balance in accountBalances) {
      final scale = commonDenom ~/ balance.denom;
      totalDebits += balance.debitNum * scale;
      totalCredits += balance.creditNum * scale;
    }

    // Verify balance
    final isBalanced = totalDebits == totalCredits;

    return TrialBalance(
      accounts: accountBalances,
      totalDebits: totalDebits,
      totalCredits: totalCredits,
      commonDenom: commonDenom,
      isBalanced: isBalanced,
      generatedAt: DateTime.now(),
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Build account balance with hierarchical children.
  AccountBalance _buildAccountBalance(
    Account account,
    Map<String, Account> accountMap,
    Map<String, AccountBalanceRaw> balanceMap,
  ) {
    // Find children
    final children = accountMap.values
        .where((a) => a.parentId == account.id && !a.isHidden)
        .toList();

    // Build child balances recursively
    final childBalances = children
        .map((child) => _buildAccountBalance(child, accountMap, balanceMap))
        .toList();

    // Get raw balance for this account
    final rawBalance = balanceMap[account.id];

    int debitNum = 0;
    int creditNum = 0;
    int denom = 1;

    if (rawBalance != null) {
      debitNum = rawBalance.debitNum;
      creditNum = rawBalance.creditNum;
      denom = rawBalance.denom;
    }

    // Add child balances (aggregate)
    if (childBalances.isNotEmpty) {
      // Find common denominator for aggregation
      denom = _lcm(denom, _findCommonDenom(childBalances));

      // Scale and add child balances
      for (final child in childBalances) {
        final scale = denom ~/ child.denom;
        debitNum += child.debitNum * scale;
        creditNum += child.creditNum * scale;
      }
    }

    return AccountBalance(
      accountId: account.id,
      accountName: account.name,
      accountType: account.accountType,
      debitNum: debitNum,
      creditNum: creditNum,
      denom: denom,
      parentId: account.parentId,
      children: childBalances.isEmpty ? null : childBalances,
    );
  }

  /// Find common denominator for a list of account balances.
  int _findCommonDenom(List<AccountBalance> balances) {
    int denom = 1;
    for (final balance in balances) {
      denom = _lcm(denom, balance.denom);
    }
    return denom;
  }

  /// Calculate balance for a single account from splits.
  ///
  /// Parameters:
  /// - [account]: The account to calculate balance for
  /// - [splits]: List of splits for this account
  ///
  /// Returns an [AccountBalance] with calculated debit/credit totals.
  AccountBalance calculateAccountBalance(Account account, List<Split> splits) {
    if (splits.isEmpty) {
      return AccountBalance(
        accountId: account.id,
        accountName: account.name,
        accountType: account.accountType,
        debitNum: 0,
        creditNum: 0,
        denom: 1,
        parentId: account.parentId,
      );
    }

    // Find common denominator using LCM
    int commonDenom = 1;
    for (final split in splits) {
      commonDenom = _lcm(commonDenom, split.valueDenom);
    }

    // Sum debits and credits separately
    int debitNum = 0;
    int creditNum = 0;

    for (final split in splits) {
      final scaledNum = split.valueNum * (commonDenom ~/ split.valueDenom);

      // In double-entry: positive value = credit, negative value = debit
      // But for trial balance display, we show absolute values
      if (split.valueNum < 0) {
        // Debit (negative value)
        debitNum += scaledNum.abs();
      } else {
        // Credit (positive value)
        creditNum += scaledNum;
      }
    }

    return AccountBalance(
      accountId: account.id,
      accountName: account.name,
      accountType: account.accountType,
      debitNum: debitNum,
      creditNum: creditNum,
      denom: commonDenom,
      parentId: account.parentId,
    );
  }

  /// Group account balances by account type.
  ///
  /// Returns a map from [AccountType] to list of [AccountBalance].
  Map<AccountType, List<AccountBalance>> groupByType(
    List<AccountBalance> balances,
  ) {
    final result = <AccountType, List<AccountBalance>>{};

    for (final type in AccountType.values) {
      result[type] = [];
    }

    for (final balance in balances) {
      result[balance.accountType]!.add(balance);
    }

    return result;
  }

  /// Verify that the trial balance is balanced (debits = credits).
  ///
  /// Returns true if total debits equal total credits.
  bool verifyBalance(TrialBalance trialBalance) {
    return trialBalance.isBalanced;
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

/// Raw account balance data from database.
///
/// Represents the raw debit/credit totals for a single account
/// before hierarchical aggregation.
class AccountBalanceRaw {
  final String accountId;
  final int debitNum;
  final int creditNum;
  final int denom;

  const AccountBalanceRaw({
    required this.accountId,
    required this.debitNum,
    required this.creditNum,
    required this.denom,
  });

  /// Creates an empty balance (all zeros).
  const AccountBalanceRaw.empty(String accountId)
      : this(
          accountId: accountId,
          debitNum: 0,
          creditNum: 0,
          denom: 1,
        );
}
