import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';
import 'package:finance_app/features/currency/data/rate_fetch_service.dart';

/// Provider for all commodities (currencies)
final commoditiesProvider = StreamProvider<List<Commodity>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.commodities).watch();
});

/// Provider for currency commodities only
final currenciesProvider = Provider<List<Commodity>>((ref) {
  final commodities = ref.watch(commoditiesProvider);
  return commodities.when(
    data: (list) => list.where((c) => c.namespace == 'CURRENCY').toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider for all exchange rates
final exchangeRatesProvider = StreamProvider<List<ExchangeRate>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.exchangeRatesDao.watchAll();
});

/// Provider for exchange rates as a map for quick lookup
/// Key format: "FROM_TO" (e.g., "USD_CNY")
final exchangeRatesMapProvider = Provider<Map<String, ExchangeRate>>((ref) {
  final rates = ref.watch(exchangeRatesProvider);
  return rates.when(
    data: (list) {
      final map = <String, ExchangeRate>{};
      for (final rate in list) {
        final key = '${rate.fromCurrency}_${rate.toCurrency}';
        // Keep only the latest rate for each pair
        if (!map.containsKey(key) || map[key]!.date < rate.date) {
          map[key] = rate;
        }
      }
      return map;
    },
    loading: () => {},
    error: (_, __) => {},
  );
});

/// Provider for currency pairs (unique from-to combinations)
final currencyPairsProvider = FutureProvider<List<({String from, String to})>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.exchangeRatesDao.getCurrencyPairs();
});

/// Exchange rate state notifier for CRUD operations
class ExchangeRateNotifier extends StateNotifier<AsyncValue<void>> {
  final LocalFinanceDatabase _db;

  ExchangeRateNotifier(this._db) : super(const AsyncValue.data(null));

  Future<void> addRate({
    required String fromCurrency,
    required String toCurrency,
    required double rate,
    required DateTime date,
    String source = 'manual',
  }) async {
    state = const AsyncValue.loading();
    try {
      await _db.exchangeRatesDao.insertRate(
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        rate: rate,
        date: date,
        source: source,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateRate(String id, double rate) async {
    state = const AsyncValue.loading();
    try {
      await _db.exchangeRatesDao.updateRate(id, rate: rate);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteRate(String id) async {
    state = const AsyncValue.loading();
    try {
      await _db.exchangeRatesDao.deleteRate(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteRatesBySource(String source) async {
    state = const AsyncValue.loading();
    try {
      await _db.exchangeRatesDao.deleteRatesBySource(source);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final exchangeRateNotifierProvider = StateNotifierProvider<ExchangeRateNotifier, AsyncValue<void>>((ref) {
  final db = ref.watch(databaseProvider);
  return ExchangeRateNotifier(db);
});

/// Commodity notifier for adding new currencies
class CommodityNotifier extends StateNotifier<AsyncValue<void>> {
  final LocalFinanceDatabase _db;

  CommodityNotifier(this._db) : super(const AsyncValue.data(null));

  Future<void> addCurrency({
    required String id,
    required String mnemonic,
    required String fullName,
    int fraction = 100,
  }) async {
    state = const AsyncValue.loading();
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.into(_db.commodities).insert(
        CommoditiesCompanion.insert(
          id: id,
          namespace: 'CURRENCY',
          mnemonic: mnemonic,
          fullName: drift.Value(fullName),
          fraction: drift.Value(fraction),
          createdAt: now,
          updatedAt: now,
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateCurrency(Commodity commodity) async {
    state = const AsyncValue.loading();
    try {
      await (_db.update(_db.commodities)..where((c) => c.id.equals(commodity.id))).write(
        CommoditiesCompanion(
          mnemonic: drift.Value(commodity.mnemonic),
          fullName: drift.Value(commodity.fullName),
          fraction: drift.Value(commodity.fraction),
          updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final commodityNotifierProvider = StateNotifierProvider<CommodityNotifier, AsyncValue<void>>((ref) {
  final db = ref.watch(databaseProvider);
  return CommodityNotifier(db);
});

/// Helper model for currency with exchange rate info
class CurrencyWithRate {
  final Commodity currency;
  final double? rateToBase; // Rate to base currency (CNY)
  final DateTime? rateDate;
  final String? rateSource;

  CurrencyWithRate({
    required this.currency,
    this.rateToBase,
    this.rateDate,
    this.rateSource,
  });
}

/// Provider for currencies with their latest rates to base currency (CNY)
final currenciesWithRatesProvider = FutureProvider<List<CurrencyWithRate>>((ref) async {
  final currencies = ref.watch(currenciesProvider);
  final db = ref.watch(databaseProvider);

  if (currencies.isEmpty) return [];

  final result = <CurrencyWithRate>[];
  for (final currency in currencies) {
    if (currency.id == 'CNY') {
      result.add(CurrencyWithRate(currency: currency, rateToBase: 1.0));
      continue;
    }

    final rate = await db.exchangeRatesDao.getLatestRate(currency.id, 'CNY');
    result.add(CurrencyWithRate(
      currency: currency,
      rateToBase: rate?.rate,
      rateDate: rate != null ? DateTime.fromMillisecondsSinceEpoch(rate.date) : null,
      rateSource: rate?.source,
    ));
  }

  return result;
});

/// Currency conversion helper
class CurrencyConverter {
  final LocalFinanceDatabase _db;
  final Map<String, ExchangeRate> _ratesMap;

  CurrencyConverter(this._db, this._ratesMap);

  /// Convert amount from one currency to another
  /// Returns null if conversion is not possible
  Future<double?> convert(double amount, String from, String to) async {
    if (from == to) return amount;

    // Try direct rate
    final directKey = '${from}_${to}';
    if (_ratesMap.containsKey(directKey)) {
      return amount * _ratesMap[directKey]!.rate;
    }

    // Try inverse rate
    final inverseKey = '${to}_${from}';
    if (_ratesMap.containsKey(inverseKey)) {
      return amount / _ratesMap[inverseKey]!.rate;
    }

    // Try via base currency (CNY)
    final fromToBase = '${from}_CNY';
    final baseToTo = '${to}_CNY';

    if (_ratesMap.containsKey(fromToBase) && _ratesMap.containsKey(baseToTo)) {
      final inCny = amount * _ratesMap[fromToBase]!.rate;
      return inCny / _ratesMap[baseToTo]!.rate;
    }

    // Fallback to database lookup
    return _db.exchangeRatesDao.convertAmount(amount, from, to);
  }
}

/// Provider for currency converter
final currencyConverterProvider = Provider<CurrencyConverter>((ref) {
  final db = ref.watch(databaseProvider);
  final ratesMap = ref.watch(exchangeRatesMapProvider);
  return CurrencyConverter(db, ratesMap);
});

/// Currency display formatter - shows amount in original and base currency
class CurrencyDisplayFormatter {
  final CurrencyConverter converter;
  final String baseCurrency;

  CurrencyDisplayFormatter(this.converter, this.baseCurrency);

  /// Format amount with dual currency display
  /// Returns "¥100 (≈ $14.50)" format
  Future<String> formatDual(
    double amount,
    String originalCurrency, {
    bool showBaseAlways = false,
  }) async {
    if (originalCurrency == baseCurrency) {
      return _formatAmount(amount, originalCurrency);
    }

    final baseAmount = await converter.convert(amount, originalCurrency, baseCurrency);
    if (baseAmount == null) {
      return _formatAmount(amount, originalCurrency);
    }

    final originalFormatted = _formatAmount(amount, originalCurrency);
    final baseFormatted = _formatAmount(baseAmount, baseCurrency);

    return '$originalFormatted (≈ $baseFormatted)';
  }

  /// Format amount with conversion rate info
  Future<String> formatWithRate(
    double amount,
    String originalCurrency,
  ) async {
    if (originalCurrency == baseCurrency) {
      return _formatAmount(amount, originalCurrency);
    }

    final rate = await converter.convert(1, originalCurrency, baseCurrency);
    if (rate == null) {
      return _formatAmount(amount, originalCurrency);
    }

    final baseAmount = amount * rate;
    final originalFormatted = _formatAmount(amount, originalCurrency);
    final baseFormatted = _formatAmount(baseAmount, baseCurrency);

    return '$originalFormatted\n(≈ $baseFormatted @ ${rate.toStringAsFixed(4)})';
  }

  String _formatAmount(double amount, String currency) {
    final symbol = _getCurrencySymbol(currency);
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  String _getCurrencySymbol(String currency) {
    const symbols = {
      'CNY': '¥',
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
      'KRW': '₩',
      'HKD': 'HK\$',
      'SGD': 'S\$',
      'AUD': 'A\$',
      'CAD': 'C\$',
      'CHF': 'CHF',
      'THB': '฿',
      'MYR': 'RM',
    };
    return symbols[currency] ?? currency;
  }
}

/// Provider for currency display formatter
final currencyDisplayFormatterProvider = Provider<CurrencyDisplayFormatter>((ref) {
  final converter = ref.watch(currencyConverterProvider);
  // Default base currency - in real app, this would be from settings
  return CurrencyDisplayFormatter(converter, 'CNY');
});

/// Provider for converting amounts for reports
/// Takes a list of amounts with their currencies and converts all to base currency
final convertToBaseCurrencyProvider = FutureProvider.family<double, ({double amount, String currency})>((ref, params) async {
  final converter = ref.watch(currencyConverterProvider);
  if (params.currency == 'CNY') return params.amount;
  final result = await converter.convert(params.amount, params.currency, 'CNY');
  return result ?? params.amount;
});

/// Provider for account currency balance (converts to base currency)
final accountBalanceInBaseCurrencyProvider = FutureProvider.family<double, String>((ref, accountId) async {
  final db = ref.watch(databaseProvider);
  final converter = ref.watch(currencyConverterProvider);
  
  // Get account with its currency
  final account = await (db.select(db.accounts)..where((a) => a.id.equals(accountId))).getSingleOrNull();
  if (account == null) return 0.0;
  
  // Get account balance from splits (not transactions directly)
  final splits = await (db.select(db.splits)
    ..where((s) => s.accountId.equals(accountId))).get();
  
  double balance = 0.0;
  for (final split in splits) {
    final amount = split.valueNum / split.valueDenom.toDouble();
    if (account.commodityId == 'CNY') {
      balance += amount;
    } else {
      final converted = await converter.convert(amount, account.commodityId, 'CNY');
      if (converted != null) {
        balance += converted;
      }
    }
  }
  
  return balance;
});

// ============================================================
// Exchange Rate Auto-Update and Alert System
// ============================================================

/// Rate fetch service provider
final rateFetchServiceProvider = Provider<RateFetchService>((ref) {
  return RateFetchService();
});

/// Auto-update settings
class AutoUpdateSettings {
  final bool enabled;
  final Duration interval;
  final double alertThreshold; // Percentage change threshold for alerts
  final String baseCurrency;

  const AutoUpdateSettings({
    this.enabled = true,
    this.interval = const Duration(hours: 6),
    this.alertThreshold = 5.0, // 5% change triggers alert
    this.baseCurrency = 'CNY',
  });

  AutoUpdateSettings copyWith({
    bool? enabled,
    Duration? interval,
    double? alertThreshold,
    String? baseCurrency,
  }) {
    return AutoUpdateSettings(
      enabled: enabled ?? this.enabled,
      interval: interval ?? this.interval,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      baseCurrency: baseCurrency ?? this.baseCurrency,
    );
  }
}

/// Provider for auto-update settings
final autoUpdateSettingsProvider = StateNotifierProvider<AutoUpdateSettingsNotifier, AutoUpdateSettings>((ref) {
  return AutoUpdateSettingsNotifier();
});

class AutoUpdateSettingsNotifier extends StateNotifier<AutoUpdateSettings> {
  AutoUpdateSettingsNotifier() : super(const AutoUpdateSettings());

  void setEnabled(bool enabled) => state = state.copyWith(enabled: enabled);
  void setInterval(Duration interval) => state = state.copyWith(interval: interval);
  void setAlertThreshold(double threshold) => state = state.copyWith(alertThreshold: threshold);
  void setBaseCurrency(String currency) => state = state.copyWith(baseCurrency: currency);
}

/// Rate change alert model
class RateChangeAlert {
  final String fromCurrency;
  final String toCurrency;
  final double oldRate;
  final double newRate;
  final double changePercent;
  final DateTime timestamp;

  RateChangeAlert({
    required this.fromCurrency,
    required this.toCurrency,
    required this.oldRate,
    required this.newRate,
    required this.changePercent,
    required this.timestamp,
  });

  String get direction => changePercent >= 0 ? '上涨' : '下跌';
}

/// Enhanced exchange rate notifier with auto-update and alerts
class EnhancedExchangeRateNotifier extends StateNotifier<AsyncValue<void>> {
  final LocalFinanceDatabase _db;
  final RateFetchService _fetchService;
  final Ref _ref;
  Timer? _autoUpdateTimer;
  final List<RateChangeAlert> _pendingAlerts = [];

  EnhancedExchangeRateNotifier(this._db, this._fetchService, this._ref) 
      : super(const AsyncValue.data(null));

  /// Start auto-update timer
  void startAutoUpdate() {
    final settings = _ref.read(autoUpdateSettingsProvider);
    if (!settings.enabled) return;

    _autoUpdateTimer?.cancel();
    _autoUpdateTimer = Timer.periodic(settings.interval, (_) {
      fetchAndUpdateRates();
    });
    
    debugPrint('汇率自动更新已启动，间隔: ${settings.interval.inHours}小时');
  }

  /// Stop auto-update timer
  void stopAutoUpdate() {
    _autoUpdateTimer?.cancel();
    _autoUpdateTimer = null;
    debugPrint('汇率自动更新已停止');
  }

  /// Fetch and update rates from API
  Future<List<RateChangeAlert>> fetchAndUpdateRates({
    String? baseCurrency,
    bool showAlerts = true,
  }) async {
    final settings = _ref.read(autoUpdateSettingsProvider);
    final base = baseCurrency ?? settings.baseCurrency;

    state = const AsyncValue.loading();
    final alerts = <RateChangeAlert>[];

    try {
      // Check if online
      if (!await _fetchService.isOnline()) {
        debugPrint('离线模式，跳过汇率更新');
        state = const AsyncValue.data(null);
        return [];
      }

      // Fetch rates from API
      final fetchedRates = await _fetchService.fetchRates(base);
      
      // Get existing rates for comparison
      final existingRates = await _db.exchangeRatesDao.getAll();
      final existingMap = <String, ExchangeRate>{};
      for (final rate in existingRates) {
        final key = '${rate.fromCurrency}_${rate.toCurrency}';
        if (!existingMap.containsKey(key) || existingMap[key]!.date < rate.date) {
          existingMap[key] = rate;
        }
      }

      // Prepare batch insert
      final companions = <ExchangeRatesCompanion>[];
      final now = DateTime.now();

      for (final fetched in fetchedRates) {
        // Check for significant change
        final key = '${fetched.fromCurrency}_${fetched.toCurrency}';
        final existing = existingMap[key];
        
        if (existing != null && showAlerts) {
          final changePercent = ((fetched.rate - existing.rate) / existing.rate) * 100;
          if (changePercent.abs() >= settings.alertThreshold) {
            final alert = RateChangeAlert(
              fromCurrency: fetched.fromCurrency,
              toCurrency: fetched.toCurrency,
              oldRate: existing.rate,
              newRate: fetched.rate,
              changePercent: changePercent,
              timestamp: now,
            );
            alerts.add(alert);
            _pendingAlerts.add(alert);
          }
        }

        companions.add(ExchangeRatesCompanion.insert(
          id: '${fetched.fromCurrency}_${fetched.toCurrency}_${now.millisecondsSinceEpoch}_${fetched.source}',
          fromCurrency: fetched.fromCurrency,
          toCurrency: fetched.toCurrency,
          rate: fetched.rate,
          date: now.millisecondsSinceEpoch,
          source: drift.Value(fetched.source),
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ));
      }

      // Batch insert new rates
      if (companions.isNotEmpty) {
        await _db.exchangeRatesDao.batchInsertRates(companions);
        debugPrint('已更新 ${companions.length} 个汇率');
      }

      state = const AsyncValue.data(null);
      
      // Show notifications for alerts
      if (alerts.isNotEmpty) {
        await _showRateAlerts(alerts);
      }

      return alerts;
    } catch (e, st) {
      debugPrint('汇率更新失败: $e');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Add manual rate (overrides auto-fetched)
  Future<void> addManualRate({
    required String fromCurrency,
    required String toCurrency,
    required double rate,
    DateTime? date,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _db.exchangeRatesDao.insertRate(
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        rate: rate,
        date: date ?? DateTime.now(),
        source: 'manual',
      );
      debugPrint('已添加手动汇率: $fromCurrency -> $toCurrency = $rate');
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Get pending alerts
  List<RateChangeAlert> getPendingAlerts() {
    return List.unmodifiable(_pendingAlerts);
  }

  /// Clear pending alerts
  void clearAlerts() {
    _pendingAlerts.clear();
  }

  /// Show rate change notifications
  Future<void> _showRateAlerts(List<RateChangeAlert> alerts) async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      
      // Initialize if not already done
      await plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      for (final alert in alerts) {
        await plugin.show(
          alert.toCurrency.hashCode,
          '汇率变动提醒',
          '${alert.fromCurrency}/${alert.toCurrency} ${alert.direction} ${alert.changePercent.abs().toStringAsFixed(2)}%\n'
          '旧汇率: ${alert.oldRate.toStringAsFixed(4)} → 新汇率: ${alert.newRate.toStringAsFixed(4)}',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'exchange_rate_alerts',
              '汇率提醒',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      }
    } catch (e) {
      debugPrint('显示通知失败: $e');
    }
  }

  @override
  void dispose() {
    stopAutoUpdate();
    super.dispose();
  }
}

/// Provider for enhanced exchange rate notifier
final enhancedExchangeRateNotifierProvider = 
    StateNotifierProvider<EnhancedExchangeRateNotifier, AsyncValue<void>>((ref) {
  final db = ref.watch(databaseProvider);
  final fetchService = ref.watch(rateFetchServiceProvider);
  return EnhancedExchangeRateNotifier(db, fetchService, ref);
});

/// Provider for rate history for a specific currency pair
final rateHistoryProvider = FutureProvider.family<List<ExchangeRate>, ({String from, String to})>((ref, params) async {
  final db = ref.watch(databaseProvider);
  return db.exchangeRatesDao.getRatesForDateRange(
    params.from,
    params.to,
    DateTime.now().subtract(const Duration(days: 30)),
    DateTime.now(),
  );
});

/// Provider for rate history statistics
final rateHistoryStatsProvider = FutureProvider.family<RateHistoryStats, ({String from, String to})>((ref, params) async {
  final rates = await ref.watch(rateHistoryProvider(params).future);
  
  if (rates.isEmpty) {
    return RateHistoryStats.empty();
  }

  final rateValues = rates.map((r) => r.rate).toList();
  final avg = rateValues.reduce((a, b) => a + b) / rateValues.length;
  final max = rateValues.reduce((a, b) => a > b ? a : b);
  final min = rateValues.reduce((a, b) => a < b ? a : b);
  final latest = rateValues.first;
  final oldest = rateValues.last;
  final change = ((latest - oldest) / oldest) * 100;

  return RateHistoryStats(
    count: rates.length,
    average: avg,
    max: max,
    min: min,
    latest: latest,
    changePercent: change,
    oldestDate: DateTime.fromMillisecondsSinceEpoch(rates.last.date),
    latestDate: DateTime.fromMillisecondsSinceEpoch(rates.first.date),
  );
});

/// Rate history statistics model
class RateHistoryStats {
  final int count;
  final double average;
  final double max;
  final double min;
  final double latest;
  final double changePercent;
  final DateTime oldestDate;
  final DateTime latestDate;

  RateHistoryStats({
    required this.count,
    required this.average,
    required this.max,
    required this.min,
    required this.latest,
    required this.changePercent,
    required this.oldestDate,
    required this.latestDate,
  });

  factory RateHistoryStats.empty() => RateHistoryStats(
    count: 0,
    average: 0,
    max: 0,
    min: 0,
    latest: 0,
    changePercent: 0,
    oldestDate: DateTime.now(),
    latestDate: DateTime.now(),
  );

  String get trend => changePercent >= 0 ? '上涨' : '下跌';
}

/// Provider for checking if rates need update
final ratesNeedUpdateProvider = FutureProvider<bool>((ref) async {
  final db = ref.watch(databaseProvider);
  final currencies = ref.watch(currenciesProvider);
  
  if (currencies.isEmpty) return false;

  for (final currency in currencies) {
    if (currency.id == 'CNY') continue;
    
    final latestDate = await db.exchangeRatesDao.getLatestRateDate(currency.id, 'CNY');
    if (latestDate == null) return true;
    
    final age = DateTime.now().difference(latestDate);
    if (age.inHours > 24) return true;
  }
  
  return false;
});