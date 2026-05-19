import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Reconciliation state enumeration.
enum ReconcileState {
  none('n', '未对账'),
  cleared('c', '已清除'),
  reconciled('y', '已对账'),
  voided('v', '已作废');

  final String code;
  final String labelZh;

  const ReconcileState(this.code, this.labelZh);
}

/// Split model representing a single debit or credit entry within a transaction.
///
/// In double-entry accounting, each transaction consists of multiple splits
/// that must balance (sum of values = 0).
class Split extends Equatable {
  final String id;
  final String transactionId;
  final String accountId;
  final String? memo;
  final int valueNum;
  final int valueDenom;
  final int quantityNum;
  final int quantityDenom;
  final ReconcileState reconcileState;
  final DateTime? reconcileDate;
  final int version;
  final DateTime createdAt;

  Split({
    String? id,
    required this.transactionId,
    required this.accountId,
    this.memo,
    required this.valueNum,
    this.valueDenom = 1,
    required this.quantityNum,
    this.quantityDenom = 1,
    this.reconcileState = ReconcileState.none,
    this.reconcileDate,
    this.version = 1,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Returns the value as a decimal number.
  double get value => valueNum / valueDenom;

  /// Returns the quantity as a decimal number.
  double get quantity => quantityNum / quantityDenom;

  /// Returns true if this split represents a debit (negative value).
  bool get isDebit => valueNum < 0;

  /// Returns true if this split represents a credit (positive value).
  bool get isCredit => valueNum > 0;

  /// Creates a split with a given decimal value.
  factory Split.fromValue({
    String? id,
    required String transactionId,
    required String accountId,
    String? memo,
    required double value,
    double quantity = 0,
    ReconcileState reconcileState = ReconcileState.none,
    DateTime? reconcileDate,
    int version = 1,
    DateTime? createdAt,
    int fraction = 100,
  }) {
    return Split(
      id: id,
      transactionId: transactionId,
      accountId: accountId,
      memo: memo,
      valueNum: (value * fraction).round(),
      valueDenom: fraction,
      quantityNum: (quantity * fraction).round(),
      quantityDenom: fraction,
      reconcileState: reconcileState,
      reconcileDate: reconcileDate,
      version: version,
      createdAt: createdAt,
    );
  }

  Split copyWith({
    String? id,
    String? transactionId,
    String? accountId,
    String? memo,
    int? valueNum,
    int? valueDenom,
    int? quantityNum,
    int? quantityDenom,
    ReconcileState? reconcileState,
    DateTime? reconcileDate,
    int? version,
    DateTime? createdAt,
  }) {
    return Split(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      accountId: accountId ?? this.accountId,
      memo: memo ?? this.memo,
      valueNum: valueNum ?? this.valueNum,
      valueDenom: valueDenom ?? this.valueDenom,
      quantityNum: quantityNum ?? this.quantityNum,
      quantityDenom: quantityDenom ?? this.quantityDenom,
      reconcileState: reconcileState ?? this.reconcileState,
      reconcileDate: reconcileDate ?? this.reconcileDate,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'account_id': accountId,
      'memo': memo,
      'value_num': valueNum,
      'value_denom': valueDenom,
      'quantity_num': quantityNum,
      'quantity_denom': quantityDenom,
      'reconcile_state': reconcileState.code,
      'reconcile_date': reconcileDate?.millisecondsSinceEpoch,
      'version': version,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Split.fromJson(Map<String, dynamic> json) {
    return Split(
      id: json['id'] as String,
      transactionId: json['transaction_id'] as String,
      accountId: json['account_id'] as String,
      memo: json['memo'] as String?,
      valueNum: json['value_num'] as int,
      valueDenom: json['value_denom'] as int? ?? 1,
      quantityNum: json['quantity_num'] as int,
      quantityDenom: json['quantity_denom'] as int? ?? 1,
      reconcileState: ReconcileState.values.firstWhere(
        (e) => e.code == json['reconcile_state'],
        orElse: () => ReconcileState.none,
      ),
      reconcileDate: json['reconcile_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['reconcile_date'] as int)
          : null,
      version: json['version'] as int? ?? 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
    );
  }

  @override
  List<Object?> get props => [
        id,
        transactionId,
        accountId,
        memo,
        valueNum,
        valueDenom,
        quantityNum,
        quantityDenom,
        reconcileState,
        reconcileDate,
        version,
        createdAt,
      ];
}