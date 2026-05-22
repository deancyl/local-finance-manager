import 'package:csv/csv.dart';
import 'dart:typed_data';
import 'encoding_detector.dart';

/// CSV parser with support for Chinese financial institution exports.
///
/// Features:
/// - Auto-detects encoding (UTF-8, GBK, GB2312)
/// - Handles various delimiters (comma, tab, semicolon)
/// - Handles quoted fields with Chinese characters
/// - Handles backtick prefix (common in WeChat Pay exports)
class CsvParser {
  /// Default field delimiter.
  static const defaultDelimiter = ',';

  /// Parse CSV content and return list of rows.
  ///
  /// Parameters:
  /// - [content]: Raw file bytes
  /// - [encoding]: Optional encoding hint
  /// - [delimiter]: Field delimiter (default: comma)
  /// - [hasHeader]: Whether first row is header
  ///
  /// Returns:
  /// - List of rows, each row is a list of field values
  static CsvParseResult parse({
    required Uint8List content,
    String? encoding,
    String? delimiter,
    bool hasHeader = true,
  }) {
    // Decode content
    final decoded = EncodingDetector.decode(content, encoding);
    final detectedEncoding = EncodingDetector.detect(content);

    // Detect delimiter if not specified
    final delim = delimiter ?? _detectDelimiter(decoded);

    // Handle backtick prefix (common in WeChat Pay)
    final cleaned = _cleanBacktickPrefix(decoded);

    // Normalize line endings (fix Android/Windows compatibility)
    final normalized = _normalizeLineEndings(cleaned);

    // Parse CSV
    final rows = _parseCsvRows(normalized, delim);

    // Extract header and data
    final header = hasHeader && rows.isNotEmpty ? rows.first : null;
    final data = hasHeader && rows.isNotEmpty ? rows.sublist(1) : rows;

    return CsvParseResult(
      header: header ?? [],
      rows: data,
      detectedEncoding: detectedEncoding,
      detectedDelimiter: delim,
      totalRows: rows.length,
    );
  }

  /// Parse CSV with field mapping.
  ///
  /// Returns list of maps with field names as keys.
  static List<Map<String, String>> parseWithMapping({
    required Uint8List content,
    String? encoding,
    String? delimiter,
    bool hasHeader = true,
    Map<String, String>? fieldMapping,
  }) {
    final result = parse(
      content: content,
      encoding: encoding,
      delimiter: delimiter,
      hasHeader: hasHeader,
    );

    if (result.header.isEmpty) {
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

  /// Detect the delimiter used in CSV.
  static String _detectDelimiter(String content) {
    final firstLine = content.split('\n').firstOrNull ?? '';

    // Count occurrences of common delimiters
    final commaCount = firstLine.split(',').length - 1;
    final tabCount = firstLine.split('\t').length - 1;
    final semicolonCount = firstLine.split(';').length - 1;

    // Return the most common delimiter
    if (tabCount > commaCount && tabCount > semicolonCount) {
      return '\t';
    }
    if (semicolonCount > commaCount) {
      return ';';
    }
    return defaultDelimiter;
  }

  /// Normalize line endings to LF (\n).
  ///
  /// Handles:
  /// - Windows-style CRLF (\r\n)
  /// - Old Mac-style CR (\r)
  /// - Mixed line endings
  ///
  /// This is critical for Android compatibility as banking apps
  /// often export files with Windows-style line endings.
  static String _normalizeLineEndings(String content) {
    // First replace CRLF with LF (Windows style)
    // Then replace standalone CR with LF (old Mac style)
    return content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  /// Clean backtick prefix from CSV content.
  ///
  /// WeChat Pay exports sometimes have a backtick (`) prefix
  /// to prevent Excel from interpreting numbers as dates.
  static String _cleanBacktickPrefix(String content) {
    // Remove backtick at the start of the file
    if (content.startsWith('`')) {
      return content.substring(1);
    }
    return content;
  }

  /// Parse CSV rows using the csv package.
  static List<List<String>> _parseCsvRows(String content, String delimiter) {
    try {
      final csvConverter = CsvToListConverter(
        fieldDelimiter: delimiter,
        textDelimiter: '"',
        textEndDelimiter: '"',
        eol: '\n',
      );

      final rows = csvConverter.convert(content);

      // Convert to List<List<String>>
      return rows.map((row) {
        return row.map((field) => field?.toString() ?? '').toList();
      }).toList();
    } catch (e) {
      // Fallback: simple line-by-line parsing
      return content
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => _parseCsvLine(line, delimiter))
          .toList();
    }
  }

  /// Parse a single CSV line.
  static List<String> _parseCsvLine(String line, String delimiter) {
    final fields = <String>[];
    var current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          // Escaped quote
          current.write('"');
          i++;
        } else {
          // Toggle quote state
          inQuotes = !inQuotes;
        }
      } else if (char == delimiter && !inQuotes) {
        // Field separator
        fields.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }

    // Add last field
    fields.add(current.toString().trim());

    return fields;
  }
}

/// Result of CSV parsing.
class CsvParseResult {
  /// Header row (if hasHeader is true).
  final List<String> header;

  /// Data rows.
  final List<List<String>> rows;

  /// Detected encoding.
  final String detectedEncoding;

  /// Detected delimiter.
  final String detectedDelimiter;

  /// Total row count (including header).
  final int totalRows;

  const CsvParseResult({
    required this.header,
    required this.rows,
    required this.detectedEncoding,
    required this.detectedDelimiter,
    required this.totalRows,
  });

  /// Returns true if there's a header row.
  bool get hasHeader => header.isNotEmpty;

  /// Returns the number of data rows.
  int get dataRowCount => rows.length;

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