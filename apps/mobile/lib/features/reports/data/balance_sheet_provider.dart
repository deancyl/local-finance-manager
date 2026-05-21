import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:database/database.dart';
import 'package:core/core.dart';
import '../../accounts/data/account_provider.dart';

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

  @override
  BalanceSheet? build() {
    _db = ref.watch(databaseProvider);
    _calculator = BalanceSheetCalculator();
    
    // Initial load
    _fetch();
    
    return null;
  }

  /// Fetch balance sheet data from database
  Future<BalanceSheet> _fetch() async {
    final asOfDate = ref.read(balanceSheetAsOfDateProvider);

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

    // Get raw balances from splits as of the specified date
    final rawBalances = await _db.splitsDao.getAccountBalancesAsOfDate(asOfDate);

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
}
