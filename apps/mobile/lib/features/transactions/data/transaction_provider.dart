import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart' as uuid_pkg;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';
import 'package:finance_app/features/budgets/data/budget_notification_service.dart';
import 'package:core/core.dart' show BudgetPeriod, BudgetPeriodCalculator;
import 'package:finance_app/core/performance/memory_optimization.dart';
import 'package:finance_app/core/presentation/widgets/undoable_action.dart';
import 'transaction_filter.dart';

/// Page size for pagination (optimized for memory v0.3.120)
const int kPageSize = 20;

final transactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.transactions)
    ..where((t) => t.deletedAt.isNull())
    ..orderBy([(t) => drift.OrderingTerm.desc(t.postDate)]))
    .watch();
});

final transactionsByDateRangeProvider = Provider.family<List<Transaction>, (DateTime, DateTime)>((ref, range) {
  final transactions = ref.watch(transactionsProvider);
  return transactions.when(
    data: (list) => list.where((t) {
      final date = DateTime.fromMillisecondsSinceEpoch(t.postDate);
      return date.isAfter(range.$1) && date.isBefore(range.$2);
    }).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

final splitsForTransactionProvider = FutureProvider.family<List<Split>, String>((ref, transactionId) async {
  final db = ref.watch(databaseProvider);
  return (db.select(db.splits)..where((s) => s.transactionId.equals(transactionId))).get();
});

/// Provider for all splits with their associated account info.
/// Used for calculating income/expense totals in reports.
/// Auto-disposes when not in use to save memory (v0.3.120).
final allSplitsWithAccountsProvider = FutureProvider.autoDispose<List<(Split, Account)>>((ref) async {
  final db = ref.watch(databaseProvider);
  
  // Get all splits
  final allSplits = await (db.select(db.splits)).get();
  
  // Get all accounts and create a map
  final allAccounts = await (db.select(db.accounts)).get();
  final accountMap = {for (var a in allAccounts) a.id: a};
  
  // Pair splits with their accounts
  return allSplits
      .where((s) => accountMap.containsKey(s.accountId))
      .map((s) => (s, accountMap[s.accountId]!))
      .toList();
});

// ============================================================
// FILTER PROVIDERS - Transaction search and filtering
// ============================================================

/// Notifier for managing transaction filter state with persistence.
class TransactionFilterNotifier extends StateNotifier<TransactionFilter> {
  static const _key = 'transaction_filter';

  TransactionFilterNotifier() : super(const TransactionFilter()) {
    _loadFilter();
  }

  Future<void> _loadFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFilter = prefs.getString(_key);
    
    if (savedFilter != null) {
      try {
        final json = jsonDecode(savedFilter) as Map<String, dynamic>;
        state = TransactionFilter.fromJson(json);
      } catch (_) {
        // If loading fails, use default empty filter
        state = const TransactionFilter();
      }
    }
  }

  Future<void> setFilter(TransactionFilter filter) async {
    state = filter;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(filter.toJson()));
  }
}

/// Provider for transaction filter state.
final transactionFilterProvider = StateNotifierProvider<TransactionFilterNotifier, TransactionFilter>((ref) {
  return TransactionFilterNotifier();
});

/// Provider for filtered transactions based on current filter state.
final filteredTransactionsProvider = Provider<List<Transaction>>((ref) {
  final transactionsAsync = ref.watch(transactionsProvider);
  final filter = ref.watch(transactionFilterProvider);
  
  return transactionsAsync.when(
    data: (transactions) {
      if (filter.isEmpty) {
        return transactions;
      }
      return _applyFilter(transactions, filter, ref);
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Applies filter criteria to transaction list.
List<Transaction> _applyFilter(
  List<Transaction> transactions,
  TransactionFilter filter,
  Ref ref,
) {
  return transactions.where((transaction) {
    // Date range filter
    if (filter.startDate != null) {
      final transactionDate = DateTime.fromMillisecondsSinceEpoch(transaction.postDate);
      final startDate = DateTime(filter.startDate!.year, filter.startDate!.month, filter.startDate!.day);
      if (transactionDate.isBefore(startDate)) return false;
    }
    
    if (filter.endDate != null) {
      final transactionDate = DateTime.fromMillisecondsSinceEpoch(transaction.postDate);
      final endDate = DateTime(filter.endDate!.year, filter.endDate!.month, filter.endDate!.day, 23, 59, 59);
      if (transactionDate.isAfter(endDate)) return false;
    }
    
    // Search query filter (description + notes)
    if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
      final query = filter.searchQuery!.toLowerCase();
      final description = transaction.description?.toLowerCase() ?? '';
      final notes = transaction.notes?.toLowerCase() ?? '';
      if (!description.contains(query) && !notes.contains(query)) {
        return false;
      }
    }
    
    // Category and account filters need split data
    if (filter.categoryId != null || filter.accountId != null || filter.hasAmountRange) {
      // This requires async split lookup, so we'll handle it differently
      // For now, we'll use a synchronous approach by watching splits
      // In production, this should be done at the database level
      return true; // Will be filtered further in the widget
    }
    
    // Tag filter is handled separately in filteredTransactionsWithSplitsProvider
    
    return true;
  }).toList();
}

/// Provider for filtered transactions with split data (for category/account/amount filtering).
final filteredTransactionsWithSplitsProvider = FutureProvider<List<(Transaction, List<Split>)>>((ref) async {
  final filter = ref.watch(transactionFilterProvider);
  final db = ref.watch(databaseProvider);
  
  // If no filter, return all transactions with splits
  if (filter.isEmpty) {
    final transactions = await ref.watch(transactionsProvider.future);
    final result = <(Transaction, List<Split>)>[];
    for (final t in transactions) {
      final splits = await db.transactionsDao.getSplits(t.id);
      result.add((t, splits));
    }
    return result;
  }
  
  // Handle tag filter separately for better performance
  List<String>? tagFilteredTransactionIds;
  if (filter.hasTagFilter) {
    if (filter.tagFilterLogic == TagFilterLogic.and) {
      tagFilteredTransactionIds = await db.tagsDao.getTransactionIdsWithAllTags(filter.tagIds);
    } else {
      tagFilteredTransactionIds = await db.tagsDao.getTransactionIdsWithAnyTags(filter.tagIds);
    }
  }
  
  // Build query with filters
  final query = db.select(db.transactions)
    ..where((t) => t.deletedAt.isNull())
    ..orderBy([(t) => drift.OrderingTerm.desc(t.postDate)]);
  
  final transactions = await query.get();
  final result = <(Transaction, List<Split>)>[];
  
  for (final transaction in transactions) {
    // Apply tag filter
    if (tagFilteredTransactionIds != null) {
      if (!tagFilteredTransactionIds.contains(transaction.id)) continue;
    }
    
    final splits = await db.transactionsDao.getSplits(transaction.id);
    
    // Apply date filter
    if (filter.startDate != null) {
      final transactionDate = DateTime.fromMillisecondsSinceEpoch(transaction.postDate);
      final startDate = DateTime(filter.startDate!.year, filter.startDate!.month, filter.startDate!.day);
      if (transactionDate.isBefore(startDate)) continue;
    }
    
    if (filter.endDate != null) {
      final transactionDate = DateTime.fromMillisecondsSinceEpoch(transaction.postDate);
      final endDate = DateTime(filter.endDate!.year, filter.endDate!.month, filter.endDate!.day, 23, 59, 59);
      if (transactionDate.isAfter(endDate)) continue;
    }
    
    // Apply search filter
    if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
      final query = filter.searchQuery!.toLowerCase();
      final description = transaction.description?.toLowerCase() ?? '';
      final notes = transaction.notes?.toLowerCase() ?? '';
      if (!description.contains(query) && !notes.contains(query)) {
        continue;
      }
    }
    
    // Apply category filter
    if (filter.categoryId != null) {
      final hasCategory = splits.any((s) => s.categoryId == filter.categoryId);
      if (!hasCategory) continue;
    }
    
    // Apply account filter
    if (filter.accountId != null) {
      final hasAccount = splits.any((s) => s.accountId == filter.accountId);
      if (!hasAccount) continue;
    }
    
    // Apply amount range filter (absolute value)
    if (filter.hasAmountRange) {
      final totalAmount = splits.fold<int>(0, (sum, s) => sum + s.valueNum.abs());
      final amount = totalAmount / 100.0;
      
      if (filter.minAmount != null && amount < filter.minAmount!) continue;
      if (filter.maxAmount != null && amount > filter.maxAmount!) continue;
    }
    
    result.add((transaction, splits));
  }
  
  return result;
});

class TransactionNotifier extends StateNotifier<AsyncValue<void>> {
  final LocalFinanceDatabase _db;
  final Ref _ref;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  
  /// Stores the most recent undoable action (for undo functionality)
  UndoableAction? _pendingUndoAction;
  
  /// Getter for the pending undo action
  UndoableAction? get pendingUndoAction => _pendingUndoAction;

  TransactionNotifier(this._db, this._ref) : super(const AsyncValue.data(null));

  Future<String?> createTransaction({
    required String accountId,
    required double amount,
    required DateTime date,
    required String currencyId,
    String? description,
    String? notes,
    String? categoryId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final transactionId = const uuid_pkg.Uuid().v4();
      final splitId = const uuid_pkg.Uuid().v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final postDate = date.millisecondsSinceEpoch;
      final amountNum = (amount * 100).round();

      await _db.transaction(() async {
        await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            id: transactionId,
            postDate: postDate,
            enterDate: now,
            currencyId: currencyId,
            description: drift.Value(description),
            notes: drift.Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );

        await _db.into(_db.splits).insert(
          SplitsCompanion.insert(
            id: splitId,
            transactionId: transactionId,
            accountId: accountId,
            categoryId: drift.Value(categoryId),
            valueNum: amountNum,
            quantityNum: amountNum,
            createdAt: now,
          ),
        );
      });

      state = const AsyncValue.data(null);
      _retryCount = 0; // Reset retry count on success (v0.3.120)
      
      // Check budget alerts after successful transaction creation
      if (categoryId != null) {
        _checkBudgetAlertsForCategory(categoryId, amount, date);
      }
      
      return transactionId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      
      // Graceful error recovery (v0.3.120)
      _retryCount++;
      if (_retryCount <= _maxRetries) {
        print('Transaction creation failed, attempt $_retryCount/$_maxRetries: $e');
      }
      
      return null;
    }
  }
  
  /// Check budget alerts for a category after a transaction is created.
  /// Errors are caught gracefully to not affect the transaction.
  Future<void> _checkBudgetAlertsForCategory(
    String categoryId,
    double amount,
    DateTime transactionDate,
  ) async {
    try {
      // Only check for expense transactions (negative amount)
      if (amount <= 0) return;
      
      final budgets = await _db.budgetsDao.getByCategory(categoryId);
      final activeBudgets = budgets.where((b) => b.isActive).toList();
      
      if (activeBudgets.isEmpty) return;
      
      final notificationService = _ref.read(budgetNotificationServiceProvider);
      await notificationService.initialize();
      
      final now = DateTime.now();
      
      for (final budget in activeBudgets) {
        // Calculate period bounds
        final period = _parseBudgetPeriod(budget.period);
        final (start, end) = BudgetPeriodCalculator.getCurrentPeriodBounds(
          period,
          now,
          customStart: DateTime.fromMillisecondsSinceEpoch(budget.startDate),
          customEnd: budget.endDate != null 
              ? DateTime.fromMillisecondsSinceEpoch(budget.endDate!) 
              : null,
        );
        
        // Check if transaction falls within budget period
        if (transactionDate.isBefore(start) || transactionDate.isAfter(end)) {
          continue;
        }
        
        final startMs = start.millisecondsSinceEpoch;
        final endMs = end.millisecondsSinceEpoch;
        
        // Calculate spending
        final spentNum = await _db.budgetsDao.calculateSpentAmountNum(
          categoryId: budget.categoryId,
          startMs: startMs,
          endMs: endMs,
        );
        
        final spent = spentNum / 100.0;
        
        // Check alerts
        await notificationService.checkBudgetAlerts(
          budget: budget,
          spentAmount: spent,
          ref: _ref,
        );
      }
    } catch (e) {
      // Silently ignore notification errors - don't fail the transaction
      // In production, you might want to log this to a crash reporting service
    }
  }
  
  BudgetPeriod _parseBudgetPeriod(String period) {
    switch (period) {
      case 'MONTHLY':
        return BudgetPeriod.monthly;
      case 'YEARLY':
        return BudgetPeriod.yearly;
      case 'CUSTOM':
        return BudgetPeriod.custom;
      default:
        return BudgetPeriod.monthly;
    }
  }

  Future<void> updateTransaction(Transaction transaction, Split split) async {
    state = const AsyncValue.loading();
    try {
      await _db.transaction(() async {
        await (_db.update(_db.transactions)
          ..where((t) => t.id.equals(transaction.id))).write(
          TransactionsCompanion(
            description: drift.Value(transaction.description),
            postDate: drift.Value(transaction.postDate),
            notes: drift.Value(transaction.notes),
            updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );

        await (_db.update(_db.splits)
          ..where((s) => s.id.equals(split.id))).write(
          SplitsCompanion(
            valueNum: drift.Value(split.valueNum),
            quantityNum: drift.Value(split.quantityNum),
          ),
        );
      });

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Deletes a transaction with undo capability.
  /// 
  /// Returns the UndoableAction if deletion was successful,
  /// allowing the caller to show an undo snackbar.
  /// Returns null if deletion failed.
  Future<UndoableAction?> deleteTransactionWithUndo(String id) async {
    state = const AsyncValue.loading();
    try {
      // Fetch transaction and splits before deletion
      final transaction = await (_db.select(_db.transactions)
        ..where((t) => t.id.equals(id))).getSingle();
      final splits = await (_db.select(_db.splits)
        ..where((s) => s.transactionId.equals(id))).get();
      
      // Perform soft delete
      await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(
          deletedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      
      // Store for undo
      _pendingUndoAction = UndoableAction.delete(
        transaction: transaction,
        splits: splits,
      );
      
      state = const AsyncValue.data(null);
      return _pendingUndoAction;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Restores a recently deleted transaction.
  /// 
  /// This undoes the most recent delete operation if within the undo window.
  Future<bool> undoDelete() async {
    if (_pendingUndoAction == null) return false;
    
    // Check if still within undo window (5 seconds)
    if (!_pendingUndoAction!.isWithinUndoWindow(const Duration(seconds: 5))) {
      _pendingUndoAction = null;
      return false;
    }
    
    state = const AsyncValue.loading();
    try {
      final action = _pendingUndoAction!;
      
      // Restore the transaction by clearing deletedAt
      await (_db.update(_db.transactions)
        ..where((t) => t.id.equals(action.transaction.id))).write(
        TransactionsCompanion(
          deletedAt: drift.Value(null),
          updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      
      // Clear the pending action
      _pendingUndoAction = null;
      
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> deleteTransaction(String id) async {
    state = const AsyncValue.loading();
    try {
      await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(
          deletedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Creates a transfer transaction between two accounts.
  /// 
  /// This creates a single transaction with two splits:
  /// - One split debiting (negative) from the source account
  /// - One split crediting (positive) to the destination account
  Future<void> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    required DateTime date,
    required String currencyId,
    String? description,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final transactionId = const uuid_pkg.Uuid().v4();
      final fromSplitId = const uuid_pkg.Uuid().v4();
      final toSplitId = const uuid_pkg.Uuid().v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final postDate = date.millisecondsSinceEpoch;
      final amountNum = (amount * 100).round();

      // Create transaction with description like "转账: A -> B"
      final transferDescription = description ?? '账户转账';

      await _db.transaction(() async {
        // Create the transaction record
        await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            id: transactionId,
            postDate: postDate,
            enterDate: now,
            currencyId: currencyId,
            description: drift.Value(transferDescription),
            notes: drift.Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Create split for source account (debit/negative)
        await _db.into(_db.splits).insert(
          SplitsCompanion.insert(
            id: fromSplitId,
            transactionId: transactionId,
            accountId: fromAccountId,
            valueNum: -amountNum, // Negative for outgoing
            quantityNum: -amountNum,
            createdAt: now,
          ),
        );

        // Create split for destination account (credit/positive)
        await _db.into(_db.splits).insert(
          SplitsCompanion.insert(
            id: toSplitId,
            transactionId: transactionId,
            accountId: toAccountId,
            valueNum: amountNum, // Positive for incoming
            quantityNum: amountNum,
            createdAt: now,
          ),
        );
      });

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final transactionNotifierProvider = StateNotifierProvider<TransactionNotifier, AsyncValue<void>>((ref) {
  final db = ref.watch(databaseProvider);
  return TransactionNotifier(db, ref);
});

// ============================================================
// PAGINATION PROVIDERS - Infinite scroll support
// ============================================================

/// State for pagination tracking
class PaginationState {
  final int currentPage;
  final bool hasMore;
  final bool isLoading;
  final List<(Transaction, List<Split>)> items;

  const PaginationState({
    this.currentPage = 0,
    this.hasMore = true,
    this.isLoading = false,
    this.items = const [],
  });

  PaginationState copyWith({
    int? currentPage,
    bool? hasMore,
    bool? isLoading,
    List<(Transaction, List<Split>)>? items,
  }) {
    return PaginationState(
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
    );
  }
}

/// Notifier for managing paginated transactions with infinite scroll
/// Enhanced with error recovery (v0.3.120)
class PaginatedTransactionsNotifier extends StateNotifier<PaginationState> {
  final LocalFinanceDatabase _db;
  final Ref _ref;
  TransactionFilter _filter;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  PaginatedTransactionsNotifier(this._db, this._ref, {TransactionFilter? filter})
      : _filter = filter ?? const TransactionFilter(),
        super(const PaginationState());

  /// Updates the filter and resets pagination
  void updateFilter(TransactionFilter filter) {
    if (_filter != filter) {
      _filter = filter;
      // Reset and reload with new filter
      state = const PaginationState();
      _retryCount = 0;
      loadInitial();
    }
  }

  /// Gets the current filter
  TransactionFilter get filter => _filter;

  /// Loads the initial page (page 0)
  Future<void> loadInitial() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true);

    try {
      final items = await _db.transactionsDao.getFilteredTransactionsPaginated(
        limit: kPageSize,
        offset: 0,
        startDate: _filter.startDate,
        endDate: _filter.endDate,
        categoryId: _filter.categoryId,
        accountId: _filter.accountId,
        searchQuery: _filter.searchQuery,
        minAmount: _filter.minAmount,
        maxAmount: _filter.maxAmount,
      );

      state = PaginationState(
        currentPage: 0,
        hasMore: items.length == kPageSize,
        isLoading: false,
        items: items,
      );
      _retryCount = 0; // Reset retry on success
    } catch (e) {
      state = state.copyWith(isLoading: false);
      _handleLoadError('loadInitial', e);
    }
  }

  /// Loads the next page of transactions
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final nextPage = state.currentPage + 1;
      final offset = nextPage * kPageSize;

      final newItems = await _db.transactionsDao.getFilteredTransactionsPaginated(
        limit: kPageSize,
        offset: offset,
        startDate: _filter.startDate,
        endDate: _filter.endDate,
        categoryId: _filter.categoryId,
        accountId: _filter.accountId,
        searchQuery: _filter.searchQuery,
        minAmount: _filter.minAmount,
        maxAmount: _filter.maxAmount,
      );

      state = state.copyWith(
        currentPage: nextPage,
        hasMore: newItems.length == kPageSize,
        isLoading: false,
        items: [...state.items, ...newItems],
      );
      _retryCount = 0; // Reset retry on success
    } catch (e) {
      state = state.copyWith(isLoading: false);
      _handleLoadError('loadMore', e);
    }
  }

  /// Handles load errors with retry logic (v0.3.120)
  void _handleLoadError(String operation, Object error) {
    _retryCount++;
    if (_retryCount <= _maxRetries) {
      print('$operation failed (attempt $_retryCount/$_maxRetries): $error');
      // Exponential backoff retry
      Future.delayed(Duration(seconds: _retryCount * 2), () {
        if (operation == 'loadInitial') {
          loadInitial();
        } else {
          loadMore();
        }
      });
    } else {
      print('$operation failed after $_maxRetries attempts: $error');
    }
  }

  /// Refreshes the list (resets to page 0)
  Future<void> refresh() async {
    state = const PaginationState();
    _retryCount = 0;
    await loadInitial();
  }
}

/// Provider for paginated transactions state
final paginatedTransactionsProvider = StateNotifierProvider<PaginatedTransactionsNotifier, PaginationState>((ref) {
  final db = ref.watch(databaseProvider);
  return PaginatedTransactionsNotifier(db, ref);
});

/// Provider for filtered and paginated transactions.
/// This combines the filter state with pagination for optimal performance.
final filteredPaginatedTransactionsProvider = StateNotifierProvider.autoDispose
    <PaginatedTransactionsNotifier, PaginationState>((ref) {
  final db = ref.watch(databaseProvider);
  final filter = ref.watch(transactionFilterProvider);
  
  final notifier = PaginatedTransactionsNotifier(db, ref, filter: filter);
  
  // Load initial data when provider is first created
  Future.microtask(() => notifier.loadInitial());
  
  return notifier;
});

/// Provider for checking if more items can be loaded
final hasMoreTransactionsProvider = Provider<bool>((ref) {
  return ref.watch(paginatedTransactionsProvider).hasMore;
});

/// Provider for checking if currently loading
final isTransactionsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(paginatedTransactionsProvider).isLoading;
});