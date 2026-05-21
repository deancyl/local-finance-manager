import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:database/database.dart' hide Account, AccountBalanceRaw;
import 'package:core/core.dart';
import '../../accounts/data/account_provider.dart';

// ============================================================
// SELECTED ACCOUNT STATE PROVIDER
// ============================================================

/// Selected account ID for general ledger view (null = all accounts)
final generalLedgerSelectedAccountIdProvider = StateProvider<String?>((ref) => null);

// ============================================================
// DATE RANGE STATE PROVIDERS
// ============================================================

/// Start date for general ledger filtering (null = all time)
final generalLedgerStartDateProvider = StateProvider<DateTime?>((ref) => null);

/// End date for general ledger filtering (null = up to now)
final generalLedgerEndDateProvider = StateProvider<DateTime?>((ref) => null);

// ============================================================
// GENERAL LEDGER DATA PROVIDER
// ============================================================

/// Provider for general ledger data for selected account
final generalLedgerProvider = AsyncNotifierProvider<GeneralLedgerNotifier, GeneralLedger?>(
  () => GeneralLedgerNotifier(),
);

/// Notifier for managing general ledger state
class GeneralLedgerNotifier extends AsyncNotifier<GeneralLedger?> {
  late final LocalFinanceDatabase _db;
  late final GeneralLedgerCalculator _calculator;

  @override
  GeneralLedger? build() {
    _db = ref.watch(databaseProvider);
    _calculator = GeneralLedgerCalculator();

    // Initial load
    _fetch();

    return null;
  }

  /// Fetch general ledger data from database
  Future<GeneralLedger> _fetch() async {
    final accountId = ref.read(generalLedgerSelectedAccountIdProvider);
    final startDate = ref.read(generalLedgerStartDateProvider);
    final endDate = ref.read(generalLedgerEndDateProvider);

    if (accountId == null) {
      throw StateError('No account selected for general ledger');
    }

    // Get account info
    final accountData = await _db.accountsDao.getById(accountId);
    if (accountData == null) {
      throw StateError('Account not found: $accountId');
    }

    // Convert database Account to core Account model
    final account = Account(
      id: accountData.id,
      name: accountData.name,
      accountType: AccountType.values.firstWhere(
        (e) => e.code == accountData.accountType,
        orElse: () => AccountType.asset,
      ),
      parentId: accountData.parentId,
      commodityId: accountData.commodityId,
      code: accountData.code,
      description: accountData.description,
      isPlaceholder: accountData.isPlaceholder,
      isHidden: accountData.isHidden,
      sortOrder: accountData.sortOrder,
      createdAt: DateTime.fromMillisecondsSinceEpoch(accountData.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(accountData.updatedAt),
      version: accountData.version,
    );

    // Get splits with transaction info for the period
    final splitsData = await _db.splitsDao.getSplitsWithTransactionInfo(
      accountId,
      startDate: startDate,
      endDate: endDate,
    );

    // Convert to GeneralLedgerSplitRaw
    final splits = splitsData.map((data) => GeneralLedgerSplitRaw(
      splitId: data.splitId,
      transactionId: data.transactionId,
      accountId: data.accountId,
      postDate: data.postDate,
      description: data.description,
      reference: data.reference,
      memo: data.memo,
      valueNum: data.valueNum,
      valueDenom: data.valueDenom,
    )).toList();

    // Calculate opening balance (balance before start date)
    int openingBalanceNum = 0;
    int openingBalanceDenom = 1;

    if (startDate != null) {
      final splitsBeforeDate = await _db.splitsDao.getSplitsWithTransactionInfoBeforeDate(
        accountId,
        startDate,
      );

      final splitsBefore = splitsBeforeDate.map((data) => GeneralLedgerSplitRaw(
        splitId: data.splitId,
        transactionId: data.transactionId,
        accountId: data.accountId,
        postDate: data.postDate,
        description: data.description,
        reference: data.reference,
        memo: data.memo,
        valueNum: data.valueNum,
        valueDenom: data.valueDenom,
      )).toList();

      final (num, denom) = _calculator.calculateOpeningBalance(splitsBefore);
      openingBalanceNum = num;
      openingBalanceDenom = denom;
    }

    // Calculate general ledger
    final generalLedger = await _calculator.calculate(
      account: account,
      splits: splits,
      openingBalanceNum: openingBalanceNum,
      openingBalanceDenom: openingBalanceDenom,
      startDate: startDate,
      endDate: endDate,
    );

    // Update state
    state = AsyncValue.data(generalLedger);

    return generalLedger;
  }

  /// Refresh general ledger data
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      await _fetch();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Set selected account and refresh
  Future<void> setAccount(String? accountId) async {
    ref.read(generalLedgerSelectedAccountIdProvider.notifier).state = accountId;
    if (accountId != null) {
      await refresh();
    } else {
      state = const AsyncValue.data(null);
    }
  }

  /// Set date range and refresh
  Future<void> setDateRange(DateTime? start, DateTime? end) async {
    ref.read(generalLedgerStartDateProvider.notifier).state = start;
    ref.read(generalLedgerEndDateProvider.notifier).state = end;
    await refresh();
  }
}

// ============================================================
// ALL ACCOUNTS LIST PROVIDER (for account selector)
// ============================================================

/// Provider for all accounts for the account selector dropdown
final generalLedgerAccountsProvider = FutureProvider<List<Account>>((ref) async {
  final db = ref.watch(databaseProvider);

  final accountsData = await db.accountsDao.getAll();

  return accountsData.map((acc) => Account(
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
});
