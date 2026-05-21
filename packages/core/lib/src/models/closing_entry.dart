import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Closing entry type enumeration for the four-step closing process.
///
/// The closing process follows standard accounting procedures:
/// 1. Close revenue accounts to Income Summary
/// 2. Close expense accounts to Income Summary
/// 3. Close Income Summary to Retained Earnings
/// 4. Close dividend accounts to Retained Earnings
enum ClosingType {
  /// Close revenue accounts (Step 1)
  closeRevenue('CLOSE_REVENUE', '收入结转', 1),
  
  /// Close expense accounts (Step 2)
  closeExpense('CLOSE_EXPENSE', '费用结转', 2),
  
  /// Close Income Summary to Retained Earnings (Step 3)
  closeIncomeSummary('CLOSE_INCOME_SUMMARY', '损益汇总结转', 3),
  
  /// Close dividend accounts to Retained Earnings (Step 4)
  closeDividends('CLOSE_DIVIDENDS', '股利结转', 4);

  final String code;
  final String labelZh;
  final int step;

  const ClosingType(this.code, this.labelZh, this.step);
}

/// Closing entry status enumeration.
enum ClosingStatus {
  /// Entry is pending execution
  pending('PENDING', '待执行'),
  
  /// Entry has been executed successfully
  executed('EXECUTED', '已执行'),
  
  /// Entry execution failed
  failed('FAILED', '执行失败'),
  
  /// Entry has been reversed
  reversed('REVERSED', '已冲销');

  final String code;
  final String labelZh;

  const ClosingStatus(this.code, this.labelZh);
}

/// Closing entry model representing a closing entry in the accounting cycle.
///
/// Closing entries are made at the end of an accounting period to transfer
/// temporary account balances (revenues, expenses, dividends) to permanent
/// accounts (Retained Earnings).
///
/// Uses integer amounts (num/denom) for precise calculations without
/// floating point precision issues.
class ClosingEntry extends Equatable {
  final String id;
  final String fiscalPeriodId;
  final ClosingType closingType;
  final ClosingStatus status;
  final String sourceAccountId;
  final String targetAccountId;
  final int amountNum;
  final int amountDenom;
  final String? description;
  final String? transactionId;
  final DateTime executedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  ClosingEntry({
    String? id,
    required this.fiscalPeriodId,
    required this.closingType,
    this.status = ClosingStatus.pending,
    required this.sourceAccountId,
    required this.targetAccountId,
    required this.amountNum,
    this.amountDenom = 1,
    this.description,
    this.transactionId,
    DateTime? executedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.version = 1,
  })  : id = id ?? const Uuid().v4(),
        executedAt = executedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Returns the amount as a decimal number.
  double get amount => amountNum / amountDenom;

  /// Returns true if this entry has been executed.
  bool get isExecuted => status == ClosingStatus.executed;

  /// Returns true if this entry is pending.
  bool get isPending => status == ClosingStatus.pending;

  /// Creates a copy of this closing entry with the given fields replaced.
  ClosingEntry copyWith({
    String? id,
    String? fiscalPeriodId,
    ClosingType? closingType,
    ClosingStatus? status,
    String? sourceAccountId,
    String? targetAccountId,
    int? amountNum,
    int? amountDenom,
    String? description,
    String? transactionId,
    DateTime? executedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  }) {
    return ClosingEntry(
      id: id ?? this.id,
      fiscalPeriodId: fiscalPeriodId ?? this.fiscalPeriodId,
      closingType: closingType ?? this.closingType,
      status: status ?? this.status,
      sourceAccountId: sourceAccountId ?? this.sourceAccountId,
      targetAccountId: targetAccountId ?? this.targetAccountId,
      amountNum: amountNum ?? this.amountNum,
      amountDenom: amountDenom ?? this.amountDenom,
      description: description ?? this.description,
      transactionId: transactionId ?? this.transactionId,
      executedAt: executedAt ?? this.executedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }

  /// Converts this closing entry to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fiscal_period_id': fiscalPeriodId,
      'closing_type': closingType.code,
      'status': status.code,
      'source_account_id': sourceAccountId,
      'target_account_id': targetAccountId,
      'amount_num': amountNum,
      'amount_denom': amountDenom,
      'description': description,
      'transaction_id': transactionId,
      'executed_at': executedAt.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'version': version,
    };
  }

  /// Creates a closing entry from a JSON map.
  factory ClosingEntry.fromJson(Map<String, dynamic> json) {
    return ClosingEntry(
      id: json['id'] as String,
      fiscalPeriodId: json['fiscal_period_id'] as String,
      closingType: ClosingType.values.firstWhere(
        (e) => e.code == json['closing_type'],
        orElse: () => ClosingType.closeRevenue,
      ),
      status: ClosingStatus.values.firstWhere(
        (e) => e.code == json['status'],
        orElse: () => ClosingStatus.pending,
      ),
      sourceAccountId: json['source_account_id'] as String,
      targetAccountId: json['target_account_id'] as String,
      amountNum: json['amount_num'] as int,
      amountDenom: json['amount_denom'] as int? ?? 1,
      description: json['description'] as String?,
      transactionId: json['transaction_id'] as String?,
      executedAt: DateTime.fromMillisecondsSinceEpoch(json['executed_at'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
      version: json['version'] as int? ?? 1,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fiscalPeriodId,
        closingType,
        status,
        sourceAccountId,
        targetAccountId,
        amountNum,
        amountDenom,
        description,
        transactionId,
        executedAt,
        createdAt,
        updatedAt,
        version,
      ];
}