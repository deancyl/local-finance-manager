import 'package:core/core.dart';

/// Result of parsing an import file.
class ImportResult {
  /// Successfully parsed transactions.
  final List<ParsedTransaction> transactions;

  /// Rows that failed to parse with error messages.
  final List<ParseError> errors;

  /// Warnings (non-fatal issues).
  final List<String> warnings;

  /// Statistics about the parse operation.
  final ImportStats stats;

  /// Detected encoding of the file.
  final String detectedEncoding;

  /// Detected source type (if auto-detected).
  final String? detectedSource;

  const ImportResult({
    required this.transactions,
    this.errors = const [],
    this.warnings = const [],
    required this.stats,
    required this.detectedEncoding,
    this.detectedSource,
  });

  /// Returns true if there are no errors.
  bool get isSuccess => errors.isEmpty;

  /// Returns true if there are some successes and some errors.
  bool get isPartial => transactions.isNotEmpty && errors.isNotEmpty;

  /// Returns true if all rows failed.
  bool get isFailed => transactions.isEmpty && errors.isNotEmpty;

  /// Returns the success rate as a percentage.
  double get successRate {
    final total = stats.totalRows;
    if (total == 0) return 0;
    return (transactions.length / total) * 100;
  }

  ImportResult copyWith({
    List<ParsedTransaction>? transactions,
    List<ParseError>? errors,
    List<String>? warnings,
    ImportStats? stats,
    String? detectedEncoding,
    String? detectedSource,
  }) {
    return ImportResult(
      transactions: transactions ?? this.transactions,
      errors: errors ?? this.errors,
      warnings: warnings ?? this.warnings,
      stats: stats ?? this.stats,
      detectedEncoding: detectedEncoding ?? this.detectedEncoding,
      detectedSource: detectedSource ?? this.detectedSource,
    );
  }
}

/// Parse error for a specific row.
class ParseError {
  /// Row number (1-indexed).
  final int rowNumber;

  /// Error message.
  final String message;

  /// Original row data (for debugging).
  final Map<String, dynamic>? rowData;

  /// Error type.
  final ParseErrorType type;

  const ParseError({
    required this.rowNumber,
    required this.message,
    this.rowData,
    this.type = ParseErrorType.parse,
  });

  @override
  String toString() => 'Row $rowNumber: $message';
}

/// Types of parse errors.
enum ParseErrorType {
  /// General parse error.
  parse,

  /// Missing required field.
  missingField,

  /// Invalid date format.
  invalidDate,

  /// Invalid amount format.
  invalidAmount,

  /// Duplicate transaction.
  duplicate,

  /// Encoding error.
  encoding,

  /// Format error (unexpected format).
  format,
}

/// Statistics about the import operation.
class ImportStats {
  /// Total rows in file (excluding header).
  final int totalRows;

  /// Successfully parsed rows.
  final int successCount;

  /// Rows with errors.
  final int errorCount;

  /// Rows skipped (e.g., empty rows, headers).
  final int skippedCount;

  /// Duplicate transactions detected.
  final int duplicateCount;

  /// Date range of transactions.
  final DateTime? firstDate;

  /// Date range of transactions.
  final DateTime? lastDate;

  /// Total amount (sum of all transactions).
  final double totalAmount;

  /// Currency detected.
  final String? detectedCurrency;

  const ImportStats({
    required this.totalRows,
    this.successCount = 0,
    this.errorCount = 0,
    this.skippedCount = 0,
    this.duplicateCount = 0,
    this.firstDate,
    this.lastDate,
    this.totalAmount = 0,
    this.detectedCurrency,
  });

  ImportStats copyWith({
    int? totalRows,
    int? successCount,
    int? errorCount,
    int? skippedCount,
    int? duplicateCount,
    DateTime? firstDate,
    DateTime? lastDate,
    double? totalAmount,
    String? detectedCurrency,
  }) {
    return ImportStats(
      totalRows: totalRows ?? this.totalRows,
      successCount: successCount ?? this.successCount,
      errorCount: errorCount ?? this.errorCount,
      skippedCount: skippedCount ?? this.skippedCount,
      duplicateCount: duplicateCount ?? this.duplicateCount,
      firstDate: firstDate ?? this.firstDate,
      lastDate: lastDate ?? this.lastDate,
      totalAmount: totalAmount ?? this.totalAmount,
      detectedCurrency: detectedCurrency ?? this.detectedCurrency,
    );
  }
}