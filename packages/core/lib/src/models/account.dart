import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Account type enumeration following standard accounting conventions.
enum AccountType {
  asset('ASSET', '资产'),
  liability('LIABILITY', '负债'),
  equity('EQUITY', '权益'),
  income('INCOME', '收入'),
  expense('EXPENSE', '支出'),
  investment('INVESTMENT', '投资');

  final String code;
  final String labelZh;

  const AccountType(this.code, this.labelZh);
}

/// Liquidity type enumeration for balance sheet grouping.
enum LiquidityType {
  current('current', '流动'),
  nonCurrent('non_current', '非流动');

  final String code;
  final String labelZh;

  const LiquidityType(this.code, this.labelZh);
}

/// Account model representing a financial account in the chart of accounts.
///
/// Supports hierarchical structure via [parentId] for organizing accounts
/// into groups (e.g., "Assets" -> "Bank Accounts" -> "ICBC Checking").
class Account extends Equatable {
  final String id;
  final String name;
  final AccountType accountType;
  final String? parentId;
  final String commodityId;
  final String? code;
  final String? description;
  final bool isPlaceholder;
  final bool isHidden;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final LiquidityType liquidityType;

  Account({
    String? id,
    required this.name,
    required this.accountType,
    this.parentId,
    required this.commodityId,
    this.code,
    this.description,
    this.isPlaceholder = false,
    this.isHidden = false,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.version = 1,
    this.liquidityType = LiquidityType.current,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Creates a copy of this account with the given fields replaced.
  Account copyWith({
    String? id,
    String? name,
    AccountType? accountType,
    String? parentId,
    String? commodityId,
    String? code,
    String? description,
    bool? isPlaceholder,
    bool? isHidden,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    LiquidityType? liquidityType,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      accountType: accountType ?? this.accountType,
      parentId: parentId ?? this.parentId,
      commodityId: commodityId ?? this.commodityId,
      code: code ?? this.code,
      description: description ?? this.description,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
      isHidden: isHidden ?? this.isHidden,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      liquidityType: liquidityType ?? this.liquidityType,
    );
  }

  /// Converts this account to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'account_type': accountType.code,
      'parent_id': parentId,
      'commodity_id': commodityId,
      'code': code,
      'description': description,
      'is_placeholder': isPlaceholder ? 1 : 0,
      'is_hidden': isHidden ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'version': version,
      'liquidity_type': liquidityType.code,
    };
  }

  /// Creates an account from a JSON map.
  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      name: json['name'] as String,
      accountType: AccountType.values.firstWhere(
        (e) => e.code == json['account_type'],
        orElse: () => AccountType.asset,
      ),
      parentId: json['parent_id'] as String?,
      commodityId: json['commodity_id'] as String,
      code: json['code'] as String?,
      description: json['description'] as String?,
      isPlaceholder: json['is_placeholder'] == 1,
      isHidden: json['is_hidden'] == 1,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
      version: json['version'] as int? ?? 1,
      liquidityType: LiquidityType.values.firstWhere(
        (e) => e.code == json['liquidity_type'],
        orElse: () => LiquidityType.current,
      ),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        accountType,
        parentId,
        commodityId,
        code,
        description,
        isPlaceholder,
        isHidden,
        sortOrder,
        createdAt,
        updatedAt,
        version,
        liquidityType,
      ];
}
