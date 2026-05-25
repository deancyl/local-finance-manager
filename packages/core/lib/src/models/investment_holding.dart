import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Investment holding model representing a position in a security.
class InvestmentHolding extends Equatable {
  final String id;
  final String accountId;
  final String symbol;
  final String? securityName;
  final SecurityType securityType;
  final String currencyId;
  final double quantity;
  final double averageCost;
  final double? currentPrice;
  final DateTime? lastPriceUpdate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  InvestmentHolding({
    String? id,
    required this.accountId,
    required this.symbol,
    this.securityName,
    this.securityType = SecurityType.stock,
    required this.currencyId,
    required this.quantity,
    required this.averageCost,
    this.currentPrice,
    this.lastPriceUpdate,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.version = 1,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Cost basis = quantity * average cost
  double get costBasis => quantity * averageCost;

  /// Market value = quantity * current price (or cost basis if no current price)
  double get marketValue => quantity * (currentPrice ?? averageCost);

  /// Unrealized gain/loss = market value - cost basis
  double get unrealizedGain => marketValue - costBasis;

  /// Unrealized gain/loss percentage
  double get unrealizedGainPercent =>
      costBasis > 0 ? (unrealizedGain / costBasis) * 100 : 0;

  /// ROI (same as unrealized gain percent)
  double get roi => unrealizedGainPercent;

  /// Creates a copy with updated fields.
  InvestmentHolding copyWith({
    String? id,
    String? accountId,
    String? symbol,
    String? securityName,
    SecurityType? securityType,
    String? currencyId,
    double? quantity,
    double? averageCost,
    double? currentPrice,
    DateTime? lastPriceUpdate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  }) {
    return InvestmentHolding(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      symbol: symbol ?? this.symbol,
      securityName: securityName ?? this.securityName,
      securityType: securityType ?? this.securityType,
      currencyId: currencyId ?? this.currencyId,
      quantity: quantity ?? this.quantity,
      averageCost: averageCost ?? this.averageCost,
      currentPrice: currentPrice ?? this.currentPrice,
      lastPriceUpdate: lastPriceUpdate ?? this.lastPriceUpdate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'symbol': symbol,
      'security_name': securityName,
      'security_type': securityType.code,
      'currency_id': currencyId,
      'quantity': quantity,
      'average_cost': averageCost,
      'current_price': currentPrice,
      'last_price_update': lastPriceUpdate?.millisecondsSinceEpoch,
      'notes': notes,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'version': version,
    };
  }

  /// Creates from JSON.
  factory InvestmentHolding.fromJson(Map<String, dynamic> json) {
    return InvestmentHolding(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      symbol: json['symbol'] as String,
      securityName: json['security_name'] as String?,
      securityType: SecurityType.values.firstWhere(
        (e) => e.code == json['security_type'],
        orElse: () => SecurityType.stock,
      ),
      currencyId: json['currency_id'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      averageCost: (json['average_cost'] as num).toDouble(),
      currentPrice: json['current_price'] != null
          ? (json['current_price'] as num).toDouble()
          : null,
      lastPriceUpdate: json['last_price_update'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['last_price_update'] as int)
          : null,
      notes: json['notes'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
      version: json['version'] as int? ?? 1,
    );
  }

  @override
  List<Object?> get props => [
        id,
        accountId,
        symbol,
        securityName,
        securityType,
        currencyId,
        quantity,
        averageCost,
        currentPrice,
        lastPriceUpdate,
        notes,
        createdAt,
        updatedAt,
        version,
      ];
}

/// Security type enum.
enum SecurityType {
  stock('stock', '股票'),
  fund('fund', '基金'),
  bond('bond', '债券'),
  etf('etf', 'ETF'),
  other('other', '其他');

  final String code;
  final String labelZh;

  const SecurityType(this.code, this.labelZh);
}
