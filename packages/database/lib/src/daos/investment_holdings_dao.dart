part of '../database.dart';

/// Data Access Object for investment holdings.
@DriftAccessor(tables: [InvestmentHoldings])
class InvestmentHoldingsDao extends DatabaseAccessor<LocalFinanceDatabase>
    with _$InvestmentHoldingsDaoMixin, AuditableMixin {
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
  Future<void> insertHolding(InvestmentHoldingsCompanion holding) async {
    await into(investmentHoldings).insert(holding);
    // Audit log for CREATE operation
    await logMutation(
      operation: 'CREATE',
      entityType: 'investment_holding',
      entityId: holding.id.value,
      newValue: holding.toJson(),
    );
  }

  /// Update an existing holding.
  Future<void> updateHolding(InvestmentHoldingsCompanion holding) async {
    // Get old value before update for audit log
    final oldHolding = await getHoldingById(holding.id.value);
    
    await (update(investmentHoldings)
          ..where((h) => h.id.equals(holding.id.value)))
        .write(holding);
    
    // Audit log for UPDATE operation
    await logMutation(
      operation: 'UPDATE',
      entityType: 'investment_holding',
      entityId: holding.id.value,
      oldValue: oldHolding?.toJson(),
      newValue: holding.toJson(),
    );
  }

  /// Delete a holding.
  Future<void> deleteHolding(String id) async {
    // Get old value before delete for audit log
    final oldHolding = await getHoldingById(id);
    
    await (delete(investmentHoldings)..where((h) => h.id.equals(id))).go();
    
    // Audit log for DELETE operation
    await logMutation(
      operation: 'DELETE',
      entityType: 'investment_holding',
      entityId: id,
      oldValue: oldHolding?.toJson(),
    );
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

  /// Get total market value for an account using fixed-point arithmetic.
  /// Returns the value as a FixedPoint to preserve precision.
  Future<double> getTotalMarketValue(String accountId) async {
    final holdings = await getHoldingsForAccount(accountId);
    FixedPoint total = FixedPoint.zero;
    for (final h in holdings) {
      if (h.currentPriceNum != null && h.currentPriceDenom != null) {
        final quantity = FixedPoint(h.quantityNum, h.quantityDenom);
        final price = FixedPoint(h.currentPriceNum!, h.currentPriceDenom!);
        total += quantity * price;
      }
    }
    return total.toDouble();
  }

  /// Get all holdings with their unrealized gains/losses using fixed-point arithmetic.
  /// All calculations use FixedPoint to preserve precision.
  Future<List<HoldingWithPerformance>> getHoldingsWithPerformance(
    String accountId,
  ) async {
    final holdings = await getHoldingsForAccount(accountId);
    return holdings.map((h) {
      final quantity = FixedPoint(h.quantityNum, h.quantityDenom);
      final avgCost = FixedPoint(h.averageCostNum, h.averageCostDenom);
      final currentPrice = h.currentPriceNum != null && h.currentPriceDenom != null
          ? FixedPoint(h.currentPriceNum!, h.currentPriceDenom!)
          : avgCost;
      
      final costBasis = quantity * avgCost;
      final marketValue = quantity * currentPrice;
      final unrealizedGain = marketValue - costBasis;
      final unrealizedGainPercent = costBasis.isZero 
          ? FixedPoint.zero
          : (unrealizedGain / costBasis) * FixedPoint.fromInt(100);
      
      return HoldingWithPerformance(
        holding: h,
        quantity: quantity.toDouble(),
        averageCost: avgCost.toDouble(),
        currentPrice: currentPrice.toDouble(),
        costBasis: costBasis.toDouble(),
        marketValue: marketValue.toDouble(),
        unrealizedGain: unrealizedGain.toDouble(),
        unrealizedGainPercent: unrealizedGainPercent.toDouble(),
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