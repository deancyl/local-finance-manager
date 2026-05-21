import '../models/account.dart';
import 'trial_balance_calculator.dart';

/// Income statement section containing line items and totals.
class IncomeStatementSection {
  /// List of account balances in this section
  final List<IncomeStatementLine> lines;
  
  /// Total numerator for this section
  final int totalNum;
  
  /// Common denominator for this section
  final int totalDenom;
  
  /// Section title (e.g., "营业收入", "营业成本")
  final String title;

  const IncomeStatementSection({
    required this.lines,
    required this.totalNum,
    required this.totalDenom,
    required this.title,
  });

  /// Get total as a decimal string for display
  String get totalDisplay => '${totalNum ~/ totalDenom}.${(totalNum % totalDenom).abs().toString().padLeft(2, '0')}';
}

/// Single line item in income statement.
class IncomeStatementLine {
  /// Account ID
  final String accountId;
  
  /// Account name
  final String accountName;
  
  /// Balance numerator
  final int balanceNum;
  
  /// Balance denominator
  final int balanceDenom;
  
  /// Account code (optional)
  final String? accountCode;
  
  /// Parent account ID (for hierarchy)
  final String? parentId;
  
  /// Child line items (for hierarchical accounts)
  final List<IncomeStatementLine>? children;

  const IncomeStatementLine({
    required this.accountId,
    required this.accountName,
    required this.balanceNum,
    required this.balanceDenom,
    this.accountCode,
    this.parentId,
    this.children,
  });

  /// Get balance as a decimal string for display
  String get balanceDisplay => '${balanceNum ~/ balanceDenom}.${(balanceNum % balanceDenom).abs().toString().padLeft(2, '0')}';
}

/// Income statement report.
class IncomeStatement {
  /// Revenue section
  final IncomeStatementSection revenueSection;
  
  /// Expense section
  final IncomeStatementSection expenseSection;
  
  /// Net income numerator
  final int netIncomeNum;
  
  /// Common denominator
  final int netIncomeDenom;
  
  /// Report generation timestamp
  final DateTime generatedAt;
  
  /// Start date of the reporting period
  final DateTime startDate;
  
  /// End date of the reporting period
  final DateTime endDate;

  const IncomeStatement({
    required this.revenueSection,
    required this.expenseSection,
    required this.netIncomeNum,
    required this.netIncomeDenom,
    required this.generatedAt,
    required this.startDate,
    required this.endDate,
  });

  /// Get net income as a decimal string for display
  String get netIncomeDisplay => '${netIncomeNum ~/ netIncomeDenom}.${(netIncomeNum % netIncomeDenom).abs().toString().padLeft(2, '0')}';
  
  /// Check if net income is positive (profit)
  bool get isProfit => netIncomeNum > 0;
  
  /// Check if net income is negative (loss)
  bool get isLoss => netIncomeNum < 0;
}

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
    final revenueSection = calculateRevenues(accounts, balances);
    
    // Calculate expense section
    final expenseSection = calculateExpenses(accounts, balances);
    
    // Calculate net income
    final (netIncomeNum, netIncomeDenom) = calculateNetIncome(
      revenueSection.totalNum,
      revenueSection.totalDenom,
      expenseSection.totalNum,
      expenseSection.totalDenom,
    );
    
    return IncomeStatement(
      revenueSection: revenueSection,
      expenseSection: expenseSection,
      netIncomeNum: netIncomeNum,
      netIncomeDenom: netIncomeDenom,
      generatedAt: DateTime.now(),
      startDate: startDate,
      endDate: endDate,
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
    
    // Build hierarchical lines
    final lines = <IncomeStatementLine>[];
    for (final account in rootIncomeAccounts) {
      final line = _buildIncomeLine(account, accountMap, balanceMap);
      lines.add(line);
    }
    
    // Calculate total using LCM for common denominator
    int commonDenom = 1;
    for (final line in lines) {
      commonDenom = _lcm(commonDenom, line.balanceDenom);
    }
    
    int totalNum = 0;
    for (final line in lines) {
      final scale = commonDenom ~/ line.balanceDenom;
      totalNum += line.balanceNum * scale;
    }
    
    return IncomeStatementSection(
      lines: lines,
      totalNum: totalNum,
      totalDenom: commonDenom,
      title: '营业收入',
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
    
    // Build hierarchical lines
    final lines = <IncomeStatementLine>[];
    for (final account in rootExpenseAccounts) {
      final line = _buildExpenseLine(account, accountMap, balanceMap);
      lines.add(line);
    }
    
    // Calculate total using LCM for common denominator
    int commonDenom = 1;
    for (final line in lines) {
      commonDenom = _lcm(commonDenom, line.balanceDenom);
    }
    
    int totalNum = 0;
    for (final line in lines) {
      final scale = commonDenom ~/ line.balanceDenom;
      totalNum += line.balanceNum * scale;
    }
    
    return IncomeStatementSection(
      lines: lines,
      totalNum: totalNum,
      totalDenom: commonDenom,
      title: '营业成本',
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

  /// Build income line with hierarchical children.
  ///
  /// Income balance = Credit - Debit (positive = income)
  IncomeStatementLine _buildIncomeLine(
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
    
    // Build child lines recursively
    final childLines = children
        .map((child) => _buildIncomeLine(child, accountMap, balanceMap))
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
    if (childLines.isNotEmpty) {
      // Find common denominator for aggregation
      balanceDenom = _lcm(balanceDenom, _findCommonDenom(childLines));
      
      // Scale and add child balances
      for (final child in childLines) {
        final scale = balanceDenom ~/ child.balanceDenom;
        balanceNum += child.balanceNum * scale;
      }
    }
    
    return IncomeStatementLine(
      accountId: account.id,
      accountName: account.name,
      balanceNum: balanceNum,
      balanceDenom: balanceDenom,
      accountCode: account.code,
      parentId: account.parentId,
      children: childLines.isEmpty ? null : childLines,
    );
  }

  /// Build expense line with hierarchical children.
  ///
  /// Expense balance = Debit - Credit (positive = expense)
  IncomeStatementLine _buildExpenseLine(
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
    
    // Build child lines recursively
    final childLines = children
        .map((child) => _buildExpenseLine(child, accountMap, balanceMap))
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
    if (childLines.isNotEmpty) {
      // Find common denominator for aggregation
      balanceDenom = _lcm(balanceDenom, _findCommonDenom(childLines));
      
      // Scale and add child balances
      for (final child in childLines) {
        final scale = balanceDenom ~/ child.balanceDenom;
        balanceNum += child.balanceNum * scale;
      }
    }
    
    return IncomeStatementLine(
      accountId: account.id,
      accountName: account.name,
      balanceNum: balanceNum,
      balanceDenom: balanceDenom,
      accountCode: account.code,
      parentId: account.parentId,
      children: childLines.isEmpty ? null : childLines,
    );
  }

  /// Find common denominator for a list of income statement lines.
  int _findCommonDenom(List<IncomeStatementLine> lines) {
    int denom = 1;
    for (final line in lines) {
      denom = _lcm(denom, line.balanceDenom);
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
