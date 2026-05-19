import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Commodity namespace enumeration.
enum CommodityNamespace {
  currency('CURRENCY', '货币'),
  crypto('CRYPTO', '加密货币'),
  stock('STOCK', '股票'),
  fund('FUND', '基金');

  final String code;
  final String labelZh;

  const CommodityNamespace(this.code, this.labelZh);
}

/// Commodity model representing currencies, stocks, crypto, etc.
class Commodity extends Equatable {
  final String id;
  final CommodityNamespace namespace;
  final String mnemonic;
  final String? fullName;
  final int fraction;
  final DateTime createdAt;
  final DateTime updatedAt;

  Commodity({
    String? id,
    required this.namespace,
    required this.mnemonic,
    this.fullName,
    this.fraction = 100,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Creates CNY (Chinese Yuan) commodity.
  factory Commodity.cny() => Commodity(
        namespace: CommodityNamespace.currency,
        mnemonic: 'CNY',
        fullName: 'Chinese Yuan',
      );

  /// Creates USD (US Dollar) commodity.
  factory Commodity.usd() => Commodity(
        namespace: CommodityNamespace.currency,
        mnemonic: 'USD',
        fullName: 'US Dollar',
      );

  Commodity copyWith({
    String? id,
    CommodityNamespace? namespace,
    String? mnemonic,
    String? fullName,
    int? fraction,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Commodity(
      id: id ?? this.id,
      namespace: namespace ?? this.namespace,
      mnemonic: mnemonic ?? this.mnemonic,
      fullName: fullName ?? this.fullName,
      fraction: fraction ?? this.fraction,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'namespace': namespace.code,
      'mnemonic': mnemonic,
      'fullname': fullName,
      'fraction': fraction,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Commodity.fromJson(Map<String, dynamic> json) {
    return Commodity(
      id: json['id'] as String,
      namespace: CommodityNamespace.values.firstWhere(
        (e) => e.code == json['namespace'],
        orElse: () => CommodityNamespace.currency,
      ),
      mnemonic: json['mnemonic'] as String,
      fullName: json['fullname'] as String?,
      fraction: json['fraction'] as int? ?? 100,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
    );
  }

  @override
  List<Object?> get props => [id, namespace, mnemonic, fullName, fraction, createdAt, updatedAt];
}
