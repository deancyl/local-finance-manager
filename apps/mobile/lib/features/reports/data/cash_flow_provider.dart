import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:database/database.dart' hide Account, AccountBalanceRaw, LiquidityType;
import 'package:core/core.dart';
import '../../accounts/data/account_provider.dart';
import 'income_statement_provider.dart';

// ============================================================
// DATE RANGE STATE PROVIDERS
// ============================================================

/// Start date for cash flow statement filtering (null = all time)
final cashFlowStatementStartDateProvider = StateProvider<DateTime?>((ref) => null);

/// End date for cash flow statement filtering (null = up to now)
final cashFlowStatementEndDateProvider = StateProvider<DateTime?>((ref) => null);

// ============================================================
// CASH FLOW STATEMENT DATA PROVIDER
// ============================================================

/// Provider for cash flow statement data with date range filtering
final cashFlowStatementProvider = AsyncNotifierProvider<CashFlowStatementNotifier, CashFlowStatement?>(
  () => CashFlowStatementNotifier(),
);

/// Notifier for managing cash flow statement state
class CashFlowStatementNotifier extends AsyncNotifier<CashFlowStatement?> {
  late final LocalFinanceDatabase _db;
  late final CashFlowCalculator _calculator;
  late final IncomeStatementCalculator _incomeCalculator;

  @override
  CashFlowStatement? build() {
    _db = ref.watch(databaseProvider);
    _calculator = CashFlowCalculator();
    _incomeCalculator = IncomeStatementCalculator();
    
    // Initial load
    _fetch();
    
    return null;
  }

  /// Fetch cash flow statement data from database
  Future<CashFlowStatement> _fetch() async {
    final startDate = ref.read(cashFlowStatementStartDateProvider);
    final endDate = ref.read(cashFlowStatementEndDateProvider);

    // Get all accounts
    final accountsData = await _db.accountsDao.getAll();
    
    // Convert database Account to core Account model
    final accounts = accountsData.map((acc) => Account(
      id: acc.id,
      name: acc.name,
      accountType: AccountType.values.firstWhere(
        (e) => e.code == acc.accountType,
        orElse: () => AccountType.asset,
      ),
      parentId: acc.parentId,
      commodityId: acc.commodityId,
      code: acc.code,
      description: acc.description,
      isPlaceholder: acc.isPlaceholder,
      isHidden: acc.isHidden,
      sortOrder: acc.sortOrder,
      liquidityType: LiquidityType.values.firstWhere(
        (e) => e.code == acc.liquidityType,
        orElse: () => LiquidityType.current,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(acc.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(acc.updatedAt),
      version: acc.version,
    )).toList();

    // Get raw balances from splits
    final rawBalances = await _db.splitsDao.getAccountBalances(
      startDate: startDate,
      endDate: endDate,
    );

    // Convert database AccountBalanceRaw to core AccountBalanceRaw
    final balances = rawBalances.map((raw) {
      // Calculate debit and credit from totalNum
      // In double-entry: positive = credit, negative = debit
      final totalNum = raw.totalNum;
      final debitNum = totalNum < 0 ? totalNum.abs() : 0;
      final creditNum = totalNum > 0 ? totalNum : 0;
      
      return AccountBalanceRaw(
        accountId: raw.accountId,
        debitNum: debitNum,
        creditNum: creditNum,
        denom: raw.valueDenom,
      );
    }).toList();

    // Calculate income statement for net income
    final incomeStatement = await _incomeCalculator.calculate(
      accounts: accounts,
      balances: balances,
      startDate: startDate ?? DateTime(1970, 1, 1),
      endDate: endDate ?? DateTime.now(),
    );

    // Get beginning and ending cash balances
    // For simplicity, we'll use asset account balances as cash
    final cashAccounts = accounts.where((a) => 
        a.accountType == AccountType.asset && 
        a.liquidityType == LiquidityType.current &&
        !a.isPlaceholder);
    
    int beginningCashNum = 0;
    int beginningCashDenom = 1;
    int endingCashNum = 0;
    int endingCashDenom = 1;
    
    // Calculate ending cash from current balances
    for (final balance in balances) {
      final account = accounts.firstWhere(
        (a) => a.id == balance.accountId,
        orElse: () => accounts.first,
      );
      
      if (account.accountType == AccountType.asset && 
          account.liquidityType == LiquidityType.current) {
        // Asset balance = Debit - Credit (positive = asset)
        final netBalance = balance.debitNum - balance.creditNum;
        endingCashDenom = _lcm(endingCashDenom, balance.denom);
        endingCashNum += netBalance * (endingCashDenom ~/ balance.denom);
      }
    }
    
    // For beginning cash, we'd need historical balances
    // For now, we'll calculate it from ending cash minus net change
    // This is a simplified approach - in production, you'd query historical data
    
    // Calculate cash flow statement
    final cashFlowStatement = await _calculator.calculate(
      accounts: accounts,
      balances: balances,
      startDate: startDate ?? DateTime(1970, 1, 1),
      endDate: endDate ?? DateTime.now(),
      netIncomeNum: incomeStatement.netIncomeNum,
      netIncomeDenom: incomeStatement.denom,
      beginningCashNum: beginningCashNum,
      beginningCashDenom: beginningCashDenom,
      endingCashNum: endingCashNum,
      endingCashDenom: endingCashDenom,
    );

    // Update state
    state = AsyncValue.data(cashFlowStatement);
    
    return cashFlowStatement;
  }

  /// Refresh cash flow statement data
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      await _fetch();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Set date range and refresh
  Future<void> setDateRange(DateTime? start, DateTime? end) async {
    ref.read(cashFlowStatementStartDateProvider.notifier).state = start;
    ref.read(cashFlowStatementEndDateProvider.notifier).state = end;
    await refresh();
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
