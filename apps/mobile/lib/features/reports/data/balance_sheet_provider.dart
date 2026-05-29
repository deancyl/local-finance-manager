import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide AccountBalanceRaw, LiquidityType;
import 'package:database/database.dart' hide Account, AccountBalanceRaw, LiquidityType;
import 'package:core/core.dart';
import '../../accounts/data/account_provider.dart';
import 'currency_conversion_service.dart';

// ============================================================
// CALCULATION SOURCE STATE PROVIDER
// ============================================================

/// Calculation source for balance sheet (single-entry or double-entry)
final balanceSheetCalculationSourceProvider = StateProvider<BalanceSheetDataSource>(
  (ref) => BalanceSheetDataSource.singleEntry,
);

// ============================================================
// AS-OF DATE STATE PROVIDER
// ============================================================

/// As-of date for balance sheet (defaults to now)
final balanceSheetAsOfDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// ============================================================
// COMPARISON MODE STATE PROVIDER
// ============================================================

/// Comparison period for balance sheet (optional previous period)
final balanceSheetComparisonDateProvider = StateProvider<DateTime?>((ref) => null);

/// Whether comparison mode is enabled
final balanceSheetComparisonEnabledProvider = StateProvider<bool>((ref) => false);

// ============================================================
// BALANCE SHEET DATA PROVIDER
// ============================================================

/// Provider for balance sheet data with as-of date filtering
final balanceSheetProvider = AsyncNotifierProvider<BalanceSheetNotifier, BalanceSheet?>(
  () => BalanceSheetNotifier(),
);

/// Provider for comparison balance sheet data
final balanceSheetComparisonProvider = AsyncNotifierProvider<BalanceSheetComparisonNotifier, BalanceSheet?>(
  () => BalanceSheetComparisonNotifier(),
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
    
    // Listen to calculation source changes
    ref.listen<BalanceSheetDataSource>(balanceSheetCalculationSourceProvider, (_, __) {
      refresh();
    });
    
    // Listen to comparison mode changes
    ref.listen<bool>(balanceSheetComparisonEnabledProvider, (_, __) {
      refresh();
    });
    
    // Initial load
    _fetch();
    
    return null;
  }

  /// Fetch balance sheet data from database using BalanceSheetDao
  Future<BalanceSheet> _fetch() async {
    final asOfDate = ref.read(balanceSheetAsOfDateProvider);
    final targetCurrency = ref.read(reportCurrencyProvider);
    final calculationSource = ref.read(balanceSheetCalculationSourceProvider);

    // Use double-entry calculation if selected
    if (calculationSource == BalanceSheetDataSource.doubleEntry) {
      return _fetchFromJournalEntries(asOfDate, targetCurrency);
    }

    // Otherwise use single-entry calculation
    return _fetchFromSingleEntry(asOfDate, targetCurrency);
  }

  /// Fetch balance sheet from journal entries (double-entry bookkeeping)
  Future<BalanceSheet> _fetchFromJournalEntries(DateTime asOfDate, String targetCurrency) async {
    try {
      // Get balance sheet data from journal entries
      final journalData = await _db.balanceSheetDao.getBalanceSheetFromJournalEntries(
        asOfDate: asOfDate,
      );

      // Count posted journal entries
      final postedEntriesCount = await _countPostedJournalEntries(asOfDate);

      // Convert to BalanceSheet model
      return _convertJournalDataToBalanceSheet(
        journalData,
        targetCurrency,
        postedEntriesCount,
      );
    } catch (e) {
      // Fallback to single-entry if journal entries not available
      return _fetchFromSingleEntry(asOfDate, targetCurrency);
    }
  }

  /// Count posted journal entries up to the as-of date
  Future<int> _countPostedJournalEntries(DateTime asOfDate) async {
    final asOfDateMs = asOfDate.millisecondsSinceEpoch;
    final query = _db.select(_db.journalEntries)
      ..where((e) => 
          e.isPosted.equals(true) &
          e.postDate.isSmallerOrEqualValue(asOfDateMs) &
          e.deletedAt.isNull());
    
    final results = await query.get();
    return results.length;
  }

  /// Convert journal entry data to BalanceSheet model
  BalanceSheet _convertJournalDataToBalanceSheet(
    BalanceSheetFromJournalData journalData,
    String targetCurrency,
    int journalEntryCount,
  ) {
    // Convert assets
    final assetItems = journalData.assetBalances.map((b) => BalanceSheetItem(
      accountId: b.accountId,
      accountName: b.accountName,
      accountType: AccountType.asset,
      liquidityType: b.isCurrent ? LiquidityType.current : LiquidityType.nonCurrent,
      balanceNum: b.balanceNum,
      denom: b.denom,
      parentId: b.parentId,
      children: null,
    )).toList();

    // Convert liabilities
    final liabilityItems = journalData.liabilityBalances.map((b) => BalanceSheetItem(
      accountId: b.accountId,
      accountName: b.accountName,
      accountType: AccountType.liability,
      liquidityType: b.isCurrent ? LiquidityType.current : LiquidityType.nonCurrent,
      balanceNum: b.balanceNum,
      denom: b.denom,
      parentId: b.parentId,
      children: null,
    )).toList();

    // Convert equity (including retained earnings)
    final equityItems = journalData.equityBalances.map((b) => BalanceSheetItem(
      accountId: b.accountId,
      accountName: b.accountName,
      accountType: AccountType.equity,
      liquidityType: LiquidityType.current,
      balanceNum: b.balanceNum,
      denom: b.denom,
      parentId: b.parentId,
      children: null,
    )).toList();

    // Determine validation status
    BalanceSheetValidationStatus validationStatus;
    if (journalData.assetBalances.isEmpty && 
        journalData.liabilityBalances.isEmpty && 
        journalData.equityBalances.isEmpty) {
      validationStatus = BalanceSheetValidationStatus.noData;
    } else if (journalData.difference < 0.01) {
      validationStatus = BalanceSheetValidationStatus.balanced;
    } else if (journalData.difference < 1.0) {
      validationStatus = BalanceSheetValidationStatus.essentiallyBalanced;
    } else {
      validationStatus = BalanceSheetValidationStatus.unbalanced;
    }

    return BalanceSheet(
      asOfDate: journalData.asOfDate,
      assets: BalanceSheetSection(
        title: '资产',
        items: assetItems,
        totalNum: journalData.totalAssetsNum,
        denom: journalData.denom,
      ),
      liabilities: BalanceSheetSection(
        title: '负债',
        items: liabilityItems,
        totalNum: journalData.totalLiabilitiesNum,
        denom: journalData.denom,
      ),
      equity: BalanceSheetSection(
        title: '所有者权益',
        items: equityItems,
        totalNum: journalData.totalEquityNum,
        denom: journalData.denom,
      ),
      isBalanced: journalData.isBalanced,
      generatedAt: DateTime.now(),
      dataSource: BalanceSheetDataSource.doubleEntry,
      validationStatus: validationStatus,
      differenceAmount: Decimal.fromJson(journalData.difference.toStringAsFixed(2)),
      journalEntryCount: journalEntryCount,
      showRetainedEarnings: journalData.retainedEarnings.retainedEarnings != 0,
    );
  }

  /// Fetch balance sheet from single-entry transactions/splits
  Future<BalanceSheet> _fetchFromSingleEntry(DateTime asOfDate, String targetCurrency) async {
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

    // Update with single-entry data source
    final result = balanceSheet.copyWith(
      dataSource: BalanceSheetDataSource.singleEntry,
      validationStatus: balanceSheet.isBalanced 
          ? BalanceSheetValidationStatus.balanced 
          : BalanceSheetValidationStatus.unbalanced,
    );

    // Update state
    state = AsyncValue.data(result);
    
    return result;
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

  /// Set calculation source and refresh
  Future<void> setCalculationSource(BalanceSheetDataSource source) async {
    ref.read(balanceSheetCalculationSourceProvider.notifier).state = source;
    await refresh();
  }

  /// Toggle comparison mode
  Future<void> setComparisonEnabled(bool enabled) async {
    ref.read(balanceSheetComparisonEnabledProvider.notifier).state = enabled;
    await refresh();
  }

  /// Set comparison date
  Future<void> setComparisonDate(DateTime? date) async {
    ref.read(balanceSheetComparisonDateProvider.notifier).state = date;
    await refresh();
  }
}

/// Notifier for managing comparison balance sheet state
class BalanceSheetComparisonNotifier extends AsyncNotifier<BalanceSheet?> {
  late final LocalFinanceDatabase _db;
  late final BalanceSheetCalculator _calculator;
  late final CurrencyConversionService _currencyService;

  @override
  BalanceSheet? build() {
    _db = ref.watch(databaseProvider);
    _calculator = BalanceSheetCalculator();
    _currencyService = ref.watch(currencyConversionServiceProvider);
    
    // Listen to comparison date changes
    ref.listen<DateTime?>(balanceSheetComparisonDateProvider, (_, __) {
      refresh();
    });
    
    // Listen to calculation source changes
    ref.listen<BalanceSheetDataSource>(balanceSheetCalculationSourceProvider, (_, __) {
      refresh();
    });
    
    // Listen to comparison enabled changes
    ref.listen<bool>(balanceSheetComparisonEnabledProvider, (_, __) {
      refresh();
    });
    
    return null;
  }

  /// Refresh comparison balance sheet
  Future<void> refresh() async {
    final comparisonDate = ref.read(balanceSheetComparisonDateProvider);
    final comparisonEnabled = ref.read(balanceSheetComparisonEnabledProvider);
    
    if (!comparisonEnabled || comparisonDate == null) {
      state = const AsyncValue.data(null);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final targetCurrency = ref.read(reportCurrencyProvider);
      final calculationSource = ref.read(balanceSheetCalculationSourceProvider);

      // Fetch comparison based on calculation source
      if (calculationSource == BalanceSheetDataSource.doubleEntry) {
        final journalData = await _db.balanceSheetDao.getBalanceSheetFromJournalEntries(
          asOfDate: comparisonDate,
        );
        final postedEntriesCount = await _countPostedJournalEntries(comparisonDate);
        final balanceSheet = _convertJournalDataToBalanceSheet(
          journalData,
          targetCurrency,
          postedEntriesCount,
        );
        state = AsyncValue.data(balanceSheet);
      } else {
        // Single-entry comparison
        final accountsData = await _db.accountsDao.getAll();
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

        final balanceSheetData = await _db.balanceSheetDao.getAccountBalancesAsOfDate(comparisonDate);
        final balances = await _convertBalanceSheetDataToRaw(
          balanceSheetData,
          accounts,
          targetCurrency,
        );

        final balanceSheet = await _calculator.calculate(
          accounts: accounts,
          balances: balances,
          asOfDate: comparisonDate,
        );

        state = AsyncValue.data(balanceSheet.copyWith(
          dataSource: BalanceSheetDataSource.singleEntry,
        ));
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<int> _countPostedJournalEntries(DateTime asOfDate) async {
    final asOfDateMs = asOfDate.millisecondsSinceEpoch;
    final query = _db.select(_db.journalEntries)
      ..where((e) => 
          e.isPosted.equals(true) &
          e.postDate.isSmallerOrEqualValue(asOfDateMs) &
          e.deletedAt.isNull());
    
    final results = await query.get();
    return results.length;
  }

  BalanceSheet _convertJournalDataToBalanceSheet(
    BalanceSheetFromJournalData journalData,
    String targetCurrency,
    int journalEntryCount,
  ) {
    // Convert assets
    final assetItems = journalData.assetBalances.map((b) => BalanceSheetItem(
      accountId: b.accountId,
      accountName: b.accountName,
      accountType: AccountType.asset,
      liquidityType: b.isCurrent ? LiquidityType.current : LiquidityType.nonCurrent,
      balanceNum: b.balanceNum,
      denom: b.denom,
      parentId: b.parentId,
      children: null,
    )).toList();

    // Convert liabilities
    final liabilityItems = journalData.liabilityBalances.map((b) => BalanceSheetItem(
      accountId: b.accountId,
      accountName: b.accountName,
      accountType: AccountType.liability,
      liquidityType: b.isCurrent ? LiquidityType.current : LiquidityType.nonCurrent,
      balanceNum: b.balanceNum,
      denom: b.denom,
      parentId: b.parentId,
      children: null,
    )).toList();

    // Convert equity
    final equityItems = journalData.equityBalances.map((b) => BalanceSheetItem(
      accountId: b.accountId,
      accountName: b.accountName,
      accountType: AccountType.equity,
      liquidityType: LiquidityType.current,
      balanceNum: b.balanceNum,
      denom: b.denom,
      parentId: b.parentId,
      children: null,
    )).toList();

    // Determine validation status
    BalanceSheetValidationStatus validationStatus;
    if (journalData.assetBalances.isEmpty && 
        journalData.liabilityBalances.isEmpty && 
        journalData.equityBalances.isEmpty) {
      validationStatus = BalanceSheetValidationStatus.noData;
    } else if (journalData.difference < 0.01) {
      validationStatus = BalanceSheetValidationStatus.balanced;
    } else if (journalData.difference < 1.0) {
      validationStatus = BalanceSheetValidationStatus.essentiallyBalanced;
    } else {
      validationStatus = BalanceSheetValidationStatus.unbalanced;
    }

    return BalanceSheet(
      asOfDate: journalData.asOfDate,
      assets: BalanceSheetSection(
        title: '资产',
        items: assetItems,
        totalNum: journalData.totalAssetsNum,
        denom: journalData.denom,
      ),
      liabilities: BalanceSheetSection(
        title: '负债',
        items: liabilityItems,
        totalNum: journalData.totalLiabilitiesNum,
        denom: journalData.denom,
      ),
      equity: BalanceSheetSection(
        title: '所有者权益',
        items: equityItems,
        totalNum: journalData.totalEquityNum,
        denom: journalData.denom,
      ),
      isBalanced: journalData.isBalanced,
      generatedAt: DateTime.now(),
      dataSource: BalanceSheetDataSource.doubleEntry,
      validationStatus: validationStatus,
      differenceAmount: Decimal.fromJson(journalData.difference.toStringAsFixed(2)),
      journalEntryCount: journalEntryCount,
      showRetainedEarnings: journalData.retainedEarnings.retainedEarnings != 0,
    );
  }

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
      final account = accountMap[item.accountId];
      if (account == null) continue;

      final totalNum = item.balanceNum;
      var debitNum = totalNum < 0 ? totalNum.abs() : 0;
      var creditNum = totalNum > 0 ? totalNum : 0;
      var denom = item.denom;

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
}