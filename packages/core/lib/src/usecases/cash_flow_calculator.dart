import '../models/account.dart';
import '../models/cash_flow_statement.dart';
import 'trial_balance_calculator.dart';

/// Calculator for generating cash flow statement reports.
///
/// Uses the indirect method:
/// 1. Start from net income
/// 2. Adjust for non-cash items (depreciation, amortization)
/// 3. Adjust for working capital changes (accounts receivable, inventory, accounts payable)
/// 4. Add investing and financing activities
///
/// Uses integer arithmetic (fractions) for precise calculations,
/// avoiding floating point precision issues.
class CashFlowCalculator {
  /// Calculate cash flow statement for a date range.
  ///
  /// Parameters:
  /// - [accounts]: List of all accounts in the chart of accounts
  /// - [balances]: Raw balances for each account (from database)
  /// - [startDate]: Start date of the reporting period
  /// - [endDate]: End date of the reporting period
  /// - [netIncomeNum]: Net income numerator for the period
  /// - [netIncomeDenom]: Net income denominator
  /// - [beginningCashNum]: Beginning cash balance numerator
  /// - [beginningCashDenom]: Beginning cash balance denominator
  /// - [endingCashNum]: Ending cash balance numerator
  /// - [endingCashDenom]: Ending cash balance denominator
  ///
  /// Returns a [CashFlowStatement] containing all three activity sections.
  Future<CashFlowStatement> calculate({
    required List<Account> accounts,
    required List<AccountBalanceRaw> balances,
    required DateTime startDate,
    required DateTime endDate,
    required int netIncomeNum,
    required int netIncomeDenom,
    required int beginningCashNum,
    required int beginningCashDenom,
    required int endingCashNum,
    required int endingCashDenom,
  }) async {
    // Calculate operating activities section
    final operating = calculateOperatingActivities(
      accounts,
      balances,
      netIncomeNum,
      netIncomeDenom,
    );

    // Calculate investing activities section
    final investing = calculateInvestingActivities(accounts, balances);

    // Calculate financing activities section
    final financing = calculateFinancingActivities(accounts, balances);

    // Calculate net change in cash
    final commonDenom = _lcm(
      _lcm(operating.denom, investing.denom),
      financing.denom,
    );

    final scaledOperating = operating.netCashFlowNum * (commonDenom ~/ operating.denom);
    final scaledInvesting = investing.netCashFlowNum * (commonDenom ~/ investing.denom);
    final scaledFinancing = financing.netCashFlowNum * (commonDenom ~/ financing.denom);

    final netChangeNum = scaledOperating + scaledInvesting + scaledFinancing;

    return CashFlowStatement(
      startDate: startDate,
      endDate: endDate,
      operating: operating,
      investing: investing,
      financing: financing,
      beginningCashNum: beginningCashNum,
      netChangeInCashNum: netChangeNum,
      endingCashNum: endingCashNum,
      denom: commonDenom,
      generatedAt: DateTime.now(),
    );
  }

  /// Calculate operating activities section using indirect method.
  ///
  /// Starts with net income and adjusts for:
  /// - Non-cash items (depreciation, amortization)
  /// - Working capital changes
  CashFlowSection calculateOperatingActivities(
    List<Account> accounts,
    List<AccountBalanceRaw> balances,
    int netIncomeNum,
    int netIncomeDenom,
  ) {
    final items = <CashFlowItem>[];
    int commonDenom = netIncomeDenom;
    int netCashFlowNum = netIncomeNum;

    // Build balance lookup map
    final balanceMap = <String, AccountBalanceRaw>{
      for (final balance in balances) balance.accountId: balance,
    };

    // 1. Net Income (starting point)
    items.add(CashFlowItem(
      id: 'net_income',
      name: '净利润',
      activityType: CashFlowActivityType.operating,
      amountNum: netIncomeNum,
      denom: netIncomeDenom,
      isInflow: netIncomeNum >= 0,
      description: '利润表净利润',
    ));

    // 2. Adjust for non-cash items (depreciation, amortization)
    // These are expense accounts that don't involve cash
    final depreciationItems = _findNonCashExpenses(accounts, balanceMap);
    for (final item in depreciationItems) {
      items.add(item);
      commonDenom = _lcm(commonDenom, item.denom);
      final scaledAmount = item.amountNum * (commonDenom ~/ item.denom);
      netCashFlowNum = netCashFlowNum * (commonDenom ~/ netIncomeDenom) + scaledAmount;
    }

    // 3. Adjust for working capital changes
    final workingCapitalItems = _calculateWorkingCapitalChanges(accounts, balanceMap);
    for (final item in workingCapitalItems) {
      items.add(item);
      commonDenom = _lcm(commonDenom, item.denom);
      final scaledAmount = item.amountNum * (commonDenom ~/ item.denom);
      netCashFlowNum += scaledAmount;
    }

    // Calculate total inflows and outflows
    int totalInflowNum = 0;
    int totalOutflowNum = 0;
    for (final item in items) {
      final scale = commonDenom ~/ item.denom;
      if (item.isInflow) {
        totalInflowNum += item.amountNum * scale;
      } else {
        totalOutflowNum += item.amountNum * scale;
      }
    }

    return CashFlowSection(
      activityType: CashFlowActivityType.operating,
      title: '经营活动产生的现金流量',
      items: items,
      totalInflowNum: totalInflowNum,
      totalOutflowNum: totalOutflowNum,
      netCashFlowNum: netCashFlowNum,
      denom: commonDenom,
    );
  }

  /// Calculate investing activities section.
  ///
  /// Includes:
  /// - Purchase/sale of long-term assets
  /// - Purchase/sale of investments
  CashFlowSection calculateInvestingActivities(
    List<Account> accounts,
    List<AccountBalanceRaw> balances,
  ) {
    final items = <CashFlowItem>[];
    int commonDenom = 1;
    int netCashFlowNum = 0;

    // Build balance lookup map
    final balanceMap = <String, AccountBalanceRaw>{
      for (final balance in balances) balance.accountId: balance,
    };

    // Find non-current asset accounts (investing activities)
    final nonCurrentAssets = accounts.where((a) =>
        a.accountType == AccountType.asset &&
        a.liquidityType == LiquidityType.nonCurrent &&
        !a.isHidden);

    for (final account in nonCurrentAssets) {
      final balance = balanceMap[account.id];
      if (balance != null && (balance.debitNum > 0 || balance.creditNum > 0)) {
        // Debit = purchase (outflow), Credit = sale (inflow)
        if (balance.creditNum > 0) {
          // Sale of asset = cash inflow
          items.add(CashFlowItem(
            id: 'invest_inflow_${account.id}',
            name: '出售${account.name}',
            activityType: CashFlowActivityType.investing,
            amountNum: balance.creditNum,
            denom: balance.denom,
            isInflow: true,
          ));
          commonDenom = _lcm(commonDenom, balance.denom);
          netCashFlowNum += balance.creditNum * (commonDenom ~/ balance.denom);
        }
        if (balance.debitNum > 0) {
          // Purchase of asset = cash outflow
          items.add(CashFlowItem(
            id: 'invest_outflow_${account.id}',
            name: '购入${account.name}',
            activityType: CashFlowActivityType.investing,
            amountNum: balance.debitNum,
            denom: balance.denom,
            isInflow: false,
          ));
          commonDenom = _lcm(commonDenom, balance.denom);
          netCashFlowNum -= balance.debitNum * (commonDenom ~/ balance.denom);
        }
      }
    }

    // Calculate total inflows and outflows
    int totalInflowNum = 0;
    int totalOutflowNum = 0;
    for (final item in items) {
      final scale = commonDenom ~/ item.denom;
      if (item.isInflow) {
        totalInflowNum += item.amountNum * scale;
      } else {
        totalOutflowNum += item.amountNum * scale;
      }
    }

    return CashFlowSection(
      activityType: CashFlowActivityType.investing,
      title: '投资活动产生的现金流量',
      items: items,
      totalInflowNum: totalInflowNum,
      totalOutflowNum: totalOutflowNum,
      netCashFlowNum: netCashFlowNum,
      denom: commonDenom,
    );
  }

  /// Calculate financing activities section.
  ///
  /// Includes:
  /// - Borrowing/repayment of debt
  /// - Equity transactions (issuance, repurchase, dividends)
  CashFlowSection calculateFinancingActivities(
    List<Account> accounts,
    List<AccountBalanceRaw> balances,
  ) {
    final items = <CashFlowItem>[];
    int commonDenom = 1;
    int netCashFlowNum = 0;

    // Build balance lookup map
    final balanceMap = <String, AccountBalanceRaw>{
      for (final balance in balances) balance.accountId: balance,
    };

    // Find liability accounts (borrowing/repayment)
    final liabilities = accounts.where((a) =>
        a.accountType == AccountType.liability &&
        !a.isHidden);

    for (final account in liabilities) {
      final balance = balanceMap[account.id];
      if (balance != null && (balance.debitNum > 0 || balance.creditNum > 0)) {
        // Credit = borrowing (inflow), Debit = repayment (outflow)
        if (balance.creditNum > 0) {
          // Borrowing = cash inflow
          items.add(CashFlowItem(
            id: 'finance_inflow_${account.id}',
            name: '借入${account.name}',
            activityType: CashFlowActivityType.financing,
            amountNum: balance.creditNum,
            denom: balance.denom,
            isInflow: true,
          ));
          commonDenom = _lcm(commonDenom, balance.denom);
          netCashFlowNum += balance.creditNum * (commonDenom ~/ balance.denom);
        }
        if (balance.debitNum > 0) {
          // Repayment = cash outflow
          items.add(CashFlowItem(
            id: 'finance_outflow_${account.id}',
            name: '偿还${account.name}',
            activityType: CashFlowActivityType.financing,
            amountNum: balance.debitNum,
            denom: balance.denom,
            isInflow: false,
          ));
          commonDenom = _lcm(commonDenom, balance.denom);
          netCashFlowNum -= balance.debitNum * (commonDenom ~/ balance.denom);
        }
      }
    }

    // Find equity accounts (issuance, dividends)
    final equities = accounts.where((a) =>
        a.accountType == AccountType.equity &&
        !a.isHidden);

    for (final account in equities) {
      final balance = balanceMap[account.id];
      if (balance != null && (balance.debitNum > 0 || balance.creditNum > 0)) {
        // Credit = equity issuance (inflow), Debit = dividends/repurchase (outflow)
        if (balance.creditNum > 0) {
          // Equity issuance = cash inflow
          items.add(CashFlowItem(
            id: 'equity_inflow_${account.id}',
            name: '发行${account.name}',
            activityType: CashFlowActivityType.financing,
            amountNum: balance.creditNum,
            denom: balance.denom,
            isInflow: true,
          ));
          commonDenom = _lcm(commonDenom, balance.denom);
          netCashFlowNum += balance.creditNum * (commonDenom ~/ balance.denom);
        }
        if (balance.debitNum > 0) {
          // Dividends/repurchase = cash outflow
          items.add(CashFlowItem(
            id: 'equity_outflow_${account.id}',
            name: '分配${account.name}',
            activityType: CashFlowActivityType.financing,
            amountNum: balance.debitNum,
            denom: balance.denom,
            isInflow: false,
          ));
          commonDenom = _lcm(commonDenom, balance.denom);
          netCashFlowNum -= balance.debitNum * (commonDenom ~/ balance.denom);
        }
      }
    }

    // Calculate total inflows and outflows
    int totalInflowNum = 0;
    int totalOutflowNum = 0;
    for (final item in items) {
      final scale = commonDenom ~/ item.denom;
      if (item.isInflow) {
        totalInflowNum += item.amountNum * scale;
      } else {
        totalOutflowNum += item.amountNum * scale;
      }
    }

    return CashFlowSection(
      activityType: CashFlowActivityType.financing,
      title: '筹资活动产生的现金流量',
      items: items,
      totalInflowNum: totalInflowNum,
      totalOutflowNum: totalOutflowNum,
      netCashFlowNum: netCashFlowNum,
      denom: commonDenom,
    );
  }

  /// Find non-cash expense items (depreciation, amortization).
  ///
  /// These are added back to net income in the indirect method.
  List<CashFlowItem> _findNonCashExpenses(
    List<Account> accounts,
    Map<String, AccountBalanceRaw> balanceMap,
  ) {
    final items = <CashFlowItem>[];

    // Look for expense accounts with keywords indicating non-cash items
    final nonCashKeywords = ['折旧', '摊销', '减值', 'depreciation', 'amortization', 'impairment'];

    final nonCashExpenses = accounts.where((a) =>
        a.accountType == AccountType.expense &&
        !a.isHidden &&
        nonCashKeywords.any((keyword) =>
            a.name.toLowerCase().contains(keyword.toLowerCase())));

    for (final account in nonCashExpenses) {
      final balance = balanceMap[account.id];
      if (balance != null && balance.debitNum > 0) {
        // Non-cash expense: add back (inflow adjustment)
        items.add(CashFlowItem(
          id: 'noncash_${account.id}',
          name: '加：${account.name}',
          activityType: CashFlowActivityType.operating,
          amountNum: balance.debitNum,
          denom: balance.denom,
          isInflow: true,
          description: '非现金费用调整',
        ));
      }
    }

    return items;
  }

  /// Calculate working capital changes.
  ///
  /// Changes in:
  /// - Accounts receivable (increase = outflow, decrease = inflow)
  /// - Inventory (increase = outflow, decrease = inflow)
  /// - Accounts payable (increase = inflow, decrease = outflow)
  /// - Prepaid expenses (increase = outflow, decrease = inflow)
  List<CashFlowItem> _calculateWorkingCapitalChanges(
    List<Account> accounts,
    Map<String, AccountBalanceRaw> balanceMap,
  ) {
    final items = <CashFlowItem>[];

    // Find current asset accounts (excluding cash)
    final currentAssets = accounts.where((a) =>
        a.accountType == AccountType.asset &&
        a.liquidityType == LiquidityType.current &&
        !a.isHidden);

    for (final account in currentAssets) {
      final balance = balanceMap[account.id];
      if (balance != null && (balance.debitNum > 0 || balance.creditNum > 0)) {
        // For current assets:
        // Debit increase = cash outflow (asset increase)
        // Credit increase = cash inflow (asset decrease)
        final netChange = balance.debitNum - balance.creditNum;
        if (netChange != 0) {
          items.add(CashFlowItem(
            id: 'wc_asset_${account.id}',
            name: netChange > 0
                ? '减：${account.name}增加'
                : '加：${account.name}减少',
            activityType: CashFlowActivityType.operating,
            amountNum: netChange.abs(),
            denom: balance.denom,
            isInflow: netChange < 0,
            description: '营运资金变动',
          ));
        }
      }
    }

    // Find current liability accounts
    final currentLiabilities = accounts.where((a) =>
        a.accountType == AccountType.liability &&
        a.liquidityType == LiquidityType.current &&
        !a.isHidden);

    for (final account in currentLiabilities) {
      final balance = balanceMap[account.id];
      if (balance != null && (balance.debitNum > 0 || balance.creditNum > 0)) {
        // For current liabilities:
        // Credit increase = cash inflow (liability increase)
        // Debit increase = cash outflow (liability decrease)
        final netChange = balance.creditNum - balance.debitNum;
        if (netChange != 0) {
          items.add(CashFlowItem(
            id: 'wc_liab_${account.id}',
            name: netChange > 0
                ? '加：${account.name}增加'
                : '减：${account.name}减少',
            activityType: CashFlowActivityType.operating,
            amountNum: netChange.abs(),
            denom: balance.denom,
            isInflow: netChange > 0,
            description: '营运资金变动',
          ));
        }
      }
    }

    return items;
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
