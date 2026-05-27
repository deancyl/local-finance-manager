import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:database/database.dart' hide Account, AccountBalanceRaw;
import 'package:core/core.dart';
import '../../accounts/data/account_provider.dart';

// ============================================================
// DATE RANGE STATE PROVIDERS
// ============================================================

/// Start date for trial balance filtering (null = all time)
final trialBalanceStartDateProvider = StateProvider<DateTime?>((ref) => null);

/// End date for trial balance filtering (null = up to now)
final trialBalanceEndDateProvider = StateProvider<DateTime?>((ref) => null);

/// Data source for trial balance (splits or journal entries)
final trialBalanceSourceProvider = StateProvider<TrialBalanceSource>((ref) => TrialBalanceSource.splits);

// ============================================================
// TRIAL BALANCE DATA PROVIDER
// ============================================================

/// Provider for trial balance data with date range filtering
final trialBalanceProvider = AsyncNotifierProvider<TrialBalanceNotifier, TrialBalance?>(
  () => TrialBalanceNotifier(),
);

/// Notifier for managing trial balance state
class TrialBalanceNotifier extends AsyncNotifier<TrialBalance?> {
  late final LocalFinanceDatabase _db;
  late final TrialBalanceCalculator _calculator;

  @override
  TrialBalance? build() {
    _db = ref.watch(databaseProvider);
    _calculator = TrialBalanceCalculator();
    
    // Initial load
    _fetch();
    
    return null;
  }

  /// Fetch trial balance data from database
  Future<TrialBalance> _fetch() async {
    final startDate = ref.read(trialBalanceStartDateProvider);
    final endDate = ref.read(trialBalanceEndDateProvider);
    final source = ref.read(trialBalanceSourceProvider);

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

    List<AccountBalanceRaw> balances;

    if (source == TrialBalanceSource.journalEntries) {
      // Use journal entries as data source
      balances = await _getBalancesFromJournalEntries(accounts, startDate, endDate);
    } else {
      // Use splits as data source (default)
      balances = await _getBalancesFromSplits(startDate, endDate);
    }

    // Calculate trial balance
    final trialBalance = await _calculator.calculate(
      accounts: accounts,
      balances: balances,
      startDate: startDate,
      endDate: endDate,
    );

    // Update state
    state = AsyncValue.data(trialBalance);
    
    return trialBalance;
  }

  /// Get balances from splits (traditional single-entry approach)
  Future<List<AccountBalanceRaw>> _getBalancesFromSplits(
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    final rawBalances = await _db.splitsDao.getAccountBalances(
      startDate: startDate,
      endDate: endDate,
    );

    return rawBalances.map((raw) {
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
  }

  /// Get balances from journal entries (double-entry bookkeeping)
  Future<List<AccountBalanceRaw>> _getBalancesFromJournalEntries(
    List<Account> accounts,
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    final journalBalances = await _db.getJournalAccountBalances(
      startDate: startDate,
      endDate: endDate,
    );

    // Convert to AccountBalanceRaw format
    // Journal entries store amounts in cents (100 = 1 yuan)
    return journalBalances.map((jb) => AccountBalanceRaw(
      accountId: jb.accountId,
      debitNum: jb.debitAmount,
      creditNum: jb.creditAmount,
      denom: 100, // Amounts are in cents
    )).toList();
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

  /// Set data source and refresh
  Future<void> setSource(TrialBalanceSource source) async {
    ref.read(trialBalanceSourceProvider.notifier).state = source;
    await refresh();
  }
}

/// Data source for trial balance calculation
enum TrialBalanceSource {
  /// Traditional splits/transactions approach
  splits,
  
  /// Double-entry journal entries approach
  journalEntries,
}

/// Extension to get JournalAccountBalances from database
extension JournalEntriesDaoExtension on LocalFinanceDatabase {
  Future<List<JournalAccountBalance>> getJournalAccountBalances({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return JournalEntriesDao(this).getJournalAccountBalances(
      startDate: startDate,
      endDate: endDate,
    );
  }
}
