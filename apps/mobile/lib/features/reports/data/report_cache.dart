import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

/// Cache entry with timestamp for TTL-based expiration.
class _CacheEntry<T> {
  final T data;
  final DateTime cachedAt;
  final Duration ttl;

  _CacheEntry({
    required this.data,
    required this.cachedAt,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().difference(cachedAt) > ttl;
}

/// Report cache key types.
enum ReportCacheKey {
  trialBalance,
  balanceSheet,
  incomeStatement,
}

/// Cache key generator for reports with date parameters.
String _generateCacheKey(ReportCacheKey key, {DateTime? startDate, DateTime? endDate, DateTime? asOfDate}) {
  final buffer = StringBuffer('report_cache_${key.name}');
  if (startDate != null) {
    buffer.write('_start_${startDate.millisecondsSinceEpoch}');
  }
  if (endDate != null) {
    buffer.write('_end_${endDate.millisecondsSinceEpoch}');
  }
  if (asOfDate != null) {
    buffer.write('_asof_${asOfDate.millisecondsSinceEpoch}');
  }
  return buffer.toString();
}

/// Report cache service for caching expensive report calculations.
/// 
/// Features:
/// - TTL-based expiration (default 5 minutes)
/// - Automatic invalidation on transaction changes
/// - Memory-efficient caching with size limits
/// - Fast access for frequently requested reports
/// 
/// Performance target: Report loads in <1s with 10,000 transactions
class ReportCacheService {
  static const Duration defaultTTL = Duration(minutes: 5);
  static const int maxCacheEntries = 100;
  
  final Map<String, _CacheEntry> _memoryCache = {};
  DateTime? _lastTransactionChange;
  
  /// Get cached trial balance if available and not expired.
  TrialBalance? getTrialBalance({DateTime? startDate, DateTime? endDate}) {
    final key = _generateCacheKey(
      ReportCacheKey.trialBalance,
      startDate: startDate,
      endDate: endDate,
    );
    return _getFromCache<TrialBalance>(key);
  }

  /// Cache trial balance result.
  void cacheTrialBalance(
    TrialBalance data, {
    DateTime? startDate,
    DateTime? endDate,
    Duration? ttl,
  }) {
    final key = _generateCacheKey(
      ReportCacheKey.trialBalance,
      startDate: startDate,
      endDate: endDate,
    );
    _setCache(key, data, ttl ?? defaultTTL);
  }

  /// Get cached balance sheet if available and not expired.
  BalanceSheet? getBalanceSheet({DateTime? asOfDate}) {
    final key = _generateCacheKey(
      ReportCacheKey.balanceSheet,
      asOfDate: asOfDate,
    );
    return _getFromCache<BalanceSheet>(key);
  }

  /// Cache balance sheet result.
  void cacheBalanceSheet(
    BalanceSheet data, {
    DateTime? asOfDate,
    Duration? ttl,
  }) {
    final key = _generateCacheKey(
      ReportCacheKey.balanceSheet,
      asOfDate: asOfDate,
    );
    _setCache(key, data, ttl ?? defaultTTL);
  }

  /// Get cached income statement if available and not expired.
  IncomeStatement? getIncomeStatement({DateTime? startDate, DateTime? endDate}) {
    final key = _generateCacheKey(
      ReportCacheKey.incomeStatement,
      startDate: startDate,
      endDate: endDate,
    );
    return _getFromCache<IncomeStatement>(key);
  }

  /// Cache income statement result.
  void cacheIncomeStatement(
    IncomeStatement data, {
    DateTime? startDate,
    DateTime? endDate,
    Duration? ttl,
  }) {
    final key = _generateCacheKey(
      ReportCacheKey.incomeStatement,
      startDate: startDate,
      endDate: endDate,
    );
    _setCache(key, data, ttl ?? defaultTTL);
  }

  /// Get generic cached data.
  T? _getFromCache<T>(String key) {
    final entry = _memoryCache[key];
    if (entry == null) return null;
    
    // Check if expired
    if (entry.isExpired) {
      _memoryCache.remove(key);
      return null;
    }
    
    // Check if transactions changed since cache
    if (_lastTransactionChange != null &&
        entry.cachedAt.isBefore(_lastTransactionChange!)) {
      _memoryCache.remove(key);
      return null;
    }
    
    return entry.data as T;
  }

  /// Set generic cache data.
  void _setCache<T>(String key, T data, Duration ttl) {
    final entry = _CacheEntry(
      data: data,
      cachedAt: DateTime.now(),
      ttl: ttl,
    );
    
    // Store in memory cache
    _memoryCache[key] = entry;
    
    // Enforce cache size limit
    if (_memoryCache.length > maxCacheEntries) {
      _evictOldestEntries();
    }
  }

  /// Evict oldest entries when cache is full.
  void _evictOldestEntries() {
    final sortedKeys = _memoryCache.keys.toList();
    sortedKeys.sort((a, b) {
      final aTime = _memoryCache[a]!.cachedAt;
      final bTime = _memoryCache[b]!.cachedAt;
      return aTime.compareTo(bTime);
    });
    
    // Remove oldest 25% of entries
    final toRemove = (sortedKeys.length * 0.25).floor();
    for (var i = 0; i < toRemove; i++) {
      _memoryCache.remove(sortedKeys[i]);
    }
  }

  /// Invalidate all report caches.
  /// Called when transactions are modified.
  void invalidateAll() {
    _lastTransactionChange = DateTime.now();
    _memoryCache.clear();
  }

  /// Invalidate specific report type.
  void invalidateReport(ReportCacheKey reportKey) {
    final prefix = 'report_cache_${reportKey.name}';
    _memoryCache.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// Clear all caches (manual clear from settings).
  void clearAllCaches() {
    _memoryCache.clear();
    _lastTransactionChange = null;
  }

  /// Get cache statistics.
  Map<String, dynamic> getCacheStats() {
    int trialBalanceCount = 0;
    int balanceSheetCount = 0;
    int incomeStatementCount = 0;
    
    for (final key in _memoryCache.keys) {
      if (key.contains('trialBalance')) trialBalanceCount++;
      if (key.contains('balanceSheet')) balanceSheetCount++;
      if (key.contains('incomeStatement')) incomeStatementCount++;
    }
    
    return {
      'memoryCacheSize': _memoryCache.length,
      'trialBalanceEntries': trialBalanceCount,
      'balanceSheetEntries': balanceSheetCount,
      'incomeStatementEntries': incomeStatementCount,
      'maxCacheSize': maxCacheEntries,
      'lastInvalidation': _lastTransactionChange?.toIso8601String(),
    };
  }

  /// Estimate memory usage in bytes.
  /// Each report typically uses ~5-10KB depending on account count.
  int estimateMemoryUsage() {
    // Estimate: each cache entry is ~8KB on average for reports with ~100 accounts
    return _memoryCache.length * 8192;
  }
}

/// Provider for report cache service (singleton).
final reportCacheServiceProvider = Provider<ReportCacheService>((ref) {
  return ReportCacheService();
});

/// Provider for cache statistics.
final cacheStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final cache = ref.watch(reportCacheServiceProvider);
  return cache.getCacheStats();
});

/// Notifier for triggering cache invalidation.
/// Watch this provider to know when to refresh cached data.
final cacheInvalidationNotifierProvider = StateNotifierProvider<CacheInvalidationNotifier, DateTime?>(
  (ref) => CacheInvalidationNotifier(ref),
);

class CacheInvalidationNotifier extends StateNotifier<DateTime?> {
  final Ref _ref;
  
  CacheInvalidationNotifier(this._ref) : super(null);

  /// Called when transactions are created, updated, or deleted.
  void onTransactionChanged() {
    final cache = _ref.read(reportCacheServiceProvider);
    cache.invalidateAll();
    state = DateTime.now();
  }
  
  /// Manual cache clear from settings.
  void clearCache() {
    final cache = _ref.read(reportCacheServiceProvider);
    cache.clearAllCaches();
    state = DateTime.now();
  }
}
