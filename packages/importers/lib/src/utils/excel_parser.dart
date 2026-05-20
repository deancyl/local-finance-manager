import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'encoding_detector.dart';

/// Excel parser with support for XLS and XLSX files.
///
/// Features:
/// - Supports both .xls and .xlsx formats
/// - Auto-detects encoding for cell values
/// - Handles multiple sheets (uses first sheet by default)
/// - Converts Excel data to CSV-like format for compatibility
class ExcelParser {
  /// Parse Excel content and return list of rows.
  ///
  /// Parameters:
  /// - [content]: Raw file bytes
  /// - [sheetIndex]: Sheet index to parse (default: 0)
  /// - [hasHeader]: Whether first row is header
  ///
  /// Returns:
  /// - List of rows, each row is a list of field values
  static ExcelParseResult parse({
    required Uint8List content,
    int sheetIndex = 0,
    bool hasHeader = true,
  }) {
    try {
      // Decode Excel file
      final excel = Excel.decodeBytes(content);

      // Get sheet names
      final sheetNames = excel.tables.keys.toList();

      if (sheetNames.isEmpty) {
        return ExcelParseResult(
          header: [],
          rows: [],
          sheetNames: [],
          selectedSheet: '',
          totalRows: 0,
          error: 'Excel文件中没有工作表',
        );
      }

      // Select sheet
      final selectedSheetName = sheetIndex < sheetNames.length
          ? sheetNames[sheetIndex]
          : sheetNames.first;
      final sheet = excel.tables[selectedSheetName];

      if (sheet == null) {
        return ExcelParseResult(
          header: [],
          rows: [],
          sheetNames: sheetNames,
          selectedSheet: selectedSheetName,
          totalRows: 0,
          error: '无法访问工作表: $selectedSheetName',
        );
      }

      // Extract rows
      final allRows = _extractRows(sheet);

      // Extract header and data
      final header = hasHeader && allRows.isNotEmpty ? allRows.first : <String>[];
      final data = hasHeader && allRows.isNotEmpty
          ? allRows.sublist(1)
          : allRows;

      return ExcelParseResult(
        header: header,
        rows: data,
        sheetNames: sheetNames,
        selectedSheet: selectedSheetName,
        totalRows: allRows.length,
      );
    } catch (e) {
      return ExcelParseResult(
        header: [],
        rows: [],
        sheetNames: [],
        selectedSheet: '',
        totalRows: 0,
        error: '解析Excel文件失败: $e',
      );
    }
  }

  /// Parse Excel with field mapping.
  ///
  /// Returns list of maps with field names as keys.
  static List<Map<String, String>> parseWithMapping({
    required Uint8List content,
    int sheetIndex = 0,
    bool hasHeader = true,
    Map<String, String>? fieldMapping,
  }) {
    final result = parse(
      content: content,
      sheetIndex: sheetIndex,
      hasHeader: hasHeader,
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

  /// Extract rows from Excel sheet.
  static List<List<String>> _extractRows(Sheet sheet) {
    final rows = <List<String>>[];

    // Get max rows and columns
    final maxRows = sheet.maxRows;
    final maxCols = sheet.maxColumns;

    for (var rowIndex = 0; rowIndex < maxRows; rowIndex++) {
      final row = <String>[];
      var hasData = false;

      for (var colIndex = 0; colIndex < maxCols; colIndex++) {
        final cell = sheet.cell(
          CellIndex.indexByString(
            '${_getColumnName(colIndex)}${rowIndex + 1}',
          ),
        );

        final value = _cellToString(cell);
        row.add(value);

        if (value.isNotEmpty) {
          hasData = true;
        }
      }

      // Only add rows that have data
      if (hasData) {
        rows.add(row);
      }
    }

    return rows;
  }

  /// Convert cell value to string.
  static String _cellToString(Data cell) {
    final value = cell.value;

    if (value == null) {
      return '';
    }

    // Handle different cell types
    switch (cell.type) {
      case CellType.text:
      case CellType.string:
        return value.toString().trim();

      case CellType.num:
        // Handle numbers (avoid scientific notation for large numbers)
        final numValue = value;
        if (numValue is double) {
          // Check if it's actually an integer
          if (numValue == numValue.toInt()) {
            return numValue.toInt().toString();
          }
          // Format with reasonable precision
          return numValue.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
        }
        return numValue.toString();

      case CellType.date:
        // Handle dates
        if (value is DateTime) {
          return _formatDateTime(value);
        }
        return value.toString();

      case CellType.bool:
        return value.toString();

      case CellType.formula:
        // For formula cells, get the calculated value
        return value.toString().trim();

      case CellType.empty:
        return '';

      default:
        return value.toString().trim();
    }
  }

  /// Format DateTime to string.
  static String _formatDateTime(DateTime dt) {
    final year = dt.year;
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');

    // If time is midnight, just return date
    if (hour == '00' && minute == '00' && second == '00') {
      return '$year-$month-$day';
    }

    return '$year-$month-$day $hour:$minute:$second';
  }

  /// Get Excel column name from index (0 -> A, 1 -> B, etc.).
  static String _getColumnName(int index) {
    final result = StringBuffer();
    var i = index;

    while (i >= 0) {
      result.write(String.fromCharCode(65 + (i % 26)));
      i = (i ~/ 26) - 1;
    }

    return result.toString().split('').reversed.join();
  }

  /// Check if the given bytes represent a valid Excel file.
  static bool isExcelFile(Uint8List bytes) {
    if (bytes.length < 4) return false;

    // Check for XLSX (ZIP-based, starts with PK)
    if (bytes[0] == 0x50 && bytes[1] == 0x4B) {
      return true;
    }

    // Check for XLS (OLE-based, starts with D0 CF 11 E0)
    if (bytes[0] == 0xD0 &&
        bytes[1] == 0xCF &&
        bytes[2] == 0x11 &&
        bytes[3] == 0xE0) {
      return true;
    }

    return false;
  }

  /// Get all sheet names from Excel file.
  static List<String> getSheetNames(Uint8List content) {
    try {
      final excel = Excel.decodeBytes(content);
      return excel.tables.keys.toList();
    } catch (_) {
      return [];
    }
  }
}

/// Result of Excel parsing.
class ExcelParseResult {
  /// Header row (if hasHeader is true).
  final List<String> header;

  /// Data rows.
  final List<List<String>> rows;

  /// All sheet names in the file.
  final List<String> sheetNames;

  /// Selected sheet name.
  final String selectedSheet;

  /// Total row count (including header).
  final int totalRows;

  /// Error message if parsing failed.
  final String? error;

  const ExcelParseResult({
    required this.header,
    required this.rows,
    required this.sheetNames,
    required this.selectedSheet,
    required this.totalRows,
    this.error,
  });

  /// Returns true if there's a header row.
  bool get hasHeader => header.isNotEmpty;

  /// Returns the number of data rows.
  int get dataRowCount => rows.length;

  /// Returns true if parsing was successful.
  bool get isSuccess => error == null;

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
