import 'dart:typed_data';
import '../base/importer_base.dart';
import '../base/import_config.dart';
import '../base/import_result.dart';
import '../utils/file_parser.dart';
import '../utils/date_parser.dart';
import '../utils/amount_parser.dart';
import 'package:core/src/models/import_source.dart';

/// CCB (建设银行) CSV importer.
///
/// Supports CCB bank statement exports with:
/// - GBK or UTF-8 encoding
/// - Headers: 交易日期, 交易金额, 余额, 摘要, etc.
/// - Date format: 20260519 or 2026-05-19
/// - Amount can be positive/negative
class CcbImporter extends ImporterBase {
  @override
  String get name => '建设银行';

  @override
  String get sourceId => 'ccb';

  @override
  List<String> get supportedExtensions => ['.csv', '.xls', '.xlsx'];

  @override
  ImportSourceType get sourceType => ImportSourceType.bank;

  @override
  String get description => '建设银行账户交易记录导入';

  /// CCB-specific header patterns for detection.
  static const List<String> _requiredHeaders = [
    '交易日期',
    '交易金额',
  ];

  @override
  bool canParse({
    required String filename,
    required Uint8List content,
    String? encoding,
  }) {
    // Check file extension
    final ext = filename.toLowerCase();
    if (!supportedExtensions.any((e) => ext.endsWith(e))) {
      return false;
    }

    // Parse file (CSV or Excel)
    final fileResult = FileParser.parse(
      filename: filename,
      content: content,
      encoding: encoding,
      hasHeader: true,
    );

    if (fileResult.header.isEmpty) {
      return false;
    }

    // Check for CCB-specific headers
    final headerSet = fileResult.header.toSet();
    var hasRequiredHeaders = true;
    for (final header in _requiredHeaders) {
      if (!headerSet.any((h) => h.contains(header))) {
        hasRequiredHeaders = false;
        break;
      }
    }

    if (hasRequiredHeaders) return true;

    // Also check for CCB-specific patterns in content
    if (fileResult.header.any((h) => h.contains('建设银行') || h.contains('CCB'))) {
      return true;
    }

    return false;
  }

  @override
  Future<ImportResult> parse({
    required Uint8List content,
    required ImportConfig config,
    String? encoding,
  }) async {
    final errors = <ParseError>[];
    final warnings = <String>[];
    final transactions = <ParsedTransaction>[];

    // Parse file (CSV or Excel)
    final fileResult = FileParser.parse(
      filename: 'ccb_import',
      content: content,
      encoding: encoding,
      hasHeader: true,
    );

    if (fileResult.header.isEmpty) {
      return ImportResult(
        transactions: [],
        errors: [
          ParseError(
            rowNumber: 1,
            message: '无法识别文件头',
            type: ParseErrorType.format,
          ),
        ],
        stats: const ImportStats(totalRows: 0),
        detectedEncoding: fileResult.detectedEncoding,
      );
    }

    // Find column indices
    final headerMap = _buildHeaderMap(fileResult.header);

    // Validate required columns
    if (!headerMap.containsKey('date')) {
      errors.add(ParseError(
        rowNumber: 1,
        message: '缺少交易日期列',
        type: ParseErrorType.missingField,
      ));
    }

    if (!headerMap.containsKey('amount') && 
        !headerMap.containsKey('income') && 
        !headerMap.containsKey('expense')) {
      errors.add(ParseError(
        rowNumber: 1,
        message: '缺少交易金额列',
        type: ParseErrorType.missingField,
      ));
    }

    // Parse each row
    for (var i = 0; i < fileResult.rows.length; i++) {
      final row = fileResult.rows[i];
      final rowNum = i + 2; // +1 for header, +1 for 1-indexing

      try {
        final transaction = _parseRow(row, headerMap, config, rowNum);
        if (transaction != null) {
          transactions.add(transaction);
        }
      } catch (e) {
        errors.add(ParseError(
          rowNumber: rowNum,
          message: e.toString(),
          type: ParseErrorType.parse,
          rowData: _rowToMap(fileResult.header, row),
        ));
      }
    }

    // Calculate statistics
    final stats = _calculateStats(transactions, fileResult.rows.length);

    return ImportResult(
      transactions: transactions,
      errors: errors,
      warnings: warnings,
      stats: stats,
      detectedEncoding: fileResult.detectedEncoding,
      detectedSource: sourceId,
    );
  }

  @override
  Future<ImportPreview> preview({
    required Uint8List content,
    int maxRows = 10,
    String? encoding,
  }) async {
    final fileResult = FileParser.parse(
      filename: 'ccb_preview',
      content: content,
      encoding: encoding,
      hasHeader: true,
    );

    final previewRows = <Map<String, dynamic>>[];
    final rowsToShow = fileResult.rows.take(maxRows).toList();

    for (final row in rowsToShow) {
      final map = <String, dynamic>{};
      for (var i = 0; i < fileResult.header.length && i < row.length; i++) {
        map[fileResult.header[i]] = row[i];
      }
      previewRows.add(map);
    }

    return ImportPreview(
      rows: previewRows,
      headers: fileResult.header,
      detectedEncoding: fileResult.detectedEncoding,
      totalRowCount: fileResult.rows.length,
      detectedSource: sourceId,
    );
  }

  @override
  List<String> validateConfig(ImportConfig config) {
    final errors = <String>[];

    if (config.targetAccountId.isEmpty) {
      errors.add('目标账户ID不能为空');
    }

    if (config.defaultCurrencyId.isEmpty) {
      errors.add('默认货币ID不能为空');
    }

    return errors;
  }

  @override
  Map<String, String> getDefaultCategoryMappings() {
    return {
      '转账': 'transfer',
      '存款': 'income',
      '取款': 'cash',
      '工资': 'salary',
      '利息': 'interest',
      '手续费': 'fee',
      '消费': 'shopping',
      '网购': 'shopping',
      '餐饮': 'food',
      '交通': 'transport',
      '医疗': 'healthcare',
      '教育': 'education',
      '娱乐': 'entertainment',
      '水电费': 'utilities',
      '话费': 'communication',
      '保险': 'insurance',
      '投资': 'investment',
      '理财': 'investment',
      '还款': 'debt',
      '贷款': 'debt',
      '汇款': 'transfer',
      '缴费': 'utilities',
      '代发': 'salary',
      'ATM取款': 'cash',
      'ATM存款': 'income',
      'POS消费': 'shopping',
      '网银转账': 'transfer',
    };
  }

  /// Build a header map from CSV headers.
  Map<String, int> _buildHeaderMap(List<String> headers) {
    final map = <String, int>{};

    for (var i = 0; i < headers.length; i++) {
      final header = headers[i].trim();

      // Date column
      if (header.contains('交易日期') || header.contains('记账日期') || header == '日期') {
        map['date'] ??= i;
      }

      // Amount column
      if (header.contains('交易金额') || header == '金额') {
        map['amount'] ??= i;
      }

      // Income column
      if (header == '收入金额' || header == '存入' || header == '收入') {
        map['income'] ??= i;
      }

      // Expense column
      if (header == '支出金额' || header == '取出' || header == '支出') {
        map['expense'] ??= i;
      }

      // Balance column
      if (header == '余额' || header.contains('账户余额')) {
        map['balance'] ??= i;
      }

      // Description column
      if (header == '摘要' || header.contains('交易摘要') || header.contains('交易描述')) {
        map['description'] ??= i;
      }

      // Counterparty name column
      if (header.contains('对方户名') || header == '对方名称') {
        map['counterparty'] ??= i;
      }

      // Counterparty account column
      if (header.contains('对方账号') || header == '对方账户') {
        map['counterpartyAccount'] ??= i;
      }

      // Transaction type column
      if (header.contains('交易类型') || header == '类型') {
        map['type'] ??= i;
      }

      // Currency column
      if (header == '币种' || header == '货币') {
        map['currency'] ??= i;
      }
    }

    return map;
  }

  /// Parse a single row into a ParsedTransaction.
  ParsedTransaction? _parseRow(
    List<String> row,
    Map<String, int> headerMap,
    ImportConfig config,
    int rowNum,
  ) {
    String? getField(String key) {
      final index = headerMap[key];
      if (index == null || index >= row.length) return null;
      return row[index].trim();
    }

    // Parse date
    final dateStr = getField('date');
    if (dateStr == null || dateStr.isEmpty) {
      throw Exception('交易日期为空');
    }
    final date = DateParser.parse(dateStr);
    if (date == null) {
      throw Exception('无法解析日期: $dateStr');
    }

    // Parse amount
    double? amount;
    final amountStr = getField('amount');
    final incomeStr = getField('income');
    final expenseStr = getField('expense');

    if (amountStr != null && amountStr.isNotEmpty) {
      amount = AmountParser.parse(amountStr);
    } else if (incomeStr != null && incomeStr.isNotEmpty && incomeStr != '--') {
      amount = AmountParser.parse(incomeStr);
    } else if (expenseStr != null && expenseStr.isNotEmpty && expenseStr != '--') {
      amount = AmountParser.parse(expenseStr);
      if (amount != null) amount = -amount;
    }

    if (amount == null || amount == 0) {
      return null; // Skip rows with no amount
    }

    // Build description
    final description = getField('description') ?? getField('type') ?? '';
    final counterparty = getField('counterparty') ?? '';
    final fullDescription = counterparty.isNotEmpty
        ? '$description - $counterparty'
        : description;

    // Generate external ID
    final externalId = 'ccb_${date.millisecondsSinceEpoch}_${amount.abs()}_$rowNum';

    return ParsedTransaction(
      accountId: config.targetAccountId,
      amount: amount,
      date: date,
      currencyId: config.defaultCurrencyId,
      description: fullDescription,
      notes: getField('type'),
      memo: getField('counterpartyAccount'),
      externalId: externalId,
      category: getField('type'),
      payee: counterparty,
    );
  }

  /// Calculate import statistics.
  ImportStats _calculateStats(List<ParsedTransaction> transactions, int totalRows) {
    if (transactions.isEmpty) {
      return ImportStats(totalRows: totalRows);
    }

    DateTime? firstDate;
    DateTime? lastDate;
    double totalAmount = 0;

    for (final t in transactions) {
      if (firstDate == null || t.date.isBefore(firstDate)) {
        firstDate = t.date;
      }
      if (lastDate == null || t.date.isAfter(lastDate)) {
        lastDate = t.date;
      }
      totalAmount += t.amount;
    }

    return ImportStats(
      totalRows: totalRows,
      successCount: transactions.length,
      errorCount: totalRows - transactions.length,
      firstDate: firstDate,
      lastDate: lastDate,
      totalAmount: totalAmount,
      detectedCurrency: 'CNY',
    );
  }

  /// Convert row to map for error reporting.
  Map<String, dynamic> _rowToMap(List<String> headers, List<String> row) {
    final map = <String, dynamic>{};
    for (var i = 0; i < headers.length && i < row.length; i++) {
      map[headers[i]] = row[i];
    }
    return map;
  }
}
