import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:database/database.dart' hide Account, AccountBalanceRaw;
import 'package:core/core.dart';
import '../../accounts/data/account_provider.dart';
import 'report_cache.dart';

// ============================================================
// DATE RANGE STATE PROVIDERS
// ============================================================

/// Start date for trial balance filtering (null = all time)
final trialBalanceStartDateProvider = StateProvider<DateTime?>((ref) => null);

/// End date for trial balance filtering (null = up to now)
final trialBalanceEndDateProvider = StateProvider<DateTime?>((ref) => null);

// ============================================================
// TRIAL BALANCE DATA PROVIDER
// ============================================================

/// Provider for trial balance data with date range filtering
final trialBalanceProvider = AsyncNotifierProvider<TrialBalanceNotifier, TrialBalance?>(
  () => TrialBalanceNotifier(),
);

/// Notifier for managing trial balance state with caching (v0.3.199)
class TrialBalanceNotifier extends AsyncNotifier<TrialBalance?> {
  late final LocalFinanceDatabase _db;
  late final TrialBalanceCalculator _calculator;
  late final ReportCacheService _cache;

  @override
  TrialBalance? build() {
    _db = ref.watch(databaseProvider);
    _calculator = TrialBalanceCalculator();
    _cache = ref.watch(reportCacheServiceProvider);
    
    // Listen for cache invalidation events
    ref.listen<DateTime?>(cacheInvalidationNotifierProvider, (_, timestamp) {
      if (timestamp != null) {
        refresh();
      }
    });
    
    // Initial load
    _fetch();
    
    return null;
  }

  /// Fetch trial balance data from database with caching
  Future<TrialBalance> _fetch() async {
    final startDate = ref.read(trialBalanceStartDateProvider);
    final endDate = ref.read(trialBalanceEndDateProvider);

    // Check cache first (v0.3.199)
    final cached = _cache.getTrialBalance(startDate: startDate, endDate: endDate);
    if (cached != null) {
      state = AsyncValue.data(cached);
      return cached;
    }

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

    // Calculate trial balance
    final trialBalance = await _calculator.calculate(
      accounts: accounts,
      balances: balances,
      startDate: startDate,
      endDate: endDate,
    );

    // Cache the result (v0.3.199)
    _cache.cacheTrialBalance(
      trialBalance,
      startDate: startDate,
      endDate: endDate,
    );

    // Update state
    state = AsyncValue.data(trialBalance);
    
    return trialBalance;
  }

  /// Refresh trial balance data
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
    ref.read(trialBalanceStartDateProvider.notifier).state = start;
    ref.read(trialBalanceEndDateProvider.notifier).state = end;
    await refresh();
  }
}
