import 'dart:typed_data';
import 'package:core/core.dart';
import '../base/importer_base.dart';
import '../base/import_result.dart';
import '../base/import_config.dart';
import '../utils/file_parser.dart';
import '../utils/date_parser.dart';
import '../utils/amount_parser.dart';

/// Alipay (支付宝) CSV importer.
///
/// Supports parsing Alipay transaction export files with:
/// - Standard Alipay CSV format
/// - Huabei (花呗) transactions
/// - Yu'ebao (余额宝) transactions
/// - Balance (余额) transactions
class AlipayImporter implements ImporterBase {
  @override
  String get name => '支付宝';

  @override
  String get sourceId => ImportSource.alipay;

  @override
  List<String> get supportedExtensions => ['.csv', '.xls', '.xlsx'];

  @override
  ImportSourceType get sourceType => ImportSourceType.paymentApp;

  @override
  String get description => '导入支付宝账单CSV文件，支持余额、余额宝、花呗等账户';

  /// Alipay CSV header fields (Chinese).
  static const _requiredHeaders = [
    '交易时间',
    '交易分类',
    '交易对方',
    '商品说明',
    '收/支',
    '金额',
    '收/付款方式',
    '交易状态',
    '交易订单号',
  ];

  /// Alipay category mappings to standard categories.
  static const _categoryMappings = {
    // Food & Dining
    '餐饮美食': 'food',
    '美食': 'food',
    '外卖': 'food',
    '小吃': 'food',
    '饮品': 'food',
    '甜点': 'food',

    // Transportation
    '交通出行': 'transport',
    '出行': 'transport',
    '打车': 'transport',
    '公交': 'transport',
    '地铁': 'transport',
    '火车': 'transport',
    '机票': 'transport',
    '汽车': 'transport',

    // Shopping
    '购物': 'shopping',
    '网上购物': 'shopping',
    '服饰': 'shopping',
    '数码': 'shopping',
    '家居': 'shopping',
    '日用百货': 'shopping',

    // Entertainment
    '休闲娱乐': 'entertainment',
    '娱乐': 'entertainment',
    '游戏': 'entertainment',
    '电影': 'entertainment',
    '演出': 'entertainment',

    // Healthcare
    '医疗健康': 'health',
    '医疗': 'health',
    '健康': 'health',
    '药店': 'health',

    // Education
    '教育': 'education',
    '培训': 'education',
    '书籍': 'education',

    // Services
    '生活服务': 'services',
    '服务': 'services',
    '充值': 'services',
    '缴费': 'services',
    '维修': 'services',

    // Communication
    '通讯': 'communication',
    '话费': 'communication',
    '网络': 'communication',

    // Finance
    '金融': 'finance',
    '理财': 'finance',
    '转账': 'transfer',
    '红包': 'transfer',
    '收款': 'income',

    // Other
    '其他': 'other',
    '未知': 'other',
  };

  /// Alipay account types.
  static const _accountTypes = {
    '余额': 'balance',
    '余额宝': 'yuebao',
    '花呗': 'huabei',
    '银行卡': 'bank_card',
    '信用卡': 'credit_card',
  };

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
    try {
      final result = FileParser.parse(
        filename: filename,
        content: content,
        encoding: encoding,
        hasHeader: true,
      );

      // Check for required Alipay headers
      final headerSet = result.header.toSet();
      final matchCount = _requiredHeaders.where(headerSet.contains).length;

      // Require at least 6 of 9 required headers to identify as Alipay
      return matchCount >= 6;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ImportResult> parse({
    required Uint8List content,
    required ImportConfig config,
    String? encoding,
  }) async {
    final transactions = <ParsedTransaction>[];
    final errors = <ParseError>[];
    final warnings = <String>[];

    // Parse file (CSV or Excel)
    final fileResult = FileParser.parse(
      filename: 'alipay_import',
      content: content,
      encoding: encoding,
      hasHeader: true,
    );

    if (fileResult.header.isEmpty) {
      return ImportResult(
        transactions: [],
        errors: [
          ParseError(
            rowNumber: 0,
            message: '无法识别文件格式，缺少表头',
            type: ParseErrorType.format,
          ),
        ],
        stats: const ImportStats(totalRows: 0),
        detectedEncoding: fileResult.detectedEncoding,
        detectedSource: sourceId,
      );
    }

    // Map header indices
    final headerMap = _mapHeaders(fileResult.header);

    // Check for required fields
    if (headerMap['time'] == null) {
      errors.add(ParseError(
        rowNumber: 0,
        message: '缺少必需字段: 交易时间',
        type: ParseErrorType.missingField,
      ));
    }

    // Parse each row
    DateTime? firstDate;
    DateTime? lastDate;
    double totalAmount = 0;
    int skippedCount = 0;

    for (var i = 0; i < fileResult.rows.length; i++) {
      final row = fileResult.rows[i];
      final rowNum = i + 2; // 1-indexed + header row

      try {
        final transaction = _parseRow(row, headerMap, config, rowNum);
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
          rowNumber: rowNum,
          message: e.toString(),
          rowData: _rowToMap(fileResult.header, row),
          type: ParseErrorType.parse,
        ));
      }
    }

    return ImportResult(
      transactions: transactions,
      errors: errors,
      warnings: warnings,
      stats: ImportStats(
        totalRows: fileResult.rows.length,
        successCount: transactions.length,
        errorCount: errors.length,
        skippedCount: skippedCount,
        firstDate: firstDate,
        lastDate: lastDate,
        totalAmount: totalAmount,
        detectedCurrency: 'CNY',
      ),
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
      filename: 'alipay_preview',
      content: content,
      encoding: encoding,
      hasHeader: true,
    );

    final previewRows = <Map<String, dynamic>>[];
    final warnings = <String>[];

    // Take first N rows
    final rowsToPreview = fileResult.rows.take(maxRows).toList();

    for (final row in rowsToPreview) {
      previewRows.add(_rowToMap(fileResult.header, row));
    }

    // Detect source account type
    String? detectedSource;
    if (fileResult.header.contains('收/付款方式')) {
      detectedSource = sourceId;
    }

    return ImportPreview(
      rows: previewRows,
      headers: fileResult.header,
      detectedEncoding: fileResult.detectedEncoding,
      totalRowCount: fileResult.rows.length,
      detectedSource: detectedSource,
      warnings: warnings,
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
    return Map.from(_categoryMappings);
  }

  /// Map CSV headers to field names.
  Map<String, int> _mapHeaders(List<String> headers) {
    final map = <String, int>{};

    for (var i = 0; i < headers.length; i++) {
      final header = headers[i].trim();
      switch (header) {
        case '交易时间':
          map['time'] = i;
          break;
        case '交易分类':
          map['category'] = i;
          break;
        case '交易对方':
          map['payee'] = i;
          break;
        case '商品说明':
          map['description'] = i;
          break;
        case '收/支':
          map['type'] = i;
          break;
        case '金额':
          map['amount'] = i;
          break;
        case '收/付款方式':
          map['account'] = i;
          break;
        case '交易状态':
          map['status'] = i;
          break;
        case '交易订单号':
          map['orderId'] = i;
          break;
        case '备注':
          map['notes'] = i;
          break;
        case '资金流向':
          map['flow'] = i;
          break;
        case '已退款':
          map['refunded'] = i;
          break;
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
      return index != null && index < row.length ? row[index].trim() : null;
    }

    // Skip empty rows
    if (row.every((field) => field.trim().isEmpty)) {
      return null;
    }

    // Get required fields
    final timeStr = getField('time');
    final amountStr = getField('amount');
    final typeStr = getField('type');
    final statusStr = getField('status');

    // Skip rows without essential data
    if (timeStr == null || timeStr.isEmpty) {
      return null;
    }

    // Skip non-completed transactions
    if (statusStr != null && !_isCompletedStatus(statusStr)) {
      return null;
    }

    // Parse date
    final date = DateParser.parse(timeStr);
    if (date == null) {
      throw Exception('无法解析日期: $timeStr');
    }

    // Parse amount
    final amountResult = AmountParser.parseWithType(amountStr);
    if (amountResult == null) {
      throw Exception('无法解析金额: $amountStr');
    }

    // Determine income/expense from type field
    bool isIncome;
    if (typeStr != null) {
      isIncome = typeStr.contains('收入') ||
          typeStr.contains('退款') ||
          typeStr == '收';
    } else {
      isIncome = amountResult.isIncome;
    }

    // Get account from payment method
    final accountStr = getField('account') ?? '';
    String accountId = config.targetAccountId;

    // Check account mapping
    for (final entry in _accountTypes.entries) {
      if (accountStr.contains(entry.key)) {
        final mappedId = config.getAccountId(entry.value);
        if (mappedId != null) {
          accountId = mappedId;
        }
        break;
      }
    }

    // Get category
    final categoryStr = getField('category') ?? '';
    String? category = config.getCategoryId(categoryStr);
    category ??= _categoryMappings[categoryStr];

    // Build description
    final payee = getField('payee') ?? '';
    final description = getField('description') ?? '';
    final fullDescription = payee.isNotEmpty
        ? '$payee: $description'
        : description;

    // Get external ID (order ID)
    final orderId = getField('orderId');

    // Get notes
    final notes = getField('notes');

    return ParsedTransaction(
      accountId: accountId,
      amount: isIncome ? amountResult.amount.abs() : -amountResult.amount.abs(),
      date: date,
      currencyId: config.defaultCurrencyId,
      description: fullDescription,
      notes: notes,
      externalId: orderId,
      category: category,
      payee: payee,
    );
  }

  /// Check if transaction status indicates completion.
  bool _isCompletedStatus(String status) {
    // Alipay completed statuses
    const completedStatuses = [
      '交易成功',
      '支付成功',
      '已付款',
      '已收款',
      '退款成功',
      '转账成功',
      '充值成功',
      '提现成功',
    ];

    return completedStatuses.any((s) => status.contains(s));
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
