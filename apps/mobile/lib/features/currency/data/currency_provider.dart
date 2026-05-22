import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import 'package:database/database.dart';

// Re-export databaseProvider from accounts for convenience
export 'package:finance_app/features/accounts/data/account_provider.dart' show databaseProvider;

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