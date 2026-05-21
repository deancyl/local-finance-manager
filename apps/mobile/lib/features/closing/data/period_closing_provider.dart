import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import 'package:database/database.dart' hide Account, Transaction, Split, ClosingEntry;
import 'package:database/database.dart' as db show ClosingEntry;
import 'package:core/core.dart';
import '../../accounts/data/account_provider.dart';

/// Provider for the closing entry service.
final closingEntryServiceProvider = Provider<ClosingEntryService>((ref) {
  final db = ref.watch(databaseProvider);
  final accountRepo = _DatabaseAccountRepository(db);
  final transactionRepo = _DatabaseTransactionRepository(db);
  return ClosingEntryService(
    accountRepository: accountRepo,
    transactionRepository: transactionRepo,
  );
});

/// Fiscal period status for closing workflow.
enum PeriodStatus {
  open,
  closed,
  partiallyClosed,
}

/// Fiscal period model for closing workflow.
class FiscalPeriod {
  final String id;
  final int year;
  final int month;
  final PeriodStatus status;
  final DateTime? closedAt;
  final String? closedBy;
  final int closedEntryCount;

  FiscalPeriod({
    required this.id,
    required this.year,
    required this.month,
    required this.status,
    this.closedAt,
    this.closedBy,
    this.closedEntryCount = 0,
  });

  String get displayName => '$year年${month.toString().padLeft(2, '0')}月';

  bool get isClosed => status == PeriodStatus.closed;

  bool get canReopen => status == PeriodStatus.closed;

  DateTime get startDate => DateTime(year, month, 1);

  DateTime get endDate => DateTime(year, month + 1, 0, 23, 59, 59, 999);
}

/// State for period closing workflow.
class PeriodClosingState {
  final List<FiscalPeriod> periods;
  final FiscalPeriod? selectedPeriod;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  PeriodClosingState({
    this.periods = const [],
    this.selectedPeriod,
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  PeriodClosingState copyWith({
    List<FiscalPeriod>? periods,
    FiscalPeriod? selectedPeriod,
    bool? isLoading,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return PeriodClosingState(
      periods: periods ?? this.periods,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      successMessage: clearSuccess ? null : successMessage ?? this.successMessage,
    );
  }

  /// Gets the current open period (most recent open period).
  FiscalPeriod? get currentOpenPeriod {
    final openPeriods = periods.where((p) => p.status == PeriodStatus.open).toList()
      ..sort((a, b) {
        // Sort by year/month descending
        final compare = b.year.compareTo(a.year);
        return compare != 0 ? compare : b.month.compareTo(a.month);
      });
    return openPeriods.isNotEmpty ? openPeriods.first : null;
  }

  /// Gets closed periods sorted by date (most recent first).
  List<FiscalPeriod> get closedPeriods {
    return periods.where((p) => p.status == PeriodStatus.closed).toList()
      ..sort((a, b) {
        final compare = b.year.compareTo(a.year);
        return compare != 0 ? compare : b.month.compareTo(a.month);
      });
  }
}

/// Notifier for managing period closing workflow.
class PeriodClosingNotifier extends StateNotifier<PeriodClosingState> {
  final LocalFinanceDatabase _db;
  final ClosingEntryService _service;

  PeriodClosingNotifier(this._db, this._service) : super(PeriodClosingState()) {
    _loadPeriods();
  }

  /// Loads all fiscal periods.
  Future<void> _loadPeriods() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Get all closing entries to determine period status
      final closingEntries = await _db.closingEntriesDao.getAll();

      // Group by fiscal period
      final periodMap = <String, List<db.ClosingEntry>>{};
      for (final entry in closingEntries) {
        periodMap.putIfAbsent(entry.fiscalPeriodId, () => []).add(entry);
      }

      // Generate periods for the last 24 months and next 3 months
      final now = DateTime.now();
      final periods = <FiscalPeriod>[];

      for (var i = -24; i <= 3; i++) {
        final date = DateTime(now.year, now.month + i, 1);
        final periodId = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        final entries = periodMap[periodId] ?? [];

        // Determine status
        PeriodStatus status;
        if (entries.isEmpty) {
          status = PeriodStatus.open;
        } else {
          final executedCount = entries.where((e) => e.status == 'EXECUTED').length;
          if (executedCount == entries.length && entries.isNotEmpty) {
            status = PeriodStatus.closed;
          } else if (executedCount > 0) {
            status = PeriodStatus.partiallyClosed;
          } else {
            status = PeriodStatus.open;
          }
        }

        // Find the most recent executed entry for closedAt
        DateTime? closedAt;
        if (status == PeriodStatus.closed) {
          final executedEntries = entries.where((e) => e.status == 'EXECUTED').toList()
            ..sort((a, b) => b.executedAt.compareTo(a.executedAt));
          if (executedEntries.isNotEmpty) {
            closedAt = DateTime.fromMillisecondsSinceEpoch(executedEntries.first.executedAt);
          }
        }

        periods.add(FiscalPeriod(
          id: periodId,
          year: date.year,
          month: date.month,
          status: status,
          closedAt: closedAt,
          closedEntryCount: entries.where((e) => e.status == 'EXECUTED').length,
        ));
      }

      state = state.copyWith(
        periods: periods,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '加载期间失败: $e',
      );
    }
  }

  /// Selects a period for viewing details.
  void selectPeriod(FiscalPeriod? period) {
    state = state.copyWith(selectedPeriod: period);
  }

  /// Closes a fiscal period.
  Future<bool> closePeriod(FiscalPeriod period) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      // Get trial balance for the period
      final trialBalanceCalculator = TrialBalanceCalculator(
        accountRepository: _DatabaseAccountRepository(_db),
        transactionRepository: _DatabaseTransactionRepository(_db),
      );

      final trialBalance = await trialBalanceCalculator.calculate(
        startDate: period.startDate,
        endDate: period.endDate,
      );

      // Validate trial balance
      if (!trialBalance.isBalanced) {
        state = state.copyWith(
          isLoading: false,
          error: '试算不平衡，无法结账。借方: ${trialBalance.totalDebit.toStringAsFixed(2)}, 贷方: ${trialBalance.totalCredit.toStringAsFixed(2)}',
        );
        return false;
      }

      // Get default commodity
      final commodities = await _db.commoditiesDao.getAll();
      final commodityId = commodities.isNotEmpty ? commodities.first.id : 'CNY';

      // Generate closing entries
      final closingEntries = await _service.generateClosingEntries(
        fiscalPeriodId: period.id,
        balances: trialBalance.accounts.map((a) => AccountBalanceRaw(
          accountId: a.accountId,
          debitNum: (a.debit * 100).round(),
          creditNum: (a.credit * 100).round(),
          denom: 100,
        )).toList(),
        commodityId: commodityId,
        postDate: period.endDate,
      );

      // Save closing entries to database
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final entry in closingEntries) {
        await _db.closingEntriesDao.create(ClosingEntriesCompanion.insert(
          id: entry.id,
          fiscalPeriodId: entry.fiscalPeriodId,
          closingType: entry.closingType.code,
          status: 'EXECUTED',
          sourceAccountId: entry.sourceAccountId,
          targetAccountId: entry.targetAccountId,
          amountNum: entry.amountNum,
          amountDenom: drift.Value(entry.amountDenom),
          description: drift.Value(entry.description),
          executedAt: entry.executedAt.millisecondsSinceEpoch,
          createdAt: now,
          updatedAt: now,
        ));
      }

      // Reload periods
      await _loadPeriods();

      state = state.copyWith(
        isLoading: false,
        successMessage: '期间 ${period.displayName} 已成功结账',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '结账失败: $e',
      );
      return false;
    }
  }

  /// Reopens a closed fiscal period.
  Future<bool> reopenPeriod(FiscalPeriod period) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      // Delete all closing entries for this period
      await _db.closingEntriesDao.deleteByFiscalPeriod(period.id);

      // Reload periods
      await _loadPeriods();

      state = state.copyWith(
        isLoading: false,
        successMessage: '期间 ${period.displayName} 已重新开启',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '重新开启失败: $e',
      );
      return false;
    }
  }

  /// Refreshes the period list.
  Future<void> refresh() async {
    await _loadPeriods();
  }

  /// Clears any messages.
  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

/// Provider for period closing state management.
final periodClosingNotifierProvider =
    StateNotifierProvider<PeriodClosingNotifier, PeriodClosingState>((ref) {
  final db = ref.watch(databaseProvider);
  final service = ref.watch(closingEntryServiceProvider);
  return PeriodClosingNotifier(db, service);
});

/// Provider for current period status summary.
final currentPeriodStatusProvider = Provider<Map<String, dynamic>>((ref) {
  final state = ref.watch(periodClosingNotifierProvider);
  final currentPeriod = state.currentOpenPeriod;

  return {
    'hasOpenPeriod': currentPeriod != null,
    'periodName': currentPeriod?.displayName ?? '无',
    'closedPeriodCount': state.closedPeriods.length,
  };
});

/// Provider for closing entries of a specific period.
final periodClosingEntriesProvider =
    FutureProvider.family<List<db.ClosingEntry>, String>((ref, fiscalPeriodId) async {
  final db = ref.watch(databaseProvider);
  return await db.closingEntriesDao.getByFiscalPeriod(fiscalPeriodId);
});

// ============================================================
// INTERNAL REPOSITORY IMPLEMENTATIONS
// ============================================================

/// Internal account repository implementation using database.
class _DatabaseAccountRepository implements AccountRepository {
  final LocalFinanceDatabase _db;

  _DatabaseAccountRepository(this._db);

  @override
  Future<Account?> getById(String id) async {
    return await _db.accountsDao.getById(id);
  }

  @override
  Future<List<Account>> getAll() async {
    return await _db.accountsDao.getAll();
  }

  @override
  Future<List<Account>> getByType(AccountType type) async {
    return await _db.accountsDao.getByType(type.name.toUpperCase());
  }

  @override
  Future<List<Account>> getChildren(String parentId) async {
    return await _db.accountsDao.getChildren(parentId);
  }

  @override
  Future<double> getBalance(String accountId) async {
    final splits = await _db.splitsDao.getSplitsForAccount(accountId);
    int totalNum = 0;
    int denom = 1;
    for (final split in splits) {
      final commonDenom = denom * split.valueDenom;
      totalNum = totalNum * split.valueDenom + split.valueNum * denom;
      denom = commonDenom;
    }
    return totalNum / denom.toDouble();
  }

  @override
  Future<Account> create(Account account) async {
    throw UnimplementedError('Use AccountNotifier for creating accounts');
  }

  @override
  Future<Account> update(Account account) async {
    throw UnimplementedError('Use AccountNotifier for updating accounts');
  }

  @override
  Future<void> delete(String id) async {
    throw UnimplementedError('Use AccountNotifier for deleting accounts');
  }
}

/// Internal transaction repository implementation using database.
class _DatabaseTransactionRepository implements TransactionRepository {
  final LocalFinanceDatabase _db;

  _DatabaseTransactionRepository(this._db);

  @override
  Future<List<Transaction>> getAll() async {
    return await _db.transactionsDao.getAll();
  }

  @override
  Future<Transaction?> getById(String id) async {
    return await _db.transactionsDao.getById(id);
  }

  @override
  Future<List<Transaction>> getByDateRange(DateTime start, DateTime end) async {
    return await _db.transactionsDao.getByDateRange(start, end);
  }

  @override
  Future<List<Transaction>> getByAccount(String accountId) async {
    return await _db.transactionsDao.getByAccount(accountId);
  }

  @override
  Future<List<Transaction>> getByImportBatch(String batchId) async {
    return [];
  }

  @override
  Future<Transaction> create(Transaction transaction, List<Split> splits) async {
    throw UnimplementedError('Use TransactionNotifier for creating transactions');
  }

  @override
  Future<Transaction> update(Transaction transaction, List<Split> splits) async {
    throw UnimplementedError('Use TransactionNotifier for updating transactions');
  }

  @override
  Future<void> delete(String id) async {
    await _db.transactionsDao.softDelete(id);
  }

  @override
  Future<List<Split>> getSplits(String transactionId) async {
    return await _db.transactionsDao.getSplits(transactionId);
  }

  @override
  Future<bool> existsByExternalId(String externalId) async {
    return await _db.transactionsDao.existsByExternalId(externalId);
  }

  @override
  Future<List<Transaction>> search(TransactionQuery query) async {
    final results = await _db.transactionsDao.getFilteredTransactionsPaginated(
      limit: query.limit ?? 100,
      offset: query.offset ?? 0,
      startDate: query.startDate,
      endDate: query.endDate,
      accountId: query.accountId,
      categoryId: query.categoryId,
      searchQuery: query.searchText,
    );
    return results.map((r) => r.$1).toList();
  }

  @override
  Future<int> count({String? accountId, DateTime? start, DateTime? end}) async {
    return await _db.transactionsDao.count(accountId: accountId);
  }

  @override
  Future<List<SplitWithTransactionData>> getSplitsForAccount(
    String accountId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final splitsData = await _db.splitsDao.getSplitsWithTransactionInfo(
      accountId,
      startDate: startDate,
      endDate: endDate,
    );

    return splitsData.map((data) => SplitWithTransactionData(
      splitId: data.splitId,
      transactionId: data.transactionId,
      postDate: data.postDate,
      description: data.description,
      memo: data.memo,
      valueNum: data.valueNum,
      valueDenom: data.valueDenom,
      reconcileState: 'n',
      reconcileDate: null,
    )).toList();
  }

  @override
  Future<void> updateSplitReconcileState(
    String splitId,
    String reconcileState,
    int? reconcileDate,
  ) async {
    await (_db.update(_db.splits)
      ..where((s) => s.id.equals(splitId))).write(
      SplitsCompanion(
        reconcileState: drift.Value(reconcileState),
        reconcileDate: drift.Value(reconcileDate),
      ),
    );
  }
}
