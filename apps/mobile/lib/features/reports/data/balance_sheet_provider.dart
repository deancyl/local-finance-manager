import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:database/database.dart' hide Account, AccountBalanceRaw;
import 'package:core/core.dart';
import '../../accounts/data/account_provider.dart';
import 'currency_conversion_service.dart';

// ============================================================
// AS-OF DATE STATE PROVIDER
// ============================================================

/// As-of date for balance sheet (defaults to now)
final balanceSheetAsOfDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// ============================================================
// BALANCE SHEET DATA PROVIDER
// ============================================================

/// Provider for balance sheet data with as-of date filtering
final balanceSheetProvider = AsyncNotifierProvider<BalanceSheetNotifier, BalanceSheet?>(
  () => BalanceSheetNotifier(),
);

/// Notifier for managing balance sheet state
class BalanceSheetNotifier extends AsyncNotifier<BalanceSheet?> {
  late final LocalFinanceDatabase _db;
  late final BalanceSheetCalculator _calculator;
  late final CurrencyConversionService _currencyService;

  @override
  BalanceSheet? build() {
    _db = ref.watch(databaseProvider);
    _calculator = BalanceSheetCalculator();
    _currencyService = ref.watch(currencyConversionServiceProvider);
    
    // Initial load
    _fetch();
    
    return null;
  }

  /// Fetch balance sheet data from database using BalanceSheetDao
  Future<BalanceSheet> _fetch() async {
    final asOfDate = ref.read(balanceSheetAsOfDateProvider);
    final targetCurrency = ref.read(reportCurrencyProvider);

    // Get all accounts using accountsDao
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
      createdAt: DateTime.fromMillisecondsSinceEpoch(acc.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(acc.updatedAt),
      version: acc.version,
      liquidityType: _parseLiquidityType(acc.liquidityType),
    )).toList();

    // Get raw balances from BalanceSheetDao (preferred) or splitsDao as fallback
    List<AccountBalanceRaw> balances;
    
    try {
      // Try using the new BalanceSheetDao
      final balanceSheetData = await _db.balanceSheetDao.getAccountBalancesAsOfDate(asOfDate);
      
      // Convert BalanceSheetAccountData to AccountBalanceRaw with currency conversion
      balances = await _convertBalanceSheetDataToRaw(
        balanceSheetData,
        accounts,
        targetCurrency,
      );
    } catch (e) {
      // Fallback to splitsDao if BalanceSheetDao is not available
      final rawBalances = await _db.splitsDao.getAccountBalancesAsOfDate(asOfDate);
      
      balances = await _convertSplitsDataToRaw(
        rawBalances,
        accounts,
        targetCurrency,
      );
    }

    // Calculate balance sheet
    final balanceSheet = await _calculator.calculate(
      accounts: accounts,
      balances: balances,
      asOfDate: asOfDate,
    );

    // Update state
    state = AsyncValue.data(balanceSheet);
    
    return balanceSheet;
  }

  /// Convert BalanceSheetAccountData to AccountBalanceRaw with currency conversion
  Future<List<AccountBalanceRaw>> _convertBalanceSheetDataToRaw(
    List<BalanceSheetAccountData> data,
    List<Account> accounts,
    String targetCurrency,
  ) async {
    final balances = <AccountBalanceRaw>[];
    final accountMap = <String, Account>{
      for (final a in accounts) a.id: a,
    };

    for (final item in data) {
      // Get account's commodity for currency conversion
      final account = accountMap[item.accountId];
      if (account == null) continue;

      // Calculate debit and credit from balanceNum
      // In double-entry: positive = credit, negative = debit
      final totalNum = item.balanceNum;
      var debitNum = totalNum < 0 ? totalNum.abs() : 0;
      var creditNum = totalNum > 0 ? totalNum : 0;
      var denom = item.denom;

      // Convert to target currency if needed
      if (account.commodityId != targetCurrency) {
        final debitAmount = debitNum / denom.toDouble();
        final creditAmount = creditNum / denom.toDouble();
        
        final convertedDebit = await _currencyService.convertOrDefault(
          debitAmount,
          account.commodityId,
          targetCurrency,
        );
        final convertedCredit = await _currencyService.convertOrDefault(
          creditAmount,
          account.commodityId,
          targetCurrency,
        );
        
        // Convert back to integer (using 100 as denominator for cents)
        debitNum = (convertedDebit * 100).round();
        creditNum = (convertedCredit * 100).round();
        denom = 100;
      }

      balances.add(AccountBalanceRaw(
        accountId: item.accountId,
        debitNum: debitNum,
        creditNum: creditNum,
        denom: denom,
      ));
    }

    return balances;
  }

  /// Convert splitsDao AccountBalanceRaw to core AccountBalanceRaw with currency conversion
  Future<List<AccountBalanceRaw>> _convertSplitsDataToRaw(
    List<dynamic> rawBalances, // database.AccountBalanceRaw from splitsDao
    List<Account> accounts,
    String targetCurrency,
  ) async {
    final balances = <AccountBalanceRaw>[];
    final accountMap = <String, Account>{
      for (final a in accounts) a.id: a,
    };

    for (final raw in rawBalances) {
      // Get account's commodity for currency conversion
      final account = accountMap[raw.accountId];
      if (account == null) continue;

      // Calculate debit and credit from totalNum
      // In double-entry: positive = credit, negative = debit
      final totalNum = raw.totalNum;
      var debitNum = totalNum < 0 ? totalNum.abs() : 0;
      var creditNum = totalNum > 0 ? totalNum : 0;
      var denom = raw.valueDenom;

      // Convert to target currency if needed
      if (account.commodityId != targetCurrency) {
        final debitAmount = debitNum / denom.toDouble();
        final creditAmount = creditNum / denom.toDouble();
        
        final convertedDebit = await _currencyService.convertOrDefault(
          debitAmount,
          account.commodityId,
          targetCurrency,
        );
        final convertedCredit = await _currencyService.convertOrDefault(
          creditAmount,
          account.commodityId,
          targetCurrency,
        );
        
        // Convert back to integer (using 100 as denominator for cents)
        debitNum = (convertedDebit * 100).round();
        creditNum = (convertedCredit * 100).round();
        denom = 100;
      }

      balances.add(AccountBalanceRaw(
        accountId: raw.accountId,
        debitNum: debitNum,
        creditNum: creditNum,
        denom: denom,
      ));
    }

    return balances;
  }

  /// Parse liquidity type from database string
  LiquidityType _parseLiquidityType(String? value) {
    if (value == null) return LiquidityType.current;
    switch (value.toLowerCase()) {
      case 'current':
        return LiquidityType.current;
      case 'non_current':
      case 'non-current':
        return LiquidityType.nonCurrent;
      default:
        return LiquidityType.current;
    }
  }

  /// Refresh balance sheet data
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      await _fetch();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Set as-of date and refresh
  Future<void> setAsOfDate(DateTime date) async {
    ref.read(balanceSheetAsOfDateProvider.notifier).state = date;
    await refresh();
  }

  /// Set target currency and refresh
  Future<void> setCurrency(String currencyId) async {
    ref.read(reportCurrencyProvider.notifier).state = currencyId;
    await refresh();
  }
}