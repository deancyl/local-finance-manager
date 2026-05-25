part of '../database.dart';

/// Data Access Object for investment holdings.
@DriftAccessor(tables: [InvestmentHoldings])
class InvestmentHoldingsDao extends DatabaseAccessor<LocalFinanceDatabase>
    with _$InvestmentHoldingsDaoMixin {
  InvestmentHoldingsDao(super.db);

  /// Get all holdings for an account.
  Future<List<InvestmentHolding>> getHoldingsForAccount(String accountId) {
    return (select(investmentHoldings)
          ..where((h) => h.accountId.equals(accountId)))
        .get();
  }

  /// Get a single holding by ID.
  Future<InvestmentHolding?> getHoldingById(String id) {
    return (select(investmentHoldings)..where((h) => h.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get holding by symbol in an account.
  Future<InvestmentHolding?> getHoldingBySymbol(
    String accountId,
    String symbol,
  ) {
    return (select(investmentHoldings)
          ..where((h) =>
              h.accountId.equals(accountId) & h.symbol.equals(symbol)))
        .getSingleOrNull();
  }

  /// Watch all holdings for an account.
  Stream<List<InvestmentHolding>> watchHoldingsForAccount(String accountId) {
    return (select(investmentHoldings)
          ..where((h) => h.accountId.equals(accountId)))
        .watch();
  }

  /// Insert a new holding.
  Future<void> insertHolding(InvestmentHoldingsCompanion holding) {
    return into(investmentHoldings).insert(holding);
  }

  /// Update an existing holding.
  Future<void> updateHolding(InvestmentHoldingsCompanion holding) {
    return (update(investmentHoldings)
          ..where((h) => h.id.equals(holding.id.value)))
        .write(holding);
  }

  /// Delete a holding.
  Future<void> deleteHolding(String id) {
    return (delete(investmentHoldings)..where((h) => h.id.equals(id))).go();
  }

  /// Update current price for a holding.
  Future<void> updateHoldingPrice(
    String id,
    int priceNum,
    int priceDenom,
    int timestamp,
  ) {
    return (update(investmentHoldings)..where((h) => h.id.equals(id)))
        .write(InvestmentHoldingsCompanion(
          currentPriceNum: Value(priceNum),
          currentPriceDenom: Value(priceDenom),
          lastPriceUpdate: Value(timestamp),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          version: Value.absent(),
        ));
  }

  /// Get total market value for an account.
  Future<double> getTotalMarketValue(String accountId) async {
    final holdings = await getHoldingsForAccount(accountId);
    double total = 0;
    for (final h in holdings) {
      if (h.currentPriceNum != null && h.currentPriceDenom != null) {
        final quantity = h.quantityNum / h.quantityDenom;
        final price = h.currentPriceNum! / h.currentPriceDenom!;
        total += quantity * price;
      }
    }
    return total;
  }

  /// Get all holdings with their unrealized gains/losses.
  Future<List<HoldingWithPerformance>> getHoldingsWithPerformance(
    String accountId,
  ) async {
    final holdings = await getHoldingsForAccount(accountId);
    return holdings.map((h) {
      final quantity = h.quantityNum / h.quantityDenom;
      final avgCost = h.averageCostNum / h.averageCostDenom;
      final currentPrice = h.currentPriceNum != null && h.currentPriceDenom != null
          ? h.currentPriceNum! / h.currentPriceDenom!
          : avgCost;
      
      final costBasis = quantity * avgCost;
      final marketValue = quantity * currentPrice;
      final unrealizedGain = marketValue - costBasis;
      final unrealizedGainPercent = costBasis > 0 
          ? (unrealizedGain / costBasis) * 100 
          : 0;
      
      return HoldingWithPerformance(
        holding: h,
        quantity: quantity,
        averageCost: avgCost,
        currentPrice: currentPrice,
        costBasis: costBasis,
        marketValue: marketValue,
        unrealizedGain: unrealizedGain,
        unrealizedGainPercent: unrealizedGainPercent,
      );
    }).toList();
  }
}

/// Holding with calculated performance metrics.
class HoldingWithPerformance {
  final InvestmentHolding holding;
  final double quantity;
  final double averageCost;
  final double currentPrice;
  final double costBasis;
  final double marketValue;
  final double unrealizedGain;
  final double unrealizedGainPercent;

  HoldingWithPerformance({
    required this.holding,
    required this.quantity,
    required this.averageCost,
    required this.currentPrice,
    required this.costBasis,
    required this.marketValue,
    required this.unrealizedGain,
    required this.unrealizedGainPercent,
  });

  /// ROI percentage.
  double get roi => unrealizedGainPercent;
}