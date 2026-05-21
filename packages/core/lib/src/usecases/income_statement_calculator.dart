import '../models/account.dart';
import '../models/income_statement.dart';
import 'trial_balance_calculator.dart';

/// Calculator for generating income statement reports.
///
/// Uses integer arithmetic (fractions) for precise calculations,
/// avoiding floating point precision issues.
///
/// Income account balance = Credit - Debit (positive = income)
/// Expense account balance = Debit - Credit (positive = expense)
/// Net Income = Total Revenue - Total Expenses
class IncomeStatementCalculator {
  /// Calculate income statement for a date range.
  ///
  /// Parameters:
  /// - [accounts]: List of all accounts in the chart of accounts
  /// - [balances]: Raw balances for each account (from database)
  /// - [startDate]: Start date of the reporting period
  /// - [endDate]: End date of the reporting period
  ///
  /// Returns an [IncomeStatement] containing revenue and expense sections.
  Future<IncomeStatement> calculate({
    required List<Account> accounts,
    required List<AccountBalanceRaw> balances,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Calculate revenue section
    final revenues = calculateRevenues(accounts, balances);
    
    // Calculate expense section
    final expenses = calculateExpenses(accounts, balances);
    
    // Calculate net income
    final (netIncomeNum, denom) = calculateNetIncome(
      revenues.totalNum,
      revenues.denom,
      expenses.totalNum,
      expenses.denom,
    );
    
    return IncomeStatement(
      startDate: startDate,
      endDate: endDate,
      revenues: revenues,
      expenses: expenses,
      netIncomeNum: netIncomeNum,
      denom: denom,
      generatedAt: DateTime.now(),
    );
  }

  /// Calculate revenue section.
  ///
  /// Filters accounts by INCOME type and calculates:
  /// Revenue balance = Credit - Debit (positive = income)
  IncomeStatementSection calculateRevenues(
    List<Account> accounts,
    List<AccountBalanceRaw> balances,
  ) {
    // Filter income accounts
    final incomeAccounts = accounts
        .where((a) => a.accountType == AccountType.income && !a.isHidden)
        .toList();
    
    // Build account lookup map
    final accountMap = <String, Account>{
      for (final account in accounts) account.id: account,
    };
    
    // Build balance lookup map
    final balanceMap = <String, AccountBalanceRaw>{
      for (final balance in balances) balance.accountId: balance,
    };
    
    // Get root income accounts
    final rootIncomeAccounts = incomeAccounts
        .where((a) => a.parentId == null || 
            !incomeAccounts.any((parent) => parent.id == a.parentId))
        .toList();
    
    // Build hierarchical items
    final items = <IncomeStatementItem>[];
    for (final account in rootIncomeAccounts) {
      final item = _buildIncomeItem(account, accountMap, balanceMap);
      items.add(item);
    }
    
    // Calculate total using LCM for common denominator
    int commonDenom = 1;
    for (final item in items) {
      commonDenom = _lcm(commonDenom, item.denom);
    }
    
    int totalNum = 0;
    for (final item in items) {
      final scale = commonDenom ~/ item.denom;
      totalNum += item.amountNum * scale;
    }
    
    return IncomeStatementSection(
      title: '营业收入',
      items: items,
      totalNum: totalNum,
      denom: commonDenom,
    );
  }

  /// Calculate expense section.
  ///
  /// Filters accounts by EXPENSE type and calculates:
  /// Expense balance = Debit - Credit (positive = expense)
  IncomeStatementSection calculateExpenses(
    List<Account> accounts,
    List<AccountBalanceRaw> balances,
  ) {
    // Filter expense accounts
    final expenseAccounts = accounts
        .where((a) => a.accountType == AccountType.expense && !a.isHidden)
        .toList();
    
    // Build account lookup map
    final accountMap = <String, Account>{
      for (final account in accounts) account.id: account,
    };
    
    // Build balance lookup map
    final balanceMap = <String, AccountBalanceRaw>{
      for (final balance in balances) balance.accountId: balance,
    };
    
    // Get root expense accounts
    final rootExpenseAccounts = expenseAccounts
        .where((a) => a.parentId == null || 
            !expenseAccounts.any((parent) => parent.id == a.parentId))
        .toList();
    
    // Build hierarchical items
    final items = <IncomeStatementItem>[];
    for (final account in rootExpenseAccounts) {
      final item = _buildExpenseItem(account, accountMap, balanceMap);
      items.add(item);
    }
    
    // Calculate total using LCM for common denominator
    int commonDenom = 1;
    for (final item in items) {
      commonDenom = _lcm(commonDenom, item.denom);
    }
    
    int totalNum = 0;
    for (final item in items) {
      final scale = commonDenom ~/ item.denom;
      totalNum += item.amountNum * scale;
    }
    
    return IncomeStatementSection(
      title: '营业成本',
      items: items,
      totalNum: totalNum,
      denom: commonDenom,
    );
  }

  /// Calculate net income.
  ///
  /// Net Income = Total Revenue - Total Expenses
  /// Returns (numerator, denominator) tuple.
  (int, int) calculateNetIncome(
    int revenueTotalNum,
    int revenueTotalDenom,
    int expenseTotalNum,
    int expenseTotalDenom,
  ) {
    // Find common denominator
    final commonDenom = _lcm(revenueTotalDenom, expenseTotalDenom);
    
    // Scale to common denominator
    final scaledRevenue = revenueTotalNum * (commonDenom ~/ revenueTotalDenom);
    final scaledExpense = expenseTotalNum * (commonDenom ~/ expenseTotalDenom);
    
    // Net income = Revenue - Expense
    final netIncomeNum = scaledRevenue - scaledExpense;
    
    // Simplify the fraction
    final gcd = _gcd(netIncomeNum.abs(), commonDenom);
    
    return (netIncomeNum ~/ gcd, commonDenom ~/ gcd);
  }

  /// Build income item with hierarchical children.
  ///
  /// Income balance = Credit - Debit (positive = income)
  IncomeStatementItem _buildIncomeItem(
    Account account,
    Map<String, Account> accountMap,
    Map<String, AccountBalanceRaw> balanceMap,
  ) {
    // Find children
    final children = accountMap.values
        .where((a) => a.parentId == account.id && 
                      a.accountType == AccountType.income && 
                      !a.isHidden)
        .toList();
    
    // Build child items recursively
    final childItems = children
        .map((child) => _buildIncomeItem(child, accountMap, balanceMap))
        .toList();
    
    // Get raw balance for this account
    final rawBalance = balanceMap[account.id];
    
    // Income balance = Credit - Debit
    int balanceNum = 0;
    int balanceDenom = 1;
    
    if (rawBalance != null) {
      // Income: Credit - Debit (positive = income)
      balanceNum = rawBalance.creditNum - rawBalance.debitNum;
      balanceDenom = rawBalance.denom;
    }
    
    // Add child balances (aggregate)
    if (childItems.isNotEmpty) {
      // Find common denominator for aggregation
      balanceDenom = _lcm(balanceDenom, _findCommonDenom(childItems));
      
      // Scale and add child balances
      for (final child in childItems) {
        final scale = balanceDenom ~/ child.denom;
        balanceNum += child.amountNum * scale;
      }
    }
    
    return IncomeStatementItem(
      accountId: account.id,
      accountName: account.name,
      accountType: AccountType.income,
      amountNum: balanceNum,
      denom: balanceDenom,
      parentId: account.parentId,
      children: childItems.isEmpty ? null : childItems,
    );
  }

  /// Build expense item with hierarchical children.
  ///
  /// Expense balance = Debit - Credit (positive = expense)
  IncomeStatementItem _buildExpenseItem(
    Account account,
    Map<String, Account> accountMap,
    Map<String, AccountBalanceRaw> balanceMap,
  ) {
    // Find children
    final children = accountMap.values
        .where((a) => a.parentId == account.id && 
                      a.accountType == AccountType.expense && 
                      !a.isHidden)
        .toList();
    
    // Build child items recursively
    final childItems = children
        .map((child) => _buildExpenseItem(child, accountMap, balanceMap))
        .toList();
    
    // Get raw balance for this account
    final rawBalance = balanceMap[account.id];
    
    // Expense balance = Debit - Credit
    int balanceNum = 0;
    int balanceDenom = 1;
    
    if (rawBalance != null) {
      // Expense: Debit - Credit (positive = expense)
      balanceNum = rawBalance.debitNum - rawBalance.creditNum;
      balanceDenom = rawBalance.denom;
    }
    
    // Add child balances (aggregate)
    if (childItems.isNotEmpty) {
      // Find common denominator for aggregation
      balanceDenom = _lcm(balanceDenom, _findCommonDenom(childItems));
      
      // Scale and add child balances
      for (final child in childItems) {
        final scale = balanceDenom ~/ child.denom;
        balanceNum += child.amountNum * scale;
      }
    }
    
    return IncomeStatementItem(
      accountId: account.id,
      accountName: account.name,
      accountType: AccountType.expense,
      amountNum: balanceNum,
      denom: balanceDenom,
      parentId: account.parentId,
      children: childItems.isEmpty ? null : childItems,
    );
  }

  /// Find common denominator for a list of income statement items.
  int _findCommonDenom(List<IncomeStatementItem> items) {
    int denom = 1;
    for (final item in items) {
      denom = _lcm(denom, item.denom);
    }
    return denom;
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
