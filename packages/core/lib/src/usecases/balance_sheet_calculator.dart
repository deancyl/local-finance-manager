import '../models/balance_sheet.dart';
import '../models/account.dart';
import 'trial_balance_calculator.dart' show AccountBalanceRaw;

/// Calculator for generating balance sheet reports.
///
/// Uses integer arithmetic (fractions) for precise calculations,
/// avoiding floating point precision issues.
///
/// Balance calculation logic:
/// - 资产类账户余额 = 借方发生额 - 贷方发生额 (借方余额为正)
/// - 负债类账户余额 = 贷方发生额 - 借方发生额 (贷方余额为正)
/// - 权益类账户余额 = 贷方发生额 - 借方发生额 (贷方余额为正)
/// - 本期利润 = 收入类账户余额 - 费用类账户余额 (自动转入"未分配利润")
/// - 平衡验证: 资产总计 = 负债合计 + 权益总计
class BalanceSheetCalculator {
  /// Calculate balance sheet as of a specific date.
  ///
  /// Parameters:
  /// - [accounts]: List of all accounts in the chart of accounts
  /// - [balances]: Raw balances for each account (from database)
  /// - [asOfDate]: The date for which to calculate the balance sheet
  ///
  /// Returns a [BalanceSheet] containing assets, liabilities, and equity sections.
  Future<BalanceSheet> calculate({
    required List<Account> accounts,
    required List<AccountBalanceRaw> balances,
    required DateTime asOfDate,
  }) async {
    // Build account lookup map
    final accountMap = <String, Account>{
      for (final account in accounts) account.id: account,
    };

    // Build balance lookup map
    final balanceMap = <String, AccountBalanceRaw>{
      for (final balance in balances) balance.accountId: balance,
    };

    // Calculate each section
    final assetsSection = calculateSection(
      accounts,
      balances,
      AccountType.asset,
    );

    final liabilitiesSection = calculateSection(
      accounts,
      balances,
      AccountType.liability,
    );

    // Calculate equity section (includes retained earnings from income/expense)
    final equitySection = _calculateEquitySection(
      accounts,
      accountMap,
      balanceMap,
    );

    // Verify balance
    final isBalanced = verifyBalance(
      BalanceSheet(
        asOfDate: asOfDate,
        assets: assetsSection,
        liabilities: liabilitiesSection,
        equity: equitySection,
        isBalanced: false, // Will be set properly below
        generatedAt: DateTime.now(),
      ),
    );

    return BalanceSheet(
      asOfDate: asOfDate,
      assets: assetsSection,
      liabilities: liabilitiesSection,
      equity: equitySection,
      isBalanced: isBalanced,
      generatedAt: DateTime.now(),
    );
  }

  /// Calculate a balance sheet section (assets, liabilities, or equity).
  ///
  /// Parameters:
  /// - [accounts]: List of all accounts
  /// - [balances]: Raw balances for each account
  /// - [type]: The account type to calculate for
  ///
  /// Returns a [BalanceSheetSection] with items and total.
  BalanceSheetSection calculateSection(
    List<Account> accounts,
    List<AccountBalanceRaw> balances,
    AccountType type,
  ) {
    // Filter accounts by type
    final filteredAccounts = accounts.where((a) => a.accountType == type).toList();

    // Build account lookup map
    final accountMap = <String, Account>{
      for (final account in accounts) account.id: account,
    };

    // Build balance lookup map
    final balanceMap = <String, AccountBalanceRaw>{
      for (final balance in balances) balance.accountId: balance,
    };

    // Get root accounts of this type
    final rootAccounts = filteredAccounts
        .where((a) => a.parentId == null || accountMap[a.parentId]?.accountType != type)
        .toList();

    // Build balance sheet items with hierarchy
    final items = <BalanceSheetItem>[];
    for (final account in rootAccounts) {
      if (!account.isHidden) {
        final item = _buildBalanceSheetItem(
          account,
          accountMap,
          balanceMap,
          type,
        );
        items.add(item);
      }
    }

    // Calculate total using LCM for common denominator
    int commonDenom = 1;
    for (final item in items) {
      commonDenom = _lcm(commonDenom, item.denom);
    }

    int totalNum = 0;
    for (final item in items) {
      final scale = commonDenom ~/ item.denom;
      totalNum += item.balanceNum * scale;
    }

    // Determine section title
    final title = _getSectionTitle(type);

    return BalanceSheetSection(
      title: title,
      items: items,
      totalNum: totalNum,
      denom: commonDenom,
    );
  }

  /// Calculate equity section including retained earnings from income/expense.
  BalanceSheetSection _calculateEquitySection(
    List<Account> accounts,
    Map<String, Account> accountMap,
    Map<String, AccountBalanceRaw> balanceMap,
  ) {
    // Get equity accounts
    final equityAccounts = accounts.where((a) => a.accountType == AccountType.equity).toList();

    // Get root equity accounts
    final rootEquityAccounts = equityAccounts
        .where((a) => a.parentId == null || accountMap[a.parentId]?.accountType != AccountType.equity)
        .toList();

    // Build balance sheet items for equity accounts
    final items = <BalanceSheetItem>[];
    for (final account in rootEquityAccounts) {
      if (!account.isHidden) {
        final item = _buildBalanceSheetItem(
          account,
          accountMap,
          balanceMap,
          AccountType.equity,
        );
        items.add(item);
      }
    }

    // Calculate retained earnings from income and expense accounts
    final retainedEarningsItem = _calculateRetainedEarnings(
      accounts,
      accountMap,
      balanceMap,
    );

    if (retainedEarningsItem != null) {
      items.add(retainedEarningsItem);
    }

    // Calculate total using LCM for common denominator
    int commonDenom = 1;
    for (final item in items) {
      commonDenom = _lcm(commonDenom, item.denom);
    }

    int totalNum = 0;
    for (final item in items) {
      final scale = commonDenom ~/ item.denom;
      totalNum += item.balanceNum * scale;
    }

    return BalanceSheetSection(
      title: '所有者权益',
      items: items,
      totalNum: totalNum,
      denom: commonDenom,
    );
  }

  /// Calculate retained earnings from income and expense accounts.
  ///
  /// 本期利润 = 收入类账户余额 - 费用类账户余额
  BalanceSheetItem? _calculateRetainedEarnings(
    List<Account> accounts,
    Map<String, Account> accountMap,
    Map<String, AccountBalanceRaw> balanceMap,
  ) {
    // Get income accounts
    final incomeAccounts = accounts.where((a) => a.accountType == AccountType.income).toList();
    // Get expense accounts
    final expenseAccounts = accounts.where((a) => a.accountType == AccountType.expense).toList();

    if (incomeAccounts.isEmpty && expenseAccounts.isEmpty) {
      return null;
    }

    // Calculate total income (credit balance for income accounts)
    int incomeTotalNum = 0;
    int incomeDenom = 1;
    for (final account in incomeAccounts) {
      final rawBalance = balanceMap[account.id];
      if (rawBalance != null) {
        incomeDenom = _lcm(incomeDenom, rawBalance.denom);
      }
    }
    for (final account in incomeAccounts) {
      final rawBalance = balanceMap[account.id];
      if (rawBalance != null) {
        final scale = incomeDenom ~/ rawBalance.denom;
        // Income: credit balance = credit - debit (positive = profit)
        incomeTotalNum += (rawBalance.creditNum - rawBalance.debitNum) * scale;
      }
    }

    // Calculate total expense (debit balance for expense accounts)
    int expenseTotalNum = 0;
    int expenseDenom = 1;
    for (final account in expenseAccounts) {
      final rawBalance = balanceMap[account.id];
      if (rawBalance != null) {
        expenseDenom = _lcm(expenseDenom, rawBalance.denom);
      }
    }
    for (final account in expenseAccounts) {
      final rawBalance = balanceMap[account.id];
      if (rawBalance != null) {
        final scale = expenseDenom ~/ rawBalance.denom;
        // Expense: debit balance = debit - credit (positive = expense)
        expenseTotalNum += (rawBalance.debitNum - rawBalance.creditNum) * scale;
      }
    }

    // Calculate retained earnings: Income - Expense
    final commonDenom = _lcm(incomeDenom, expenseDenom);
    final incomeScaled = incomeTotalNum * (commonDenom ~/ incomeDenom);
    final expenseScaled = expenseTotalNum * (commonDenom ~/ expenseDenom);
    final retainedEarningsNum = incomeScaled - expenseScaled;

    // Only create item if there's a balance
    if (retainedEarningsNum == 0) {
      return null;
    }

    return BalanceSheetItem(
      accountId: 'retained_earnings', // Special ID for calculated item
      accountName: '本期利润',
      accountType: AccountType.equity,
      liquidityType: LiquidityType.current,
      balanceNum: retainedEarningsNum,
      denom: commonDenom,
      parentId: null,
      children: null,
    );
  }

  /// Build a balance sheet item with hierarchical children.
  BalanceSheetItem _buildBalanceSheetItem(
    Account account,
    Map<String, Account> accountMap,
    Map<String, AccountBalanceRaw> balanceMap,
    AccountType sectionType,
  ) {
    // Find children of the same type
    final children = accountMap.values
        .where((a) => a.parentId == account.id && a.accountType == sectionType && !a.isHidden)
        .toList();

    // Build child items recursively
    final childItems = children
        .map((child) => _buildBalanceSheetItem(child, accountMap, balanceMap, sectionType))
        .toList();

    // Get raw balance for this account
    final rawBalance = balanceMap[account.id];

    int balanceNum = 0;
    int denom = 1;

    if (rawBalance != null) {
      // Calculate balance based on account type
      // 资产类账户余额 = 借方发生额 - 贷方发生额 (借方余额为正)
      // 负债类账户余额 = 贷方发生额 - 借方发生额 (贷方余额为正)
      // 权益类账户余额 = 贷方发生额 - 借方发生额 (贷方余额为正)
      if (sectionType == AccountType.asset) {
        balanceNum = rawBalance.debitNum - rawBalance.creditNum;
      } else {
        // Liability and Equity: credit balance
        balanceNum = rawBalance.creditNum - rawBalance.debitNum;
      }
      denom = rawBalance.denom;
    }

    // Add child balances (aggregate)
    if (childItems.isNotEmpty) {
      // Find common denominator for aggregation
      denom = _lcm(denom, _findCommonDenom(childItems));

      // Scale and add child balances
      for (final child in childItems) {
        final scale = denom ~/ child.denom;
        balanceNum += child.balanceNum * scale;
      }
    }

    return BalanceSheetItem(
      accountId: account.id,
      accountName: account.name,
      accountType: account.accountType,
      liquidityType: account.liquidityType,
      balanceNum: balanceNum,
      denom: denom,
      parentId: account.parentId,
      children: childItems.isEmpty ? null : childItems,
    );
  }

  /// Find common denominator for a list of balance sheet items.
  int _findCommonDenom(List<BalanceSheetItem> items) {
    int denom = 1;
    for (final item in items) {
      denom = _lcm(denom, item.denom);
    }
    return denom;
  }

  /// Group balance sheet items by liquidity type.
  ///
  /// Parameters:
  /// - [items]: List of balance sheet items to group
  ///
  /// Returns a map from [LiquidityType] to list of [BalanceSheetItem].
  Map<LiquidityType, List<BalanceSheetItem>> groupByLiquidity(
    List<BalanceSheetItem> items,
  ) {
    final result = <LiquidityType, List<BalanceSheetItem>>{
      LiquidityType.current: [],
      LiquidityType.nonCurrent: [],
    };

    for (final item in items) {
      result[item.liquidityType]!.add(item);
    }

    return result;
  }

  /// Verify that the balance sheet balances.
  ///
  /// 平衡验证: 资产总计 = 负债合计 + 权益总计
  ///
  /// Returns true if assets equal liabilities plus equity.
  bool verifyBalance(BalanceSheet balanceSheet) {
    // Get common denominator for all three sections
    final commonDenom = _lcm(
      _lcm(balanceSheet.assets.denom, balanceSheet.liabilities.denom),
      balanceSheet.equity.denom,
    );

    // Scale all totals to common denominator
    final assetsTotal = balanceSheet.assets.totalNum * (commonDenom ~/ balanceSheet.assets.denom);
    final liabilitiesTotal = balanceSheet.liabilities.totalNum * (commonDenom ~/ balanceSheet.liabilities.denom);
    final equityTotal = balanceSheet.equity.totalNum * (commonDenom ~/ balanceSheet.equity.denom);

    // Verify: Assets = Liabilities + Equity
    return assetsTotal == liabilitiesTotal + equityTotal;
  }

  /// Get section title for account type.
  String _getSectionTitle(AccountType type) {
    switch (type) {
      case AccountType.asset:
        return '资产';
      case AccountType.liability:
        return '负债';
      case AccountType.equity:
        return '所有者权益';
      case AccountType.income:
        return '收入';
      case AccountType.expense:
        return '支出';
    }
  }

  /// Calculate the Least Common Multiple of two numbers.
  int _lcm(int a, int b) {
    if (a == 0 || b == 0) return 1;
    return (a * b).abs() ~/ _gcd(a, b);
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
