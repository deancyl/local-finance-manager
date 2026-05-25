import 'dart:typed_data';
import 'csv_parser.dart';

/// Unified file parser that supports CSV files.
///
/// Features:
/// - Auto-detects file type (CSV)
/// - Supports .csv format
/// - Provides consistent interface for all file types
/// - Handles encoding for CSV files
class FileParser {
  /// Parse file content and return list of rows.
  ///
  /// Parameters:
  /// - [filename]: File name (used to detect file type)
  /// - [content]: Raw file bytes
  /// - [encoding]: Optional encoding hint (for CSV files)
  /// - [delimiter]: Field delimiter (for CSV files, default: auto-detect)
  /// - [hasHeader]: Whether first row is header
  ///
  /// Returns:
  /// - FileParseResult with header, rows, and metadata
  static FileParseResult parse({
    required String filename,
    required Uint8List content,
    String? encoding,
    String? delimiter,
    bool hasHeader = true,
    int sheetIndex = 0, // Kept for API compatibility, ignored for CSV
  }) {
    final fileType = detectFileType(filename, content);

    switch (fileType) {
      case FileType.csv:
        final csvResult = CsvParser.parse(
          content: content,
          encoding: encoding,
          delimiter: delimiter,
          hasHeader: hasHeader,
        );

        return FileParseResult(
          header: csvResult.header,
          rows: csvResult.rows,
          fileType: fileType,
          detectedEncoding: csvResult.detectedEncoding,
          detectedDelimiter: csvResult.detectedDelimiter,
          totalRows: csvResult.totalRows,
        );

      case FileType.unknown:
        return FileParseResult(
          header: [],
          rows: [],
          fileType: fileType,
          detectedEncoding: encoding ?? 'utf-8',
          totalRows: 0,
          error: '不支持的文件类型: $filename (仅支持CSV)',
        );
    }
  }

  /// Parse file with field mapping.
  ///
  /// Returns list of maps with field names as keys.
  static List<Map<String, String>> parseWithMapping({
    required String filename,
    required Uint8List content,
    String? encoding,
    String? delimiter,
    bool hasHeader = true,
    int sheetIndex = 0,
    Map<String, String>? fieldMapping,
  }) {
    final result = parse(
      filename: filename,
      content: content,
      encoding: encoding,
      delimiter: delimiter,
      hasHeader: hasHeader,
      sheetIndex: sheetIndex,
    );

    if (result.error != null || result.header.isEmpty) {
      return result.rows.map((row) {
        final map = <String, String>{};
        for (var i = 0; i < row.length; i++) {
          map['column_$i'] = row[i];
        }
        return map;
      }).toList();
    }

    return result.rows.map((row) {
      final map = <String, String>{};
      for (var i = 0; i < result.header.length && i < row.length; i++) {
        final headerName = result.header[i];
        final fieldName = fieldMapping?[headerName] ?? headerName;
        map[fieldName] = row[i];
      }
      return map;
    }).toList();
  }

  /// Detect file type from filename and content.
  static FileType detectFileType(String filename, Uint8List content) {
    final ext = filename.toLowerCase();

    // Check CSV extension
    if (ext.endsWith('.csv')) {
      return FileType.csv;
    }

    // Unsupported file type
    return FileType.unknown;
  }

  /// Check if file is a CSV file.
  static bool isCsvFile(String filename, Uint8List content) {
    return detectFileType(filename, content) == FileType.csv;
  }

  /// Get supported file extensions.
  static List<String> get supportedExtensions => ['.csv'];
}

/// File type enumeration.
enum FileType {
  csv,
  unknown,
}

/// Result of file parsing.
class FileParseResult {
  /// Header row (if hasHeader is true).
  final List<String> header;

  /// Data rows.
  final List<List<String>> rows;

  /// Detected file type.
  final FileType fileType;

  /// Detected encoding (for CSV files).
  final String detectedEncoding;

  /// Detected delimiter (for CSV files).
  final String? detectedDelimiter;

  /// Total row count (including header).
  final int totalRows;

  /// Error message if parsing failed.
  final String? error;

  const FileParseResult({
    required this.header,
    required this.rows,
    required this.fileType,
    required this.detectedEncoding,
    this.detectedDelimiter,
    required this.totalRows,
    this.error,
  });

  /// Returns true if there's a header row.
  bool get hasHeader => header.isNotEmpty;

  /// Returns the number of data rows.
  int get dataRowCount => rows.length;

  /// Returns true if parsing was successful.
  bool get isSuccess => error == null;

  /// Returns true if this is a CSV file.
  bool get isCsv => fileType == FileType.csv;

  /// Get a specific row by index.
  List<String>? rowAt(int index) {
    if (index < 0 || index >= rows.length) return null;
    return rows[index];
  }

  /// Get a specific field from a row by header name.
  String? fieldAt(int rowIndex, String headerName) {
    final headerIndex = header.indexOf(headerName);
    if (headerIndex == -1) return null;

    final row = rowAt(rowIndex);
    if (row == null || headerIndex >= row.length) return null;

    return row[headerIndex];
  }
}