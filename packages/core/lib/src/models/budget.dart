import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Budget period enumeration.
enum BudgetPeriod {
  monthly('MONTHLY', '每月'),
  yearly('YEARLY', '每年'),
  custom('CUSTOM', '自定义');

  final String code;
  final String labelZh;

  const BudgetPeriod(this.code, this.labelZh);
}

/// Budget model for tracking spending limits.
class Budget extends Equatable {
  final String id;
  final String name;
  final String? categoryId;
  final int amountNum;
  final int amountDenom;
  final String commodityId;
  final BudgetPeriod period;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime createdAt;

  Budget({
    String? id,
    required this.name,
    this.categoryId,
    required this.amountNum,
    this.amountDenom = 1,
    required this.commodityId,
    required this.period,
    required this.startDate,
    this.endDate,
    this.isActive = true,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Returns the budget amount as a decimal number.
  double get amount => amountNum / amountDenom;

  /// Creates a budget with a given decimal amount.
  factory Budget.fromAmount({
    String? id,
    required String name,
    String? categoryId,
    required double amount,
    required String commodityId,
    required BudgetPeriod period,
    required DateTime startDate,
    DateTime? endDate,
    bool isActive = true,
    DateTime? createdAt,
    int fraction = 100,
  }) {
    return Budget(
      id: id,
      name: name,
      categoryId: categoryId,
      amountNum: (amount * fraction).round(),
      amountDenom: fraction,
      commodityId: commodityId,
      period: period,
      startDate: startDate,
      endDate: endDate,
      isActive: isActive,
      createdAt: createdAt,
    );
  }

  Budget copyWith({
    String? id,
    String? name,
    String? categoryId,
    int? amountNum,
    int? amountDenom,
    String? commodityId,
    BudgetPeriod? period,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Budget(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      amountNum: amountNum ?? this.amountNum,
      amountDenom: amountDenom ?? this.amountDenom,
      commodityId: commodityId ?? this.commodityId,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'amount_num': amountNum,
      'amount_denom': amountDenom,
      'currency_id': commodityId,
      'period': period.code,
      'start_date': startDate.millisecondsSinceEpoch,
      'end_date': endDate?.millisecondsSinceEpoch,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as String,
      name: json['name'] as String,
      categoryId: json['category_id'] as String?,
      amountNum: json['amount_num'] as int,
      amountDenom: json['amount_denom'] as int? ?? 1,
      commodityId: json['currency_id'] as String,
      period: BudgetPeriod.values.firstWhere(
        (e) => e.code == json['period'],
        orElse: () => BudgetPeriod.monthly,
      ),
      startDate: DateTime.fromMillisecondsSinceEpoch(json['start_date'] as int),
      endDate: json['end_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['end_date'] as int)
          : null,
      isActive: json['is_active'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        categoryId,
        amountNum,
        amountDenom,
        commodityId,
        period,
        startDate,
        endDate,
        isActive,
        createdAt,
      ];
}