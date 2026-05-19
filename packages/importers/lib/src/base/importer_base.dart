import 'dart:typed_data';
import '../import_result.dart';
import '../import_config.dart';
import 'package:core/core.dart';

/// Base class for all financial institution importers.
///
/// Each importer must implement:
/// 1. `canParse()` - Check if file format is supported
/// 2. `parse()` - Parse file and return ParsedTransaction list
/// 3. `getSourceType()` - Return the ImportSourceType
abstract class ImporterBase {
  /// The name of this importer (e.g., "Alipay", "WeChat Pay").
  String get name;

  /// The unique identifier for this importer.
  String get sourceId;

  /// Supported file extensions (e.g., ['.csv', '.xls']).
  List<String> get supportedExtensions;

  /// The import source type.
  ImportSourceType get sourceType;

  /// Human-readable description of this importer.
  String get description;

  /// Check if the given file content can be parsed by this importer.
  ///
  /// This method should perform a quick validation:
  /// - Check file extension
  /// - Check header format
  /// - Check encoding
  ///
  /// Returns true if this importer can handle the file.
  bool canParse({
    required String filename,
    required Uint8List content,
    String? encoding,
  });

  /// Parse the file content and return parsed transactions.
  ///
  /// Parameters:
  /// - `content`: Raw file bytes
  /// - `config`: Import configuration (account mapping, etc.)
  /// - `encoding`: Optional encoding hint (e.g., 'utf-8', 'gbk')
  ///
  /// Returns an ImportResult with:
  /// - List of ParsedTransaction
  /// - Validation errors
  /// - Parse warnings
  /// - Statistics
  Future<ImportResult> parse({
    required Uint8List content,
    required ImportConfig config,
    String? encoding,
  });

  /// Get a preview of the file content before full import.
  ///
  /// Returns the first N rows for user verification.
  Future<ImportPreview> preview({
    required Uint8List content,
    int maxRows = 10,
    String? encoding,
  });

  /// Validate the import configuration for this importer.
  ///
  /// Returns a list of validation errors, or empty if valid.
  List<String> validateConfig(ImportConfig config);

  /// Get default category mappings for this importer.
  ///
  /// Each importer has predefined category mappings based on
  /// the source's transaction types.
  Map<String, String> getDefaultCategoryMappings();
}

/// Import preview data for user verification.
class ImportPreview {
  /// Preview rows (first N rows from file).
  final List<Map<String, dynamic>> rows;

  /// Detected column headers.
  final List<String> headers;

  /// Detected encoding.
  final String detectedEncoding;

  /// Total row count in file.
  final int totalRowCount;

  /// Detected source type (if identifiable from header).
  final String? detectedSource;

  /// Warnings detected during preview.
  final List<String> warnings;

  const ImportPreview({
    required this.rows,
    required this.headers,
    required this.detectedEncoding,
    required this.totalRowCount,
    this.detectedSource,
    this.warnings = const [],
  });

  /// Returns true if preview has data.
  bool get hasData => rows.isNotEmpty;

  /// Returns true if source was detected.
  bool get sourceDetected => detectedSource != null;
}