import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Investment transaction model for buy/sell/dividend operations.
class InvestmentTransaction extends Equatable {
  final String id;
  final String accountId;
  final String? holdingId;
  final InvestmentTransactionType transactionType;
  final DateTime transactionDate;
  final String symbol;
  final String? securityName;
  final double? quantity;
  final double? price;
  final double amount;
  final double fee;
  final double tax;
  final String currencyId;
  final String? notes;
  final String? referenceNum;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  InvestmentTransaction({
    String? id,
    required this.accountId,
    this.holdingId,
    required this.transactionType,
    required this.transactionDate,
    required this.symbol,
    this.securityName,
    this.quantity,
    this.price,
    required this.amount,
    this.fee = 0,
    this.tax = 0,
    required this.currencyId,
    this.notes,
    this.referenceNum,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.version = 1,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Total cost including fees and taxes (for buy transactions).
  double get totalCost => amount + fee + tax;

  /// Net proceeds after fees and taxes (for sell transactions).
  double get netProceeds => amount - fee - tax;

  /// Creates a copy with updated fields.
  InvestmentTransaction copyWith({
    String? id,
    String? accountId,
    String? holdingId,
    InvestmentTransactionType? transactionType,
    DateTime? transactionDate,
    String? symbol,
    String? securityName,
    double? quantity,
    double? price,
    double? amount,
    double? fee,
    double? tax,
    String? currencyId,
    String? notes,
    String? referenceNum,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  }) {
    return InvestmentTransaction(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      holdingId: holdingId ?? this.holdingId,
      transactionType: transactionType ?? this.transactionType,
      transactionDate: transactionDate ?? this.transactionDate,
      symbol: symbol ?? this.symbol,
      securityName: securityName ?? this.securityName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      amount: amount ?? this.amount,
      fee: fee ?? this.fee,
      tax: tax ?? this.tax,
      currencyId: currencyId ?? this.currencyId,
      notes: notes ?? this.notes,
      referenceNum: referenceNum ?? this.referenceNum,
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
      'holding_id': holdingId,
      'transaction_type': transactionType.code,
      'transaction_date': transactionDate.millisecondsSinceEpoch,
      'symbol': symbol,
      'security_name': securityName,
      'quantity': quantity,
      'price': price,
      'amount': amount,
      'fee': fee,
      'tax': tax,
      'currency_id': currencyId,
      'notes': notes,
      'reference_num': referenceNum,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'version': version,
    };
  }

  /// Creates from JSON.
  factory InvestmentTransaction.fromJson(Map<String, dynamic> json) {
    return InvestmentTransaction(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      holdingId: json['holding_id'] as String?,
      transactionType: InvestmentTransactionType.values.firstWhere(
        (e) => e.code == json['transaction_type'],
        orElse: () => InvestmentTransactionType.other,
      ),
      transactionDate: DateTime.fromMillisecondsSinceEpoch(
        json['transaction_date'] as int,
      ),
      symbol: json['symbol'] as String,
      securityName: json['security_name'] as String?,
      quantity: json['quantity'] != null
          ? (json['quantity'] as num).toDouble()
          : null,
      price:
          json['price'] != null ? (json['price'] as num).toDouble() : null,
      amount: (json['amount'] as num).toDouble(),
      fee: json['fee'] != null ? (json['fee'] as num).toDouble() : 0,
      tax: json['tax'] != null ? (json['tax'] as num).toDouble() : 0,
      currencyId: json['currency_id'] as String,
      notes: json['notes'] as String?,
      referenceNum: json['reference_num'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
      version: json['version'] as int? ?? 1,
    );
  }

  @override
  List<Object?> get props => [
        id,
        accountId,
        holdingId,
        transactionType,
        transactionDate,
        symbol,
        securityName,
        quantity,
        price,
        amount,
        fee,
        tax,
        currencyId,
        notes,
        referenceNum,
        createdAt,
        updatedAt,
        version,
      ];
}

/// Investment transaction type enum.
enum InvestmentTransactionType {
  buy('buy', '买入'),
  sell('sell', '卖出'),
  dividend('dividend', '股息'),
  dividendReinvest('dividend_reinvest', '股息再投资'),
  split('split', '拆股'),
  transferIn('transfer_in', '转入'),
  transferOut('transfer_out', '转出'),
  fee('fee', '费用'),
  other('other', '其他');

  final String code;
  final String labelZh;

  const InvestmentTransactionType(this.code, this.labelZh);
}
