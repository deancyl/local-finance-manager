import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

/// Filter for journal entry list.
class JournalListFilter {
  final DateTime? fromDate;
  final DateTime? toDate;
  final JournalEntryStatusFilter status;
  final String? searchQuery;

  const JournalListFilter({
    this.fromDate,
    this.toDate,
    this.status = JournalEntryStatusFilter.all,
    this.searchQuery,
  });

  JournalListFilter copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    JournalEntryStatusFilter? status,
    String? searchQuery,
    bool clearFromDate = false,
    bool clearToDate = false,
    bool clearStatus = false,
    bool clearSearchQuery = false,
  }) {
    return JournalListFilter(
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
      status: clearStatus ? JournalEntryStatusFilter.all : (status ?? this.status),
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
    );
  }

  bool get isEmpty =>
      fromDate == null &&
      toDate == null &&
      status == JournalEntryStatusFilter.all &&
      (searchQuery == null || searchQuery!.isEmpty);

  bool get isNotEmpty => !isEmpty;
}

/// Status filter options.
enum JournalEntryStatusFilter {
  all,
  posted,
  draft,
}

/// Journal entry with computed totals for list display.
class JournalEntryListItem {
  final JournalEntry entry;
  final double totalDebits;
  final double totalCredits;
  final int lineCount;

  const JournalEntryListItem({
    required this.entry,
    required this.totalDebits,
    required this.totalCredits,
    required this.lineCount,
  });
}

/// Pagination state for journal entries.
class JournalListPaginationState {
  final List<JournalEntryListItem> items;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;

  const JournalListPaginationState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
  });

  JournalListPaginationState copyWith({
    List<JournalEntryListItem>? items,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
  }) {
    return JournalListPaginationState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
    );
  }
}

/// Notifier for paginated journal entry list with filtering.
class JournalListNotifier extends StateNotifier<JournalListPaginationState> {
  final Ref _ref;
  final int _pageSize;
  JournalListFilter _filter = const JournalListFilter();

  JournalListNotifier(this._ref, {int pageSize = 50})
      : _pageSize = pageSize,
        super(const JournalListPaginationState());

  JournalListFilter get filter => _filter;

  /// Load initial entries.
  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final db = _ref.read(databaseProvider);
      final entries = await _fetchEntries(db, 0, _pageSize + 1);

      state = state.copyWith(
        items: entries.take(_pageSize).toList(),
        isLoading: false,
        hasMore: entries.length > _pageSize,
        currentPage: 0,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '加载失败: $e',
      );
    }
  }

  /// Load more entries (next page).
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final db = _ref.read(databaseProvider);
      final nextPage = state.currentPage + 1;
      final offset = nextPage * _pageSize;
      final entries = await _fetchEntries(db, offset, _pageSize + 1);

      state = state.copyWith(
        items: [...state.items, ...entries.take(_pageSize)],
        isLoading: false,
        hasMore: entries.length > _pageSize,
        currentPage: nextPage,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '加载更多失败: $e',
      );
    }
  }

  /// Update filter and reload.
  Future<void> updateFilter(JournalListFilter newFilter) async {
    _filter = newFilter;
    await loadInitial();
  }

  /// Refresh all entries.
  Future<void> refresh() async {
    await loadInitial();
  }

  /// Fetch entries with current filter.
  Future<List<JournalEntryListItem>> _fetchEntries(
    LocalFinanceDatabase db,
    int offset,
    int limit,
  ) async {
    List<JournalEntry> entries;

    // Apply status filter
    switch (_filter.status) {
      case JournalEntryStatusFilter.posted:
        entries = await db.journalEntriesDao.getPostedEntries();
        break;
      case JournalEntryStatusFilter.draft:
        entries = await db.journalEntriesDao.getUnpostedEntries();
        break;
      case JournalEntryStatusFilter.all:
        entries = await db.journalEntriesDao.getAll();
    }

    // Apply date range filter
    if (_filter.fromDate != null || _filter.toDate != null) {
      final startMs = _filter.fromDate?.millisecondsSinceEpoch ?? 0;
      final endMs = _filter.toDate?.millisecondsSinceEpoch ??
          DateTime.now().add(const Duration(days: 365 * 10)).millisecondsSinceEpoch;

      entries = entries.where((e) =>
          e.postDate >= startMs && e.postDate <= endMs).toList();
    }

    // Apply search filter
    if (_filter.searchQuery != null && _filter.searchQuery!.isNotEmpty) {
      final query = _filter.searchQuery!.toLowerCase();
      entries = entries.where((e) {
        final descMatch = e.description?.toLowerCase().contains(query) ?? false;
        final numMatch = e.entryNumber.toLowerCase().contains(query);
        final refMatch = e.reference?.toLowerCase().contains(query) ?? false;
        return descMatch || numMatch || refMatch;
      }).toList();
    }

    // Sort by post date descending (newest first)
    entries.sort((a, b) => b.postDate.compareTo(a.postDate));

    // Apply pagination
    final paginatedEntries = entries.skip(offset).take(limit).toList();

    // Fetch lines and compute totals for each entry
    final result = <JournalEntryListItem>[];
    for (final entry in paginatedEntries) {
      final lines = await db.journalEntriesDao.getLinesForEntry(entry.id);
      double totalDebits = 0;
      double totalCredits = 0;

      for (final line in lines) {
        final debit = line.debitDenom != 0
            ? line.debitNum / line.debitDenom
            : line.debitNum.toDouble();
        final credit = line.creditDenom != 0
            ? line.creditNum / line.creditDenom
            : line.creditNum.toDouble();
        totalDebits += debit;
        totalCredits += credit;
      }

      result.add(JournalEntryListItem(
        entry: entry,
        totalDebits: totalDebits,
        totalCredits: totalCredits,
        lineCount: lines.length,
      ));
    }

    return result;
  }

  /// Post a draft entry.
  Future<bool> postEntry(String entryId) async {
    try {
      final db = _ref.read(databaseProvider);
      await db.journalEntriesDao.postEntry(entryId);
      await refresh();
      return true;
    } catch (e) {
      state = state.copyWith(error: '过账失败: $e');
      return false;
    }
  }

  /// Delete an entry.
  Future<bool> deleteEntry(String entryId) async {
    try {
      final db = _ref.read(databaseProvider);
      await db.journalEntriesDao.deleteEntry(entryId);
      await refresh();
      return true;
    } catch (e) {
      state = state.copyWith(error: '删除失败: $e');
      return false;
    }
  }
}

/// Provider for journal list filter state.
final journalListFilterProvider =
    StateProvider<JournalListFilter>((ref) => const JournalListFilter());

/// Provider for paginated journal entry list.
final journalListProvider =
    StateNotifierProvider<JournalListNotifier, JournalListPaginationState>((ref) {
  return JournalListNotifier(ref);
});

/// Provider for watching journal entries (reactive).
final watchJournalEntriesProvider = StreamProvider<List<JournalEntry>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.journalEntriesDao.watchAll();
});

/// Provider for counting entries by status.
final journalEntryCountsProvider = FutureProvider<(int total, int posted, int draft)>((ref) async {
  final db = ref.watch(databaseProvider);
  final total = await db.journalEntriesDao.count();
  final posted = await db.journalEntriesDao.countPosted();
  final draft = await db.journalEntriesDao.countUnposted();
  return (total, posted, draft);
});
