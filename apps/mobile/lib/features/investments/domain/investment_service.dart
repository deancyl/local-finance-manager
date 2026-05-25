import 'package:core/core.dart';

/// Service for calculating investment performance metrics.
class InvestmentService {
  /// Calculate unrealized gain/loss for a holding.
  static double calculateUnrealizedGain({
    required double quantity,
    required double averageCost,
    required double currentPrice,
  }) {
    final costBasis = quantity * averageCost;
    final marketValue = quantity * currentPrice;
    return marketValue - costBasis;
  }

  /// Calculate unrealized gain/loss percentage.
  static double calculateUnrealizedGainPercent({
    required double quantity,
    required double averageCost,
    required double currentPrice,
  }) {
    final costBasis = quantity * averageCost;
    if (costBasis <= 0) return 0;
    
    final unrealizedGain = calculateUnrealizedGain(
      quantity: quantity,
      averageCost: averageCost,
      currentPrice: currentPrice,
    );
    
    return (unrealizedGain / costBasis) * 100;
  }

  /// Calculate ROI (Return on Investment).
  /// ROI = (Current Value - Cost Basis + Dividends Received + Realized Gains) / Cost Basis * 100
  static double calculateROI({
    required double costBasis,
    required double currentValue,
    double dividendsReceived = 0,
    double realizedGains = 0,
  }) {
    if (costBasis <= 0) return 0;
    
    final totalReturn = (currentValue - costBasis) + dividendsReceived + realizedGains;
    return (totalReturn / costBasis) * 100;
  }

  /// Calculate average cost basis from transactions (FIFO method).
  static double calculateAverageCostBasis(List<InvestmentTransaction> transactions) {
    double totalCost = 0;
    double totalShares = 0;
    
    for (final tx in transactions) {
      if (tx.transactionType == InvestmentTransactionType.buy && 
          tx.quantity != null && tx.price != null) {
        totalCost += tx.quantity! * tx.price! + tx.fee;
        totalShares += tx.quantity!;
      } else if (tx.transactionType == InvestmentTransactionType.sell &&
          tx.quantity != null && tx.price != null) {
        // For average cost, we reduce both numerator and denominator proportionally
        if (totalShares > 0) {
          final avgCostPerShare = totalCost / totalShares;
          totalCost -= tx.quantity! * avgCostPerShare;
          totalShares -= tx.quantity!;
        }
      }
    }
    
    return totalShares > 0 ? totalCost / totalShares : 0;
  }

  /// Calculate realized gains using FIFO (First In, First Out) method.
  static double calculateRealizedGainsFIFO(List<InvestmentTransaction> transactions) {
    final List<_Lot> lots = [];
    double realizedGains = 0;
    
    // Sort transactions by date
    final sortedTransactions = List<InvestmentTransaction>.from(transactions)
      ..sort((a, b) => a.transactionDate.compareTo(b.transactionDate));
    
    for (final tx in sortedTransactions) {
      if (tx.transactionType == InvestmentTransactionType.buy && 
          tx.quantity != null && tx.price != null) {
        // Add to lots
        lots.add(_Lot(
          quantity: tx.quantity!,
          costPerShare: tx.price! + (tx.fee / tx.quantity!),
        ));
      } else if (tx.transactionType == InvestmentTransactionType.sell &&
          tx.quantity != null && tx.price != null) {
        var remainingToSell = tx.quantity!;
        final salePricePerShare = tx.price! - (tx.fee / tx.quantity!);
        
        // Sell from oldest lots first (FIFO)
        while (remainingToSell > 0 && lots.isNotEmpty) {
          final lot = lots.first;
          final sellFromLot = lot.quantity < remainingToSell ? lot.quantity : remainingToSell;
          
          realizedGains += sellFromLot * (salePricePerShare - lot.costPerShare);
          
          lot.quantity -= sellFromLot;
          remainingToSell -= sellFromLot;
          
          if (lot.quantity <= 0) {
            lots.removeAt(0);
          }
        }
      }
    }
    
    return realizedGains;
  }

  /// Calculate total dividends received.
  static double calculateTotalDividends(List<InvestmentTransaction> transactions) {
    return transactions
        .where((t) => t.transactionType == InvestmentTransactionType.dividend)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Calculate total return (realized + unrealized + dividends).
  static double calculateTotalReturn({
    required double costBasis,
    required double marketValue,
    required double realizedGains,
    required double dividendsReceived,
  }) {
    final unrealizedGain = marketValue - costBasis;
    return unrealizedGain + realizedGains + dividendsReceived;
  }

  /// Calculate annualized return (CAGR - Compound Annual Growth Rate).
  static double calculateAnnualizedReturn({
    required double beginningValue,
    required double endingValue,
    required int daysHeld,
  }) {
    if (beginningValue <= 0 || daysHeld <= 0) return 0;
    
    final years = daysHeld / 365.0;
    if (years <= 0) return 0;
    
    return (pow(endingValue / beginningValue, 1 / years) - 1) * 100;
  }

  /// Calculate portfolio performance summary.
  static PortfolioPerformance calculatePortfolioPerformance(
    List<HoldingWithMetrics> holdings, {
    double totalDividends = 0,
    double totalRealizedGains = 0,
  }) {
    double totalCostBasis = 0;
    double totalMarketValue = 0;
    double totalUnrealizedGain = 0;
    
    for (final h in holdings) {
      totalCostBasis += h.costBasis;
      totalMarketValue += h.marketValue;
      totalUnrealizedGain += h.unrealizedGain;
    }
    
    final totalUnrealizedGainPercent = totalCostBasis > 0
        ? (totalUnrealizedGain / totalCostBasis) * 100
        : 0.0;
    
    final totalReturn = calculateTotalReturn(
      costBasis: totalCostBasis,
      marketValue: totalMarketValue,
      realizedGains: totalRealizedGains,
      dividendsReceived: totalDividends,
    );
    
    final totalROIPercent = InvestmentService.calculateROI(
      costBasis: totalCostBasis,
      currentValue: totalMarketValue,
      dividendsReceived: totalDividends,
      realizedGains: totalRealizedGains,
    );
    
    return PortfolioPerformance(
      totalCostBasis: totalCostBasis,
      totalMarketValue: totalMarketValue,
      totalUnrealizedGain: totalUnrealizedGain,
      totalUnrealizedGainPercent: totalUnrealizedGainPercent,
      totalDividends: totalDividends,
      totalRealizedGains: totalRealizedGains,
      totalReturn: totalReturn,
      totalROIPercent: totalROIPercent,
      holdingCount: holdings.length,
    );
  }
}

/// Helper class for FIFO lot tracking.
class _Lot {
  double quantity;
  final double costPerShare;
  
  _Lot({required this.quantity, required this.costPerShare});
}

/// Model for holding with calculated metrics.
class HoldingWithMetrics {
  final String symbol;
  final String? securityName;
  final double quantity;
  final double averageCost;
  final double currentPrice;
  final double costBasis;
  final double marketValue;
  final double unrealizedGain;
  final double unrealizedGainPercent;

  HoldingWithMetrics({
    required this.symbol,
    this.securityName,
    required this.quantity,
    required this.averageCost,
    required this.currentPrice,
    required this.costBasis,
    required this.marketValue,
    required this.unrealizedGain,
    required this.unrealizedGainPercent,
  });
}

/// Model for portfolio-level performance.
class PortfolioPerformance {
  final double totalCostBasis;
  final double totalMarketValue;
  final double totalUnrealizedGain;
  final double totalUnrealizedGainPercent;
  final double totalDividends;
  final double totalRealizedGains;
  final double totalReturn;
  final double totalROIPercent;
  final int holdingCount;

  PortfolioPerformance({
    required this.totalCostBasis,
    required this.totalMarketValue,
    required this.totalUnrealizedGain,
    required this.totalUnrealizedGainPercent,
    required this.totalDividends,
    required this.totalRealizedGains,
    required this.totalReturn,
    required this.totalROIPercent,
    required this.holdingCount,
  });
}

/// Helper function for power calculation.
double pow(double base, double exponent) {
  if (base <= 0) return 0;
  return base.toDouble().pow(exponent);
}

/// Extension for double power calculation.
extension DoublePow on double {
  double pow(double exponent) {
    return _pow(this, exponent);
  }
}

double _pow(double base, double exponent) {
  // Simple implementation for non-negative exponents
  if (exponent == 0) return 1;
  if (exponent == 1) return base;
  
  // For fractional exponents, use natural log approximation
  // ln(base^exp) = exp * ln(base)
  // base^exp = e^(exp * ln(base))
  final lnBase = _naturalLog(base);
  final result = _exp(exponent * lnBase);
  return result;
}

/// Natural logarithm approximation (Newton-Raphson method).
double _naturalLog(double x) {
  if (x <= 0) return double.nan;
  
  // Simple approximation for log
  double result = 0;
  double term = (x - 1) / (x + 1);
  double termSquared = term * term;
  
  for (int i = 1; i < 20; i += 2) {
    result += term / i;
    term *= termSquared;
  }
  
  return 2 * result;
}

/// Exponential function approximation (Taylor series).
double _exp(double x) {
  double result = 1;
  double term = 1;
  
  for (int i = 1; i < 20; i++) {
    term *= x / i;
    result += term;
  }
  
  return result;
}
