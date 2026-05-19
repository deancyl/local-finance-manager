import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Import batch status enumeration.
enum ImportBatchStatus {
  success('SUCCESS', '成功'),
  partial('PARTIAL', '部分成功'),
  failed('FAILED', '失败');

  final String code;
  final String labelZh;

  const ImportBatchStatus(this.code, this.labelZh);
}

/// Import batch model representing a single import operation.
class ImportBatch extends Equatable {
  final String id;
  final String sourceId;
  final DateTime importedAt;
  final String? filename;
  final int recordCount;
  final int successCount;
  final int duplicateCount;
  final int errorCount;
  final ImportBatchStatus status;
  final String? errorDetails;
  final DateTime createdAt;

  ImportBatch({
    String? id,
    required this.sourceId,
    DateTime? importedAt,
    this.filename,
    this.recordCount = 0,
    this.successCount = 0,
    this.duplicateCount = 0,
    this.errorCount = 0,
    this.status = ImportBatchStatus.success,
    this.errorDetails,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        importedAt = importedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  /// Returns true if all records were imported successfully.
  bool get isComplete => successCount == recordCount && errorCount == 0;

  /// Returns the success rate as a percentage.
  double get successRate =>
      recordCount > 0 ? (successCount / recordCount) * 100 : 0;

  ImportBatch copyWith({
    String? id,
    String? sourceId,
    DateTime? importedAt,
    String? filename,
    int? recordCount,
    int? successCount,
    int? duplicateCount,
    int? errorCount,
    ImportBatchStatus? status,
    String? errorDetails,
    DateTime? createdAt,
  }) {
    return ImportBatch(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      importedAt: importedAt ?? this.importedAt,
      filename: filename ?? this.filename,
      recordCount: recordCount ?? this.recordCount,
      successCount: successCount ?? this.successCount,
      duplicateCount: duplicateCount ?? this.duplicateCount,
      errorCount: errorCount ?? this.errorCount,
      status: status ?? this.status,
      errorDetails: errorDetails ?? this.errorDetails,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_id': sourceId,
      'imported_at': importedAt.millisecondsSinceEpoch,
      'filename': filename,
      'record_count': recordCount,
      'success_count': successCount,
      'duplicate_count': duplicateCount,
      'error_count': errorCount,
      'status': status.code,
      'error_details': errorDetails,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory ImportBatch.fromJson(Map<String, dynamic> json) {
    return ImportBatch(
      id: json['id'] as String,
      sourceId: json['source_id'] as String,
      importedAt: DateTime.fromMillisecondsSinceEpoch(json['imported_at'] as int),
      filename: json['filename'] as String?,
      recordCount: json['record_count'] as int? ?? 0,
      successCount: json['success_count'] as int? ?? 0,
      duplicateCount: json['duplicate_count'] as int? ?? 0,
      errorCount: json['error_count'] as int? ?? 0,
      status: ImportBatchStatus.values.firstWhere(
        (e) => e.code == json['status'],
        orElse: () => ImportBatchStatus.success,
      ),
      errorDetails: json['error_details'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
    );
  }

  @override
  List<Object?> get props => [
        id,
        sourceId,
        importedAt,
        filename,
        recordCount,
        successCount,
        duplicateCount,
        errorCount,
        status,
        errorDetails,
        createdAt,
      ];
}