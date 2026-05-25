import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart' as uuid_pkg;
import 'package:core/core.dart';

import 'package:database/database.dart' hide InvestmentHolding, InvestmentTransaction;
import 'package:finance_app/features/accounts/data/account_provider.dart';

/// Provider for all investment holdings for an account.
final investmentHoldingsProvider = StreamProvider.family<List<InvestmentHolding>, String>((ref, accountId) {
  final db = ref.watch(databaseProvider);
  return db.investmentHoldingsDao.watchHoldingsForAccount(accountId);
});

/// Provider for a single holding by ID.
final investmentHoldingProvider = FutureProvider.family<InvestmentHolding?, String>((ref, holdingId) {
  final db = ref.watch(databaseProvider);
  return db.investmentHoldingsDao.getHoldingById(holdingId);
});

/// Provider for all investment transactions for an account.
final investmentTransactionsProvider = StreamProvider.family<List<InvestmentTransaction>, String>((ref, accountId) {
  final db = ref.watch(databaseProvider);
  return db.investmentTransactionsDao.watchTransactionsForAccount(accountId);
});

/// Provider for transactions for a specific holding.
final holdingTransactionsProvider = FutureProvider.family<List<InvestmentTransaction>, String>((ref, holdingId) {
  final db = ref.watch(databaseProvider);
  return db.investmentTransactionsDao.getTransactionsForHolding(holdingId);
});

/// Model for holding with performance metrics.
class HoldingPerformance {
  final InvestmentHolding holding;
  final double quantity;
  final double averageCost;
  final double currentPrice;
  final double costBasis;
  final double marketValue;
  final double unrealizedGain;
  final double unrealizedGainPercent;

  HoldingPerformance({
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

/// Provider for holdings with performance calculations.
final holdingsWithPerformanceProvider = FutureProvider.family<List<HoldingPerformance>, String>((ref, accountId) async {
  final db = ref.watch(databaseProvider);
  final holdings = await db.investmentHoldingsDao.getHoldingsForAccount(accountId);
  
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
        : 0.0;
    
    return HoldingPerformance(
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
});

/// Summary of investment account performance.
class InvestmentSummary {
  final double totalCostBasis;
  final double totalMarketValue;
  final double totalUnrealizedGain;
  final double totalUnrealizedGainPercent;
  final double totalDividends;
  final double totalRealizedGain;
  final int holdingCount;

  InvestmentSummary({
    required this.totalCostBasis,
    required this.totalMarketValue,
    required this.totalUnrealizedGain,
    required this.totalUnrealizedGainPercent,
    required this.totalDividends,
    required this.totalRealizedGain,
    required this.holdingCount,
  });

  /// Total ROI including unrealized and realized gains plus dividends.
  double get totalROI {
    if (totalCostBasis <= 0) return 0;
    return ((totalUnrealizedGain + totalRealizedGain + totalDividends) / totalCostBasis) * 100;
  }
}

/// Provider for investment account summary.
final investmentSummaryProvider = FutureProvider.family<InvestmentSummary, String>((ref, accountId) async {
  final db = ref.watch(databaseProvider);
  
  // Get holdings performance
  final holdingsPerformance = await ref.watch(holdingsWithPerformanceProvider(accountId).future);
  
  // Get dividends
  final dividends = await db.investmentTransactionsDao.getTotalDividends(accountId);
  
  // Calculate totals
  double totalCostBasis = 0;
  double totalMarketValue = 0;
  double totalUnrealizedGain = 0;
  
  for (final hp in holdingsPerformance) {
    totalCostBasis += hp.costBasis;
    totalMarketValue += hp.marketValue;
    totalUnrealizedGain += hp.unrealizedGain;
  }
  
  final totalUnrealizedGainPercent = totalCostBasis > 0
      ? (totalUnrealizedGain / totalCostBasis) * 100
      : 0.0;
  
  // Get realized gains (simplified - would need FIFO matching for accurate calculation)
  final realizedGain = await db.investmentTransactionsDao.getRealizedGains(accountId);
  
  return InvestmentSummary(
    totalCostBasis: totalCostBasis,
    totalMarketValue: totalMarketValue,
    totalUnrealizedGain: totalUnrealizedGain,
    totalUnrealizedGainPercent: totalUnrealizedGainPercent,
    totalDividends: dividends,
    totalRealizedGain: realizedGain,
    holdingCount: holdingsPerformance.length,
  );
});

/// Notifier for managing investment holdings.
class InvestmentHoldingsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  
  InvestmentHoldingsNotifier(this._ref) : super(const AsyncValue.data(null));
  
  /// Add a new holding.
  Future<String> addHolding({
    required String accountId,
    required String symbol,
    required String currencyId,
    String? securityName,
    SecurityType securityType = SecurityType.stock,
    required double quantity,
    required double averageCost,
    String? notes,
  }) async {
    final db = _ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = const uuid_pkg.Uuid().v4();
    
    // Use fixed-point arithmetic (4 decimal places for quantity, 2 for cost)
    final quantityNum = (quantity * 10000).round();
    final averageCostNum = (averageCost * 100).round();
    
    await db.investmentHoldingsDao.insertHolding(
      InvestmentHoldingsCompanion.insert(
        id: id,
        accountId: accountId,
        symbol: symbol,
        securityName: drift.Value(securityName),
        securityType: drift.Value(securityType.code),
        currencyId: currencyId,
        quantityNum: quantityNum,
        averageCostNum: averageCostNum,
        createdAt: now,
        updatedAt: now,
        notes: drift.Value(notes),
      ),
    );
    
    return id;
  }
  
  /// Update holding price.
  Future<void> updatePrice(String holdingId, double currentPrice) async {
    final db = _ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final priceNum = (currentPrice * 100).round();
    
    await db.investmentHoldingsDao.updateHoldingPrice(
      holdingId,
      priceNum,
      100,
      now,
    );
  }
  
  /// Delete a holding.
  Future<void> deleteHolding(String holdingId) async {
    final db = _ref.read(databaseProvider);
    await db.investmentHoldingsDao.deleteHolding(holdingId);
  }
}

/// Provider for holdings notifier.
final investmentHoldingsNotifierProvider = StateNotifierProvider<InvestmentHoldingsNotifier, AsyncValue<void>>((ref) {
  return InvestmentHoldingsNotifier(ref);
});

/// Notifier for managing investment transactions.
class InvestmentTransactionsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  
  InvestmentTransactionsNotifier(this._ref) : super(const AsyncValue.data(null));
  
  /// Record a buy transaction.
  Future<String> recordBuy({
    required String accountId,
    String? holdingId,
    required String symbol,
    String? securityName,
    required double quantity,
    required double price,
    required double amount,
    required String currencyId,
    double fee = 0,
    double tax = 0,
    String? notes,
    String? referenceNum,
  }) async {
    final db = _ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = const uuid_pkg.Uuid().v4();
    
    final quantityNum = (quantity * 10000).round();
    final priceNum = (price * 100).round();
    final amountNum = (amount * 100).round();
    final feeNum = (fee * 100).round();
    final taxNum = (tax * 100).round();
    
    await db.investmentTransactionsDao.insertTransaction(
      InvestmentTransactionsCompanion.insert(
        id: id,
        accountId: accountId,
        holdingId: drift.Value(holdingId),
        transactionType: 'buy',
        transactionDate: now,
        symbol: symbol,
        securityName: drift.Value(securityName),
        quantityNum: drift.Value(quantityNum),
        quantityDenom: const drift.Value(10000),
        priceNum: drift.Value(priceNum),
        priceDenom: const drift.Value(100),
        amountNum: amountNum,
        amountDenom: const drift.Value(100),
        feeNum: drift.Value(feeNum),
        feeDenom: const drift.Value(100),
        taxNum: drift.Value(taxNum),
        taxDenom: const drift.Value(100),
        currencyId: currencyId,
        notes: drift.Value(notes),
        referenceNum: drift.Value(referenceNum),
        createdAt: now,
        updatedAt: now,
      ),
    );
    
    return id;
  }
  
  /// Record a sell transaction.
  Future<String> recordSell({
    required String accountId,
    String? holdingId,
    required String symbol,
    String? securityName,
    required double quantity,
    required double price,
    required double amount,
    required String currencyId,
    double fee = 0,
    double tax = 0,
    String? notes,
    String? referenceNum,
  }) async {
    final db = _ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = const uuid_pkg.Uuid().v4();
    
    final quantityNum = (quantity * 10000).round();
    final priceNum = (price * 100).round();
    final amountNum = (amount * 100).round();
    final feeNum = (fee * 100).round();
    final taxNum = (tax * 100).round();
    
    await db.investmentTransactionsDao.insertTransaction(
      InvestmentTransactionsCompanion.insert(
        id: id,
        accountId: accountId,
        holdingId: drift.Value(holdingId),
        transactionType: 'sell',
        transactionDate: now,
        symbol: symbol,
        securityName: drift.Value(securityName),
        quantityNum: drift.Value(quantityNum),
        quantityDenom: const drift.Value(10000),
        priceNum: drift.Value(priceNum),
        priceDenom: const drift.Value(100),
        amountNum: amountNum,
        amountDenom: const drift.Value(100),
        feeNum: drift.Value(feeNum),
        feeDenom: const drift.Value(100),
        taxNum: drift.Value(taxNum),
        taxDenom: const drift.Value(100),
        currencyId: currencyId,
        notes: drift.Value(notes),
        referenceNum: drift.Value(referenceNum),
        createdAt: now,
        updatedAt: now,
      ),
    );
    
    return id;
  }
  
  /// Record a dividend.
  Future<String> recordDividend({
    required String accountId,
    String? holdingId,
    required String symbol,
    required double amount,
    required String currencyId,
    String? notes,
    String? referenceNum,
  }) async {
    final db = _ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = const uuid_pkg.Uuid().v4();
    
    final amountNum = (amount * 100).round();
    
    await db.investmentTransactionsDao.insertTransaction(
      InvestmentTransactionsCompanion.insert(
        id: id,
        accountId: accountId,
        holdingId: drift.Value(holdingId),
        transactionType: 'dividend',
        transactionDate: now,
        symbol: symbol,
        amountNum: amountNum,
        amountDenom: const drift.Value(100),
        currencyId: currencyId,
        notes: drift.Value(notes),
        referenceNum: drift.Value(referenceNum),
        createdAt: now,
        updatedAt: now,
      ),
    );
    
    return id;
  }
  
  /// Delete a transaction.
  Future<void> deleteTransaction(String transactionId) async {
    final db = _ref.read(databaseProvider);
    await db.investmentTransactionsDao.deleteTransaction(transactionId);
  }
}

/// Provider for transactions notifier.
final investmentTransactionsNotifierProvider = StateNotifierProvider<InvestmentTransactionsNotifier, AsyncValue<void>>((ref) {
  return InvestmentTransactionsNotifier(ref);
});
