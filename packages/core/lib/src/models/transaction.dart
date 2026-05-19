import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Transaction model representing a financial transaction.
///
/// Supports both single-entry and double-entry modes.
/// In single-entry mode, [splits] will contain one entry.
/// In double-entry mode, [splits] must contain at least two entries
/// that balance (sum of debits = sum of credits).
class Transaction extends Equatable {
  final String id;
  final String? description;
  final DateTime postDate;
  final DateTime enterDate;
  final String commodityId;
  final String? referenceNumber;
  final String? notes;
  final String? importBatchId;
  final String? externalId;
  final bool isDoubleEntry;
  final String? idempotencyKey;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Transaction({
    String? id,
    this.description,
    required this.postDate,
    DateTime? enterDate,
    required this.commodityId,
    this.referenceNumber,
    this.notes,
    this.importBatchId,
    this.externalId,
    this.isDoubleEntry = false,
    this.idempotencyKey,
    this.version = 1,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
  })  : id = id ?? const Uuid().v4(),
        enterDate = enterDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Transaction copyWith({
    String? id,
    String? description,
    DateTime? postDate,
    DateTime? enterDate,
    String? commodityId,
    String? referenceNumber,
    String? notes,
    String? importBatchId,
    String? externalId,
    bool? isDoubleEntry,
    String? idempotencyKey,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      description: description ?? this.description,
      postDate: postDate ?? this.postDate,
      enterDate: enterDate ?? this.enterDate,
      commodityId: commodityId ?? this.commodityId,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      notes: notes ?? this.notes,
      importBatchId: importBatchId ?? this.importBatchId,
      externalId: externalId ?? this.externalId,
      isDoubleEntry: isDoubleEntry ?? this.isDoubleEntry,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'post_date': postDate.millisecondsSinceEpoch,
      'enter_date': enterDate.millisecondsSinceEpoch,
      'currency_id': commodityId,
      'reference_num': referenceNumber,
      'notes': notes,
      'import_batch_id': importBatchId,
      'external_id': externalId,
      'is_double_entry': isDoubleEntry ? 1 : 0,
      'idempotency_key': idempotencyKey,
      'version': version,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      description: json['description'] as String?,
      postDate: DateTime.fromMillisecondsSinceEpoch(json['post_date'] as int),
      enterDate: DateTime.fromMillisecondsSinceEpoch(json['enter_date'] as int),
      commodityId: json['currency_id'] as String,
      referenceNumber: json['reference_num'] as String?,
      notes: json['notes'] as String?,
      importBatchId: json['import_batch_id'] as String?,
      externalId: json['external_id'] as String?,
      isDoubleEntry: json['is_double_entry'] == 1,
      idempotencyKey: json['idempotency_key'] as String?,
      version: json['version'] as int? ?? 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
      deletedAt: json['deleted_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['deleted_at'] as int)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        description,
        postDate,
        enterDate,
        commodityId,
        referenceNumber,
        notes,
        importBatchId,
        externalId,
        isDoubleEntry,
        idempotencyKey,
        version,
        createdAt,
        updatedAt,
        deletedAt,
      ];
}