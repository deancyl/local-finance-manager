import 'dart:typed_data';
import 'package:core/core.dart';
import '../base/importer_base.dart';
import '../base/import_config.dart';
import '../base/import_result.dart';
import '../utils/csv_parser.dart';
import '../utils/date_parser.dart';
import '../utils/amount_parser.dart';

/// WeChat Pay (微信支付) CSV importer.
///
/// Supports parsing WeChat Pay transaction export files.
///
/// WeChat Pay CSV format:
/// - Header: 交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,交易单号,商户单号,备注
/// - Date format: 2026-05-19 10:30:00
/// - Amount format: ¥0.01, ¥35.50
/// - May have backtick (`) prefix to prevent Excel auto-format
///
/// Transaction types (交易类型):
/// - 商户消费
/// - 转账
/// - 红包
/// - 微信红包
/// - 零钱充值
/// - 零钱提现
/// - 零钱通转入
/// - 零钱通转出
/// - 信用卡还款
/// - 生活缴费
/// - 理财通购买
/// - 理财通赎回
class WeChatPayImporter extends ImporterBase {
  /// WeChat Pay CSV header columns (in Chinese).
  static const _expectedHeaders = [
    '交易时间',
    '交易类型',
    '交易对方',
    '商品',
    '收/支',
    '金额(元)',
    '支付方式',
    '当前状态',
    '交易单号',
    '商户单号',
    '备注',
  ];

  /// Alternative header variations.
  static const _alternativeHeaders = [
    '交易时间',
    '交易类型',
    '交易对方',
    '商品说明',
    '收/支',
    '金额(元)',
    '支付方式',
    '当前状态',
    '交易单号',
    '商户单号',
    '备注',
  ];

  @override
  String get name => 'WeChat Pay';

  @override
  String get sourceId => ImportSource.wechatPay;

  @override
  List<String> get supportedExtensions => ['.csv'];

  @override
  ImportSourceType get sourceType => ImportSourceType.paymentApp;

  @override
  String get description => '微信支付账单导入器，支持CSV格式导出文件';

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

    // Parse CSV and check headers
    try {
      final result = CsvParser.parse(
        content: content,
        encoding: encoding,
        hasHeader: true,
      );

      if (result.header.isEmpty) {
        return false;
      }

      // Check for WeChat Pay specific headers
      // We need at least these key headers to identify WeChat Pay
      final requiredHeaders = ['交易时间', '交易类型', '收/支', '金额(元)'];
      final headerSet = result.header.toSet();

      final hasRequiredHeaders = requiredHeaders.every(
        (h) => headerSet.contains(h),
      );

      return hasRequiredHeaders;
    } catch (e) {
      return false;
    }
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

    // Parse CSV
    final csvResult = CsvParser.parse(
      content: content,
      encoding: encoding,
      hasHeader: true,
    );

    if (csvResult.header.isEmpty) {
      return ImportResult(
        transactions: [],
        errors: [
          ParseError(
            rowNumber: 0,
            message: '无法识别CSV文件格式，缺少表头',
            type: ParseErrorType.format,
          ),
        ],
        warnings: warnings,
        stats: const ImportStats(totalRows: 0),
        detectedEncoding: csvResult.detectedEncoding,
        detectedSource: sourceId,
      );
    }

    // Build column index map
    final columnMap = _buildColumnMap(csvResult.header);

    // Validate required columns
    final missingColumns = _validateColumns(columnMap);
    if (missingColumns.isNotEmpty) {
      return ImportResult(
        transactions: [],
        errors: [
          ParseError(
            rowNumber: 0,
            message: '缺少必需列: ${missingColumns.join(', ')}',
            type: ParseErrorType.format,
          ),
        ],
        warnings: warnings,
        stats: ImportStats(totalRows: csvResult.dataRowCount),
        detectedEncoding: csvResult.detectedEncoding,
        detectedSource: sourceId,
      );
    }

    // Parse each row
    DateTime? firstDate;
    DateTime? lastDate;
    double totalAmount = 0;
    int skippedCount = 0;

    for (var i = 0; i < csvResult.rows.length; i++) {
      final row = csvResult.rows[i];
      final rowNumber = i + 2; // 1-indexed + header row

      try {
        final transaction = _parseRow(row, columnMap, config, rowNumber);
        if (transaction != null) {
          transactions.add(transaction);

          // Update stats
          if (firstDate == null || transaction.date.isBefore(firstDate)) {
            firstDate = transaction.date;
          }
          if (lastDate == null || transaction.date.isAfter(lastDate)) {
            lastDate = transaction.date;
          }
          totalAmount += transaction.amount;
        } else {
          skippedCount++;
        }
      } catch (e) {
        errors.add(ParseError(
          rowNumber: rowNumber,
          message: e.toString(),
          type: ParseErrorType.parse,
        ));
      }
    }

    return ImportResult(
      transactions: transactions,
      errors: errors,
      warnings: warnings,
      stats: ImportStats(
        totalRows: csvResult.dataRowCount,
        successCount: transactions.length,
        errorCount: errors.length,
        skippedCount: skippedCount,
        firstDate: firstDate,
        lastDate: lastDate,
        totalAmount: totalAmount,
        detectedCurrency: 'CNY',
      ),
      detectedEncoding: csvResult.detectedEncoding,
      detectedSource: sourceId,
    );
  }

  @override
  Future<ImportPreview> preview({
    required Uint8List content,
    int maxRows = 10,
    String? encoding,
  }) async {
    final csvResult = CsvParser.parse(
      content: content,
      encoding: encoding,
      hasHeader: true,
    );

    final previewRows = <Map<String, dynamic>>[];
    final rowsToPreview = csvResult.rows.take(maxRows).toList();

    final columnMap = _buildColumnMap(csvResult.header);

    for (final row in rowsToPreview) {
      final rowData = <String, dynamic>{};

      for (var i = 0; i < csvResult.header.length && i < row.length; i++) {
        rowData[csvResult.header[i]] = row[i];
      }

      // Add parsed preview data
      final dateStr = _getColumnValue(row, columnMap, '交易时间');
      final typeStr = _getColumnValue(row, columnMap, '交易类型');
      final amountStr = _getColumnValue(row, columnMap, '金额(元)');
      final directionStr = _getColumnValue(row, columnMap, '收/支');
      final payeeStr = _getColumnValue(row, columnMap, '交易对方');
      final methodStr = _getColumnValue(row, columnMap, '支付方式');

      final date = DateParser.parse(dateStr);
      final amount = AmountParser.parse(amountStr);
      final isIncome = directionStr == '收入';

      rowData['_parsed_date'] = date != null
          ? DateParser.formatWithTime(date)
          : dateStr;
      rowData['_parsed_amount'] = amount != null
          ? AmountParser.format(amount)
          : amountStr;
      rowData['_parsed_type'] = isIncome ? '收入' : '支出';
      rowData['_parsed_category'] = _mapTransactionType(typeStr);
      rowData['_parsed_payee'] = payeeStr;
      rowData['_parsed_method'] = methodStr;

      previewRows.add(rowData);
    }

    return ImportPreview(
      rows: previewRows,
      headers: csvResult.header,
      detectedEncoding: csvResult.detectedEncoding,
      totalRowCount: csvResult.dataRowCount,
      detectedSource: sourceId,
      warnings: csvResult.detectedEncoding == 'gbk'
          ? ['检测到GBK编码，已自动转换为UTF-8']
          : [],
    );
  }

  @override
  List<String> validateConfig(ImportConfig config) {
    final errors = <String>[];

    if (config.targetAccountId.isEmpty) {
      errors.add('必须指定目标账户ID');
    }

    if (config.defaultCurrencyId.isEmpty) {
      errors.add('必须指定默认货币ID');
    }

    return errors;
  }

  @override
  Map<String, String> getDefaultCategoryMappings() {
    return {
      // 消费类
      '商户消费': 'expense:shopping',
      '扫二维码付款': 'expense:shopping',
      '二维码收款': 'income:business',

      // 餐饮
      '餐饮': 'expense:food',
      '外卖': 'expense:food',

      // 交通
      '交通出行': 'expense:transport',
      '滴滴出行': 'expense:transport',
      '打车': 'expense:transport',
      '公交': 'expense:transport',
      '地铁': 'expense:transport',

      // 转账
      '转账': 'transfer',
      '转账-退款': 'income:refund',
      '转账-到账': 'income:transfer',
      '转账-转出': 'expense:transfer',

      // 红包
      '红包': 'income:gift',
      '微信红包': 'income:gift',
      '发红包': 'expense:gift',

      // 零钱
      '零钱充值': 'transfer',
      '零钱提现': 'transfer',
      '零钱通转入': 'transfer',
      '零钱通转出': 'transfer',
      '零钱通收益': 'income:investment',

      // 信用卡
      '信用卡还款': 'transfer',

      // 生活缴费
      '生活缴费': 'expense:utilities',
      '水电煤缴费': 'expense:utilities',
      '手机充值': 'expense:phone',

      // 理财
      '理财通购买': 'expense:investment',
      '理财通赎回': 'income:investment',
      '理财通收益': 'income:investment',

      // 其他
      '群收款': 'income:other',
      '赞赏': 'income:other',
      '公益': 'expense:charity',
    };
  }

  /// Build column index map from header.
  Map<String, int> _buildColumnMap(List<String> header) {
    final map = <String, int>{};

    for (var i = 0; i < header.length; i++) {
      final h = header[i].trim();
      map[h] = i;
    }

    return map;
  }

  /// Validate required columns exist.
  List<String> _validateColumns(Map<String, int> columnMap) {
    final required = ['交易时间', '交易类型', '收/支', '金额(元)'];
    final missing = <String>[];

    for (final col in required) {
      if (!columnMap.containsKey(col)) {
        missing.add(col);
      }
    }

    return missing;
  }

  /// Get column value from row.
  String _getColumnValue(
    List<String> row,
    Map<String, int> columnMap,
    String columnName,
  ) {
    final index = columnMap[columnName];
    if (index == null || index >= row.length) {
      return '';
    }
    return row[index].trim();
  }

  /// Parse a single row into a ParsedTransaction.
  ParsedTransaction? _parseRow(
    List<String> row,
    Map<String, int> columnMap,
    ImportConfig config,
    int rowNumber,
  ) {
    final dateStr = _getColumnValue(row, columnMap, '交易时间');
    final typeStr = _getColumnValue(row, columnMap, '交易类型');
    final payeeStr = _getColumnValue(row, columnMap, '交易对方');
    final productStr = _getColumnValue(row, columnMap, '商品');
    final directionStr = _getColumnValue(row, columnMap, '收/支');
    final amountStr = _getColumnValue(row, columnMap, '金额(元)');
    final methodStr = _getColumnValue(row, columnMap, '支付方式');
    final statusStr = _getColumnValue(row, columnMap, '当前状态');
    final transactionIdStr = _getColumnValue(row, columnMap, '交易单号');
    final merchantIdStr = _getColumnValue(row, columnMap, '商户单号');
    final noteStr = _getColumnValue(row, columnMap, '备注');

    // Skip empty rows
    if (dateStr.isEmpty && amountStr.isEmpty) {
      return null;
    }

    // Parse date
    final date = DateParser.parse(dateStr);
    if (date == null) {
      throw Exception('无法解析日期: $dateStr');
    }

    // Parse amount
    final amount = AmountParser.parse(amountStr);
    if (amount == null) {
      throw Exception('无法解析金额: $amountStr');
    }

    // Determine income/expense
    final isIncome = directionStr == '收入';
    final signedAmount = isIncome ? amount.abs() : -amount.abs();

    // Build description
    final description = _buildDescription(typeStr, payeeStr, productStr);

    // Map category
    final category = _mapTransactionType(typeStr);

    // Determine account from payment method
    final accountName = _parsePaymentAccount(methodStr);
    final accountId = config.accountMapping[accountName] ?? config.targetAccountId;

    // Build external ID
    final externalId = transactionIdStr.isNotEmpty
        ? transactionIdStr
        : 'wechat_${date.millisecondsSinceEpoch}_$rowNumber';

    // Build notes
    final notes = _buildNotes(statusStr, noteStr, merchantIdStr);

    return ParsedTransaction(
      accountId: accountId,
      amount: signedAmount,
      date: date,
      currencyId: config.defaultCurrencyId,
      description: description,
      notes: notes,
      memo: productStr,
      externalId: externalId,
      category: category,
      payee: payeeStr,
    );
  }

  /// Build transaction description.
  String _buildDescription(String type, String payee, String product) {
    final parts = <String>[];

    if (type.isNotEmpty) {
      parts.add(type);
    }

    if (payee.isNotEmpty && payee != '/') {
      parts.add(payee);
    }

    if (product.isNotEmpty && product != '/') {
      parts.add(product);
    }

    return parts.isEmpty ? '微信支付' : parts.join(' - ');
  }

  /// Map transaction type to category.
  String _mapTransactionType(String type) {
    // Direct mapping
    final mapping = getDefaultCategoryMappings();
    if (mapping.containsKey(type)) {
      return mapping[type]!;
    }

    // Pattern matching for common types
    if (type.contains('餐饮') || type.contains('外卖')) {
      return 'expense:food';
    }
    if (type.contains('交通') || type.contains('打车') || type.contains('滴滴')) {
      return 'expense:transport';
    }
    if (type.contains('红包')) {
      return 'income:gift';
    }
    if (type.contains('转账')) {
      return 'transfer';
    }
    if (type.contains('零钱通')) {
      return 'transfer';
    }
    if (type.contains('理财')) {
      return 'expense:investment';
    }
    if (type.contains('充值') || type.contains('缴费')) {
      return 'expense:utilities';
    }

    return 'expense:other';
  }

  /// Parse payment method to account name.
  String _parsePaymentAccount(String method) {
    if (method.isEmpty || method == '/') {
      return '零钱';
    }

    // Common WeChat payment methods
    if (method.contains('零钱通')) {
      return '零钱通';
    }
    if (method.contains('零钱')) {
      return '零钱';
    }
    if (method.contains('银行卡')) {
      // Extract bank name if possible
      final bankMatch = RegExp(r'银行卡\(([^)]+)\)').firstMatch(method);
      if (bankMatch != null) {
        return bankMatch.group(1) ?? '银行卡';
      }
      return '银行卡';
    }
    if (method.contains('信用卡')) {
      return '信用卡';
    }

    return method;
  }

  /// Build notes from status and remarks.
  String? _buildNotes(String status, String note, String merchantId) {
    final parts = <String>[];

    if (status.isNotEmpty && status != '已支付' && status != '支付成功') {
      parts.add('状态: $status');
    }

    if (note.isNotEmpty && note != '/') {
      parts.add(note);
    }

    if (merchantId.isNotEmpty && merchantId != '/') {
      parts.add('商户单号: $merchantId');
    }

    return parts.isEmpty ? null : parts.join('; ');
  }
}
