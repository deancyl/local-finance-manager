import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:database/database.dart';
import '../../accounts/data/account_provider.dart';
import '../../currency/data/currency_provider.dart';

/// Service for converting amounts between currencies in reports.
class CurrencyConversionService {
  final LocalFinanceDatabase _db;
  final Map<String, ExchangeRate> _ratesMap;

  CurrencyConversionService(this._db, this._ratesMap);

  /// Converts an amount from one currency to another.
  /// Returns null if conversion is not possible.
  Future<double?> convert(
    double amount,
    String fromCurrency,
    String toCurrency,
  ) async {
    if (fromCurrency == toCurrency) return amount;

    // Try direct rate
    final directKey = '${fromCurrency}_$toCurrency';
    if (_ratesMap.containsKey(directKey)) {
      return amount * _ratesMap[directKey]!.rate;
    }

    // Try inverse rate
    final inverseKey = '${toCurrency}_$fromCurrency';
    if (_ratesMap.containsKey(inverseKey)) {
      return amount / _ratesMap[inverseKey]!.rate;
    }

    // Try via base currency (CNY)
    final fromToBase = '${fromCurrency}_CNY';
    final baseToTo = '${toCurrency}_CNY';

    if (_ratesMap.containsKey(fromToBase) && _ratesMap.containsKey(baseToTo)) {
      final inCny = amount * _ratesMap[fromToBase]!.rate;
      return inCny / _ratesMap[baseToTo]!.rate;
    }

    // Fallback to database lookup
    return _db.exchangeRatesDao.convertAmount(amount, fromCurrency, toCurrency);
  }

  /// Converts an amount to the target currency using the latest rates.
  /// If conversion fails, returns the original amount.
  Future<double> convertOrDefault(
    double amount,
    String fromCurrency,
    String toCurrency,
  ) async {
    final converted = await convert(amount, fromCurrency, toCurrency);
    return converted ?? amount;
  }
}

/// Provider for currency conversion service.
final currencyConversionServiceProvider = Provider<CurrencyConversionService>((ref) {
  final db = ref.watch(databaseProvider);
  final ratesMap = ref.watch(exchangeRatesMapProvider);
  return CurrencyConversionService(db, ratesMap);
});

/// Provider for the selected report currency (defaults to CNY).
final reportCurrencyProvider = StateProvider<String>((ref) => 'CNY');

/// Provider for available report currencies.
final availableReportCurrenciesProvider = Provider<List<String>>((ref) {
  final currencies = ref.watch(currenciesProvider);
  return currencies.map((c) => c.id).toList();
});
