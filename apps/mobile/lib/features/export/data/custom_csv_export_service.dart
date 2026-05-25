import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:database/database.dart';
import 'export_service.dart';

/// Custom CSV column definition.
class CsvColumnDefinition {
  final String id;
  final String displayName;
  final String Function(TransactionWithSplit) getValue;
  final int? width;

  const CsvColumnDefinition({
    required this.id,
    required this.displayName,
    required this.getValue,
    this.width,
  });
}

/// Transaction with split data for CSV export.
class TransactionWithSplit {
  final Transaction transaction;
  final Split split;
  final Account? account;
  final Category? category;
  final Commodity? commodity;

  TransactionWithSplit({
    required this.transaction,
    required this.split,
    this.account,
    this.category,
    this.commodity,
  });
}

/// Predefined column templates for CSV export.
class CsvColumnTemplate {
  final String id;
  final String name;
  final String description;
  final List<String> columnIds;

  const CsvColumnTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.columnIds,
  });

  /// Standard template for basic transaction export.
  static const CsvColumnTemplate standard = CsvColumnTemplate(
    id: 'standard',
    name: '标准格式',
    description: '日期、描述、金额、账户、分类',
    columnIds: ['date', 'description', 'amount', 'account', 'category'],
  );

  /// Detailed template with all fields.
  static const CsvColumnTemplate detailed = CsvColumnTemplate(
    id: 'detailed',
    name: '详细格式',
    description: '包含备注、货币、录入时间等详细信息',
    columnIds: ['date', 'description', 'amount', 'currency', 'account', 'category', 'notes', 'enter_date'],
  );

  /// Accounting template for bookkeeping.
  static const CsvColumnTemplate accounting = CsvColumnTemplate(
    id: 'accounting',
    name: '记账格式',
    description: '复式记账格式，包含借贷方向',
    columnIds: ['date', 'description', 'debit', 'credit', 'account', 'category', 'notes'],
  );

  /// Simple template for quick export.
  static const CsvColumnTemplate simple = CsvColumnTemplate(
    id: 'simple',
    name: '简洁格式',
    description: '仅包含日期、描述、金额',
    columnIds: ['date', 'description', 'amount'],
  );

  /// All available templates.
  static const List<CsvColumnTemplate> all = [
    standard,
    detailed,
    accounting,
    simple,
  ];
}

/// Custom CSV export service with user-defined column mapping.
class CustomCsvExportService {
  final LocalFinanceDatabase _db;

  CustomCsvExportService(this._db);

  /// Date formats
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  /// Available column definitions.
  static final Map<String, CsvColumnDefinition> availableColumns = {
    'date': CsvColumnDefinition(
      id: 'date',
      displayName: '日期',
      getValue: (t) => _dateFormat.format(
        DateTime.fromMillisecondsSinceEpoch(t.transaction.postDate),
      ),
    ),
    'time': CsvColumnDefinition(
      id: 'time',
      displayName: '时间',
      getValue: (t) => _dateTimeFormat.format(
        DateTime.fromMillisecondsSinceEpoch(t.transaction.postDate),
      ),
    ),
    'description': CsvColumnDefinition(
      id: 'description',
      displayName: '描述',
      getValue: (t) => t.transaction.description ?? '',
    ),
    'amount': CsvColumnDefinition(
      id: 'amount',
      displayName: '金额',
      getValue: (t) {
        final amount = t.split.valueNum / t.split.valueDenom.toDouble();
        return amount.toStringAsFixed(2);
      },
    ),
    'debit': CsvColumnDefinition(
      id: 'debit',
      displayName: '借方',
      getValue: (t) {
        final amount = t.split.valueNum / t.split.valueDenom.toDouble();
        return amount < 0 ? amount.abs().toStringAsFixed(2) : '';
      },
    ),
    'credit': CsvColumnDefinition(
      id: 'credit',
      displayName: '贷方',
      getValue: (t) {
        final amount = t.split.valueNum / t.split.valueDenom.toDouble();
        return amount >= 0 ? amount.toStringAsFixed(2) : '';
      },
    ),
    'currency': CsvColumnDefinition(
      id: 'currency',
      displayName: '货币',
      getValue: (t) => t.commodity?.mnemonic ?? 'CNY',
    ),
    'account': CsvColumnDefinition(
      id: 'account',
      displayName: '账户',
      getValue: (t) => t.account?.name ?? '',
    ),
    'account_code': CsvColumnDefinition(
      id: 'account_code',
      displayName: '账户代码',
      getValue: (t) => t.account?.code ?? '',
    ),
    'category': CsvColumnDefinition(
      id: 'category',
      displayName: '分类',
      getValue: (t) => t.category?.name ?? '',
    ),
    'category_type': CsvColumnDefinition(
      id: 'category_type',
      displayName: '分类类型',
      getValue: (t) => t.category?.isIncome == true ? '收入' : '支出',
    ),
    'notes': CsvColumnDefinition(
      id: 'notes',
      displayName: '备注',
      getValue: (t) => t.transaction.notes ?? '',
    ),
    'memo': CsvColumnDefinition(
      id: 'memo',
      displayName: '明细备注',
      getValue: (t) => t.split.memo ?? '',
    ),
    'enter_date': CsvColumnDefinition(
      id: 'enter_date',
      displayName: '录入日期',
      getValue: (t) => _dateFormat.format(
        DateTime.fromMillisecondsSinceEpoch(t.transaction.enterDate),
      ),
    ),
    'reference': CsvColumnDefinition(
      id: 'reference',
      displayName: '参考号',
      getValue: (t) => t.transaction.referenceNum ?? '',
    ),
    'external_id': CsvColumnDefinition(
      id: 'external_id',
      displayName: '外部ID',
      getValue: (t) => t.transaction.externalId ?? '',
    ),
    'transaction_id': CsvColumnDefinition(
      id: 'transaction_id',
      displayName: '交易ID',
      getValue: (t) => t.transaction.id,
    ),
    'reconciled': CsvColumnDefinition(
      id: 'reconciled',
      displayName: '已对账',
      getValue: (t) => t.split.reconcileState == 'y' ? '是' : '否',
    ),
  };

  /// Exports transactions to custom CSV format.
  ///
  /// [filters] - Export filters
  /// [columnIds] - List of column IDs to include (from availableColumns)
  /// [customPath] - Optional custom file path
  /// [delimiter] - CSV delimiter (default: comma)
  /// [includeHeader] - Whether to include header row
  /// [dateFormat] - Custom date format (default: yyyy-MM-dd)
  Future<ExportResult> exportCustomCSV({
    required ExportFilters filters,
    required List<String> columnIds,
    String? customPath,
    String delimiter = ',',
    bool includeHeader = true,
    String? dateFormat,
  }) async {
    // Validate columns
    final invalidColumns = columnIds.where((id) => !availableColumns.containsKey(id)).toList();
    if (invalidColumns.isNotEmpty) {
      throw ExportException('无效的列定义: ${invalidColumns.join(', ')}');
    }

    // Fetch transactions with splits
    final transactionsWithSplits = await _fetchFilteredTransactions(filters);

    if (transactionsWithSplits.isEmpty) {
      throw ExportException('没有可导出的交易记录');
    }

    // Fetch reference data
    final accounts = await _db.select(_db.accounts).get();
    final categories = await _db.select(_db.categories).get();
    final commodities = await _db.select(_db.commodities).get();

    final accountMap = {for (var a in accounts) a.id: a};
    final categoryMap = {for (var c in categories) c.id: c};
    final commodityMap = {for (var c in commodities) c.id: c};

    // Build transaction with split list
    final flatTransactions = <TransactionWithSplit>[];
    for (final (transaction, splits) in transactionsWithSplits) {
      for (final split in splits) {
        flatTransactions.add(TransactionWithSplit(
          transaction: transaction,
          split: split,
          account: accountMap[split.accountId],
          category: split.categoryId != null ? categoryMap[split.categoryId] : null,
          commodity: commodityMap[transaction.currencyId],
        ));
      }
    }

    // Build CSV rows
    final rows = <List<String>>[];

    // Header row
    if (includeHeader) {
      final headers = columnIds.map((id) => availableColumns[id]!.displayName).toList();
      rows.add(headers);
    }

    // Data rows
    for (final t in flatTransactions) {
      final row = columnIds.map((id) => availableColumns[id]!.getValue(t)).toList();
      rows.add(row);
    }

    // Convert to CSV string
    final csvString = const ListToCsvConverter().convert(rows, fieldDelimiter: delimiter);

    // Add UTF-8 BOM for Excel compatibility
    final bom = '\u{FEFF}';
    final csvWithBom = '$bom$csvString';

    // Save file
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'transactions_custom_$timestamp.csv';
    final filePath = await _saveFile(csvWithBom, fileName, customPath);

    return ExportResult(
      filePath: filePath,
      transactionCount: transactionsWithSplits.length,
      accountCount: accounts.length,
      categoryCount: categories.length,
      format: 'CSV',
    );
  }

  /// Exports using a predefined template.
  Future<ExportResult> exportWithTemplate({
    required ExportFilters filters,
    required CsvColumnTemplate template,
    String? customPath,
  }) async {
    return exportCustomCSV(
      filters: filters,
      columnIds: template.columnIds,
      customPath: customPath,
    );
  }

  /// Gets the list of available column definitions.
  static List<CsvColumnDefinition> getAvailableColumns() {
    return availableColumns.values.toList();
  }

  /// Gets the list of available templates.
  static List<CsvColumnTemplate> getTemplates() {
    return CsvColumnTemplate.all;
  }

  /// Exports column mapping configuration to JSON.
  static String exportColumnMapping(List<String> columnIds) {
    return jsonEncode({'columns': columnIds});
  }

  /// Imports column mapping configuration from JSON.
  static List<String>? importColumnMapping(String json) {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final columns = (data['columns'] as List).cast<String>();
      // Validate
      for (final col in columns) {
        if (!availableColumns.containsKey(col)) {
          return null;
        }
      }
      return columns;
    } catch (e) {
      return null;
    }
  }

  /// Fetches filtered transactions with their splits.
  Future<List<(Transaction, List<Split>)>> _fetchFilteredTransactions(
    ExportFilters filters,
  ) async {
    var query = _db.select(_db.transactions);

    if (!filters.includeDeleted) {
      query = query..where((t) => t.deletedAt.isNull());
    }

    query = query..orderBy([(t) => OrderingTerm.desc(t.postDate)]);

    if (filters.startDate != null) {
      final startMs = DateTime(
        filters.startDate!.year,
        filters.startDate!.month,
        filters.startDate!.day,
      ).millisecondsSinceEpoch;
      query.where((t) => t.postDate.isBiggerOrEqualValue(startMs));
    }

    if (filters.endDate != null) {
      final endMs = DateTime(
        filters.endDate!.year,
        filters.endDate!.month,
        filters.endDate!.day,
        23,
        59,
        59,
        999,
      ).millisecondsSinceEpoch;
      query.where((t) => t.postDate.isSmallerOrEqualValue(endMs));
    }

    final transactions = await query.get();

    final transactionIds = transactions.map((t) => t.id).toList();
    final allSplits = await (_db.select(_db.splits)
          ..where((s) => s.transactionId.isIn(transactionIds)))
        .get();

    final splitsByTransaction = <String, List<Split>>{};
    for (final split in allSplits) {
      splitsByTransaction.putIfAbsent(split.transactionId, () => []).add(split);
    }

    final result = <(Transaction, List<Split>)>[];
    for (final transaction in transactions) {
      var splits = splitsByTransaction[transaction.id] ?? [];

      if (filters.categoryId != null) {
        splits = splits.where((s) => s.categoryId == filters.categoryId).toList();
        if (splits.isEmpty) continue;
      }

      if (filters.accountId != null) {
        splits = splits.where((s) => s.accountId == filters.accountId).toList();
        if (splits.isEmpty) continue;
      }

      result.add((transaction, splits));
    }

    return result;
  }

  /// Saves content to file.
  Future<String> _saveFile(String content, String fileName, String? customPath) async {
    String filePath;

    if (customPath != null) {
      filePath = customPath;
    } else if (Platform.isAndroid || Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      filePath = '${directory.path}/$fileName';
    } else {
      final directory = await getApplicationDocumentsDirectory();
      filePath = '${directory.path}/$fileName';
    }

    final file = File(filePath);
    await file.writeAsString(content, encoding: utf8);

    return filePath;
  }
}
