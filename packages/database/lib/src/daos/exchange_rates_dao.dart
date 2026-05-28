part of '../database.dart';

/// Data Access Object for exchange rates
extension type ExchangeRatesDao(LocalFinanceDatabase db) implements LocalFinanceDatabase {
  /// Watch all exchange rates
  Stream<List<ExchangeRate>> watchAll() {
    return (db.select(db.exchangeRates)
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  /// Get all exchange rates
  Future<List<ExchangeRate>> getAll() {
    return (db.select(db.exchangeRates)
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// Get latest rate for a currency pair
  Future<ExchangeRate?> getLatestRate(String fromCurrency, String toCurrency) {
    return (db.select(db.exchangeRates)
          ..where((t) => t.fromCurrency.equals(fromCurrency) & t.toCurrency.equals(toCurrency))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Get rate for a specific date
  Future<ExchangeRate?> getRateForDate(
    String fromCurrency,
    String toCurrency,
    DateTime date,
  ) {
    final dateTimestamp = date.millisecondsSinceEpoch;
    return (db.select(db.exchangeRates)
          ..where((t) =>
              t.fromCurrency.equals(fromCurrency) &
              t.toCurrency.equals(toCurrency) &
              t.date.equals(dateTimestamp)))
        .getSingleOrNull();
  }

  /// Get rates for a date range
  Future<List<ExchangeRate>> getRatesForDateRange(
    String fromCurrency,
    String toCurrency,
    DateTime startDate,
    DateTime endDate,
  ) {
    final startTimestamp = startDate.millisecondsSinceEpoch;
    final endTimestamp = endDate.millisecondsSinceEpoch;
    return (db.select(db.exchangeRates)
          ..where((t) =>
              t.fromCurrency.equals(fromCurrency) &
              t.toCurrency.equals(toCurrency) &
              t.date.isBetweenValues(startTimestamp, endTimestamp))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// Get all rates from a specific source
  Future<List<ExchangeRate>> getRatesBySource(String source) {
    return (db.select(db.exchangeRates)
          ..where((t) => t.source.equals(source))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// Insert a new exchange rate
  Future<void> insertRate({
    required String fromCurrency,
    required String toCurrency,
    required double rate,
    required DateTime date,
    String source = 'manual',
  }) async {
    final id = '${fromCurrency}_${toCurrency}_${date.millisecondsSinceEpoch}_$source';
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.into(db.exchangeRates).insert(
          ExchangeRatesCompanion.insert(
            id: id,
            fromCurrency: fromCurrency,
            toCurrency: toCurrency,
            rate: rate,
            date: date.millisecondsSinceEpoch,
            source: Value(source),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// Update an existing exchange rate
  Future<int> updateRate(String id, {required double rate}) {
    return (db.update(db.exchangeRates)..where((t) => t.id.equals(id))).write(
      ExchangeRatesCompanion(
        rate: Value(rate),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Delete an exchange rate
  Future<int> deleteRate(String id) {
    return (db.delete(db.exchangeRates)..where((t) => t.id.equals(id))).go();
  }

  /// Delete all rates from a specific source
  Future<int> deleteRatesBySource(String source) {
    return (db.delete(db.exchangeRates)..where((t) => t.source.equals(source))).go();
  }

  /// Get all unique currency pairs
  Future<List<({String from, String to})>> getCurrencyPairs() async {
    final query = db.selectOnly(db.exchangeRates, distinct: true)
      ..addColumns([db.exchangeRates.fromCurrency, db.exchangeRates.toCurrency]);

    final results = await query.get();
    return results.map((row) {
      return (
        from: row.read(db.exchangeRates.fromCurrency)!,
        to: row.read(db.exchangeRates.toCurrency)!,
      );
    }).toList();
  }

  /// Batch insert rates (for API imports)
  Future<void> batchInsertRates(List<ExchangeRatesCompanion> rates) {
    return db.batch((batch) {
      batch.insertAll(db.exchangeRates, rates);
    });
  }

  /// Convert amount from one currency to another using fixed-point arithmetic.
  /// Returns null if no rate is available.
  /// Note: Exchange rates are stored as doubles in the database schema,
  /// so we convert them to FixedPoint for calculations to preserve precision.
  Future<double?> convertAmount(
    double amount,
    String fromCurrency,
    String toCurrency,
  ) async {
    if (fromCurrency == toCurrency) {
      return amount;
    }

    final rate = await getLatestRate(fromCurrency, toCurrency);
    if (rate == null) {
      // Try inverse rate
      final inverseRate = await getLatestRate(toCurrency, fromCurrency);
      if (inverseRate != null) {
        final amountFp = FixedPoint.parse(amount.toString());
        final rateFp = FixedPoint.parse(inverseRate.rate.toString());
        return (amountFp / rateFp).toDouble();
      }
      return null;
    }

    final amountFp = FixedPoint.parse(amount.toString());
    final rateFp = FixedPoint.parse(rate.rate.toString());
    return (amountFp * rateFp).toDouble();
  }

  /// Get the most recent rate date for a currency pair
  Future<DateTime?> getLatestRateDate(String fromCurrency, String toCurrency) async {
    final rate = await getLatestRate(fromCurrency, toCurrency);
    return rate != null ? DateTime.fromMillisecondsSinceEpoch(rate.date) : null;
  }
}
