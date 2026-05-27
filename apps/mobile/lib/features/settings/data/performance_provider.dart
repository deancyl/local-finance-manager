import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:database/database.dart';

/// Provider for database performance metrics.
final dbPerformanceProvider = StateNotifierProvider<DbPerformanceNotifier, DbPerformanceMetrics>((ref) {
  final db = ref.watch(databaseProvider);
  return DbPerformanceNotifier(db);
});

/// Database performance metrics.
class DbPerformanceMetrics {
  final int totalTransactions;
  final int totalAccounts;
  final int totalCategories;
  final int totalSplits;
  final int dbSizeKB;
  final double avgQueryTimeMs;
  final DateTime lastUpdated;

  const DbPerformanceMetrics({
    this.totalTransactions = 0,
    this.totalAccounts = 0,
    this.totalCategories = 0,
    this.totalSplits = 0,
    this.dbSizeKB = 0,
    this.avgQueryTimeMs = 0.0,
    this.lastUpdated = DateTime.now(),
  });

  DbPerformanceMetrics copyWith({
    int? totalTransactions,
    int? totalAccounts,
    int? totalCategories,
    int? totalSplits,
    int? dbSizeKB,
    double? avgQueryTimeMs,
    DateTime? lastUpdated,
  }) {
    return DbPerformanceMetrics(
      totalTransactions: totalTransactions ?? this.totalTransactions,
      totalAccounts: totalAccounts ?? this.totalAccounts,
      totalCategories: totalCategories ?? this.totalCategories,
      totalSplits: totalSplits ?? this.totalSplits,
      dbSizeKB: dbSizeKB ?? this.dbSizeKB,
      avgQueryTimeMs: avgQueryTimeMs ?? this.avgQueryTimeMs,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Notifier for tracking database performance.
class DbPerformanceNotifier extends StateNotifier<DbPerformanceMetrics> {
  final LocalFinanceDatabase _db;
  final List<double> _queryTimes = [];

  DbPerformanceNotifier(this._db) : super(const DbPerformanceMetrics());

  /// Refresh performance metrics.
  Future<void> refresh() async {
    final stopwatch = Stopwatch()..start();

    try {
      // Get counts
      final transactions = await _db.transactionsDao.countAll();
      final accounts = await _db.accountsDao.countAll();
      final categories = await _db.categoriesDao.countAll();
      final splits = await _db.splitsDao.countAll();

      // Get database size (approximate)
      final dbSize = await _getDatabaseSize();

      stopwatch.stop();

      _queryTimes.add(stopwatch.elapsedMilliseconds.toDouble());
      final avgQueryTime = _queryTimes.length > 0
          ? _queryTimes.reduce((a, b) => a + b) / _queryTimes.length
          : 0.0;

      state = state.copyWith(
        totalTransactions: transactions,
        totalAccounts: accounts,
        totalCategories: categories,
        totalSplits: splits,
        dbSizeKB: dbSize,
        avgQueryTimeMs: avgQueryTime,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      // Keep current state on error
    }
  }

  /// Get approximate database size.
  Future<int> _getDatabaseSize() async {
    try {
      // This is a placeholder - actual implementation depends on platform
      // For SQLite, we could query the file size
      return 0; // Placeholder
    } catch (e) {
      return 0;
    }
  }

  /// Clear query time history.
  void clearHistory() {
    _queryTimes.clear();
    state = state.copyWith(avgQueryTimeMs: 0.0);
  }
}

/// Provider for cache statistics.
final cacheStatsProvider = StateNotifierProvider<CacheStatsNotifier, CacheStats>((ref) {
  return CacheStatsNotifier();
});

/// Cache statistics.
class CacheStats {
  final int cachedProviders;
  final int invalidatedProviders;
  final DateTime lastUpdated;

  const CacheStats({
    this.cachedProviders = 0,
    this.invalidatedProviders = 0,
    this.lastUpdated = DateTime.now(),
  });
}

/// Notifier for cache statistics.
class CacheStatsNotifier extends StateNotifier<CacheStats> {
  int _invalidatedCount = 0;

  CacheStatsNotifier() : super(const CacheStats());

  /// Record a provider invalidation.
  void recordInvalidation() {
    _invalidatedCount++;
    state = CacheStats(
      invalidatedProviders: _invalidatedCount,
      lastUpdated: DateTime.now(),
    );
  }

  /// Reset statistics.
  void reset() {
    _invalidatedCount = 0;
    state = const CacheStats();
  }
}

/// Helper stopwatch class.
class Stopwatch {
  DateTime? _start;
  DateTime? _end;

  void start() {
    _start = DateTime.now();
    _end = null;
  }

  void stop() {
    _end = DateTime.now();
  }

  bool get isRunning => _start != null && _end == null;

  int get elapsedMilliseconds {
    if (_start == null) return 0;
    final end = _end ?? DateTime.now();
    return end.difference(_start!).inMilliseconds;
  }

  double get elapsedSeconds => elapsedMilliseconds / 1000.0;

  void reset() {
    _start = null;
    _end = null;
  }
}