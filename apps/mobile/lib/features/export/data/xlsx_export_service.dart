import 'dart:io';
import 'dart:typed_data';
import 'package:drift/drift.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:database/database.dart';
import 'export_service.dart';

/// Excel (XLSX) export service for financial data.
///
/// Generates Excel spreadsheets with:
/// - Transaction list with formatting
/// - Summary sheet with totals
/// - Category breakdown sheet
/// - Monthly trend sheet
class XlsxExportService {
  final LocalFinanceDatabase _db;

  XlsxExportService(this._db);

  /// Date formats
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _monthFormat = DateFormat('yyyy-MM');

  /// Exports transactions to Excel format.
  Future<XlsxExportResult> exportToXLSX({
    required ExportFilters filters,
    bool includeSummary = true,
    bool includeCategoryBreakdown = true,
    bool includeMonthlyTrend = true,
    String? customPath,
  }) async {
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

    // Create Excel document
    final excel = Excel.createExcel();

    // Remove default sheet
    excel.delete('Sheet1');

    // Create Transactions sheet
    final transactionSheet = excel['交易记录'];
    _buildTransactionSheet(
      transactionSheet,
      transactionsWithSplits,
      accountMap,
      categoryMap,
      commodityMap,
    );

    // Create Summary sheet
    if (includeSummary) {
      final summarySheet = excel['汇总'];
      _buildSummarySheet(
        summarySheet,
        transactionsWithSplits,
        categoryMap,
        filters,
      );
    }

    // Create Category Breakdown sheet
    if (includeCategoryBreakdown) {
      final categorySheet = excel['分类明细'];
      _buildCategorySheet(
        categorySheet,
        transactionsWithSplits,
        categoryMap,
      );
    }

    // Create Monthly Trend sheet
    if (includeMonthlyTrend) {
      final trendSheet = excel['月度趋势'];
      _buildMonthlyTrendSheet(
        trendSheet,
        transactionsWithSplits,
      );
    }

    // Save file
    final bytes = excel.encode();
    if (bytes == null) {
      throw ExportException('生成Excel文件失败');
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'transactions_$timestamp.xlsx';
    final filePath = await _saveFile(bytes, fileName, customPath);

    return XlsxExportResult(
      filePath: filePath,
      transactionCount: transactionsWithSplits.length,
      accountCount: accounts.length,
      categoryCount: categories.length,
      sheetCount: excel.sheets.length,
    );
  }

  /// Builds the main transaction sheet.
  void _buildTransactionSheet(
    Sheet sheet,
    List<(Transaction, List<Split>)> transactionsWithSplits,
    Map<String, Account> accountMap,
    Map<String, Category> categoryMap,
    Map<String, Commodity> commodityMap,
  ) {
    // Headers
    final headers = ['日期', '描述', '账户', '分类', '金额', '货币', '备注', '录入时间'];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByString('${_getColumnName(i)}1'));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
      );
    }

    // Data rows
    var rowNum = 2;
    for (final (transaction, splits) in transactionsWithSplits) {
      for (final split in splits) {
        final account = accountMap[split.accountId];
        final category = split.categoryId != null ? categoryMap[split.categoryId] : null;
        final commodity = commodityMap[transaction.currencyId];
        final amount = split.valueNum / split.valueDenom.toDouble();
        final postDate = DateTime.fromMillisecondsSinceEpoch(transaction.postDate);
        final enterDate = DateTime.fromMillisecondsSinceEpoch(transaction.enterDate);

        // Date
        sheet.cell(CellIndex.indexByString('A$rowNum')).value = 
            TextCellValue(_dateFormat.format(postDate));
        
        // Description
        sheet.cell(CellIndex.indexByString('B$rowNum')).value = 
            TextCellValue(transaction.description ?? '');
        
        // Account
        sheet.cell(CellIndex.indexByString('C$rowNum')).value = 
            TextCellValue(account?.name ?? '');
        
        // Category
        sheet.cell(CellIndex.indexByString('D$rowNum')).value = 
            TextCellValue(category?.name ?? '');
        
        // Amount
        final amountCell = sheet.cell(CellIndex.indexByString('E$rowNum'));
        amountCell.value = DoubleCellValue(amount);
        amountCell.cellStyle = CellStyle(
          fontColorHex: amount >= 0 ? ExcelColor.green : ExcelColor.red,
        );
        
        // Currency
        sheet.cell(CellIndex.indexByString('F$rowNum')).value = 
            TextCellValue(commodity?.mnemonic ?? 'CNY');
        
        // Notes
        sheet.cell(CellIndex.indexByString('G$rowNum')).value = 
            TextCellValue(transaction.notes ?? '');
        
        // Enter date
        sheet.cell(CellIndex.indexByString('H$rowNum')).value = 
            TextCellValue(_dateFormat.format(enterDate));

        rowNum++;
      }
    }

    // Auto-fit columns (approximate)
    sheet.setColWidth(1, 12);  // Date
    sheet.setColWidth(2, 30);  // Description
    sheet.setColWidth(3, 15);  // Account
    sheet.setColWidth(4, 15);  // Category
    sheet.setColWidth(5, 12);  // Amount
    sheet.setColWidth(6, 8);   // Currency
    sheet.setColWidth(7, 25);  // Notes
    sheet.setColWidth(8, 12);  // Enter date
  }

  /// Builds the summary sheet.
  void _buildSummarySheet(
    Sheet sheet,
    List<(Transaction, List<Split>)> transactionsWithSplits,
    Map<String, Category> categoryMap,
    ExportFilters filters,
  ) {
    // Calculate summary
    double totalIncome = 0;
    double totalExpense = 0;

    for (final (transaction, splits) in transactionsWithSplits) {
      for (final split in splits) {
        final amount = split.valueNum / split.valueDenom.toDouble();
        final category = split.categoryId != null ? categoryMap[split.categoryId] : null;

        if (category != null && category.isIncome) {
          totalIncome += amount.abs();
        } else {
          totalExpense += amount.abs();
        }
      }
    }

    // Title
    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('财务汇总报告');
    titleCell.cellStyle = CellStyle(bold: true, fontSize: 16);

    // Date range
    String dateRangeText;
    if (filters.startDate != null && filters.endDate != null) {
      dateRangeText = '${_dateFormat.format(filters.startDate!)} - ${_dateFormat.format(filters.endDate!)}';
    } else if (filters.startDate != null) {
      dateRangeText = '${_dateFormat.format(filters.startDate!)} - 至今';
    } else if (filters.endDate != null) {
      dateRangeText = '截至 ${_dateFormat.format(filters.endDate!)}';
    } else {
      dateRangeText = '全部时间';
    }

    sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('日期范围:');
    sheet.cell(CellIndex.indexByString('B3')).value = TextCellValue(dateRangeText);

    sheet.cell(CellIndex.indexByString('A5')).value = TextCellValue('生成时间:');
    sheet.cell(CellIndex.indexByString('B5')).value = 
        TextCellValue(_dateFormat.format(DateTime.now()));

    // Summary data
    sheet.cell(CellIndex.indexByString('A7')).value = TextCellValue('收入合计');
    final incomeCell = sheet.cell(CellIndex.indexByString('B7'));
    incomeCell.value = DoubleCellValue(totalIncome);
    incomeCell.cellStyle = CellStyle(fontColorHex: ExcelColor.green);

    sheet.cell(CellIndex.indexByString('A8')).value = TextCellValue('支出合计');
    final expenseCell = sheet.cell(CellIndex.indexByString('B8'));
    expenseCell.value = DoubleCellValue(totalExpense);
    expenseCell.cellStyle = CellStyle(fontColorHex: ExcelColor.red);

    sheet.cell(CellIndex.indexByString('A9')).value = TextCellValue('净收入');
    final netCell = sheet.cell(CellIndex.indexByString('B9'));
    netCell.value = DoubleCellValue(totalIncome - totalExpense);
    netCell.cellStyle = CellStyle(
      bold: true,
      fontColorHex: totalIncome >= totalExpense ? ExcelColor.green : ExcelColor.red,
    );

    // Transaction count
    sheet.cell(CellIndex.indexByString('A11')).value = TextCellValue('交易笔数');
    sheet.cell(CellIndex.indexByString('B11')).value = 
        IntCellValue(transactionsWithSplits.length);

    // Set column widths
    sheet.setColWidth(1, 15);
    sheet.setColWidth(2, 30);
  }

  /// Builds the category breakdown sheet.
  void _buildCategorySheet(
    Sheet sheet,
    List<(Transaction, List<Split>)> transactionsWithSplits,
    Map<String, Category> categoryMap,
  ) {
    // Calculate category breakdown
    final categoryTotals = <String, _CategoryStats>{};
    double totalIncome = 0;
    double totalExpense = 0;

    for (final (transaction, splits) in transactionsWithSplits) {
      for (final split in splits) {
        final amount = split.valueNum / split.valueDenom.toDouble();
        final category = split.categoryId != null ? categoryMap[split.categoryId] : null;

        if (category != null) {
          final stats = categoryTotals[category.id] ?? _CategoryStats(
            name: category.name,
            isIncome: category.isIncome,
          );
          stats.amount += amount.abs();
          stats.count++;
          categoryTotals[category.id] = stats;

          if (category.isIncome) {
            totalIncome += amount.abs();
          } else {
            totalExpense += amount.abs();
          }
        }
      }
    }

    // Headers
    final headers = ['分类', '类型', '金额', '占比', '笔数'];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByString('${_getColumnName(i)}1'));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
      );
    }

    // Data rows
    var rowNum = 2;
    
    // Sort by amount descending
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.amount.compareTo(a.value.amount));

    for (final entry in sortedCategories) {
      final stats = entry.value;
      final total = stats.isIncome ? totalIncome : totalExpense;
      final percentage = total > 0 ? (stats.amount / total) * 100 : 0.0;

      sheet.cell(CellIndex.indexByString('A$rowNum')).value = 
          TextCellValue(stats.name);
      
      sheet.cell(CellIndex.indexByString('B$rowNum')).value = 
          TextCellValue(stats.isIncome ? '收入' : '支出');
      
      final amountCell = sheet.cell(CellIndex.indexByString('C$rowNum'));
      amountCell.value = DoubleCellValue(stats.amount);
      amountCell.cellStyle = CellStyle(
        fontColorHex: stats.isIncome ? ExcelColor.green : ExcelColor.red,
      );
      
      sheet.cell(CellIndex.indexByString('D$rowNum')).value = 
          TextCellValue('${percentage.toStringAsFixed(1)}%');
      
      sheet.cell(CellIndex.indexByString('E$rowNum')).value = 
          IntCellValue(stats.count);

      rowNum++;
    }

    // Set column widths
    sheet.setColWidth(1, 20);
    sheet.setColWidth(2, 10);
    sheet.setColWidth(3, 12);
    sheet.setColWidth(4, 10);
    sheet.setColWidth(5, 8);
  }

  /// Builds the monthly trend sheet.
  void _buildMonthlyTrendSheet(
    Sheet sheet,
    List<(Transaction, List<Split>)> transactionsWithSplits,
  ) {
    // Calculate monthly data
    final monthlyData = <String, _MonthlyStats>{};

    for (final (transaction, splits) in transactionsWithSplits) {
      final postDate = DateTime.fromMillisecondsSinceEpoch(transaction.postDate);
      final monthKey = _monthFormat.format(postDate);

      final stats = monthlyData[monthKey] ?? _MonthlyStats(month: monthKey);

      for (final split in splits) {
        final amount = split.valueNum / split.valueDenom.toDouble();
        if (amount >= 0) {
          stats.income += amount;
        } else {
          stats.expense += amount.abs();
        }
      }

      monthlyData[monthKey] = stats;
    }

    // Headers
    final headers = ['月份', '收入', '支出', '净收入'];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByString('${_getColumnName(i)}1'));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
      );
    }

    // Data rows
    var rowNum = 2;
    
    // Sort by month ascending
    final sortedMonths = monthlyData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in sortedMonths) {
      final stats = entry.value;

      sheet.cell(CellIndex.indexByString('A$rowNum')).value = 
          TextCellValue(stats.month);
      
      final incomeCell = sheet.cell(CellIndex.indexByString('B$rowNum'));
      incomeCell.value = DoubleCellValue(stats.income);
      incomeCell.cellStyle = CellStyle(fontColorHex: ExcelColor.green);
      
      final expenseCell = sheet.cell(CellIndex.indexByString('C$rowNum'));
      expenseCell.value = DoubleCellValue(stats.expense);
      expenseCell.cellStyle = CellStyle(fontColorHex: ExcelColor.red);
      
      final netCell = sheet.cell(CellIndex.indexByString('D$rowNum'));
      netCell.value = DoubleCellValue(stats.net);
      netCell.cellStyle = CellStyle(
        fontColorHex: stats.net >= 0 ? ExcelColor.green : ExcelColor.red,
      );

      rowNum++;
    }

    // Set column widths
    sheet.setColWidth(1, 12);
    sheet.setColWidth(2, 12);
    sheet.setColWidth(3, 12);
    sheet.setColWidth(4, 12);
  }

  /// Gets column name by index (A, B, C, ..., Z, AA, AB, ...)
  String _getColumnName(int index) {
    if (index < 26) {
      return String.fromCharCode(65 + index);
    }
    final first = (index ~/ 26) - 1;
    final second = index % 26;
    return '${String.fromCharCode(65 + first)}${String.fromCharCode(65 + second)}';
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

  /// Saves Excel file.
  Future<String> _saveFile(Uint8List bytes, String fileName, String? customPath) async {
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
    await file.writeAsBytes(bytes);

    return filePath;
  }
}

/// Category statistics helper class.
class _CategoryStats {
  final String name;
  final bool isIncome;
  double amount;
  int count;

  _CategoryStats({
    required this.name,
    required this.isIncome,
    this.amount = 0,
    this.count = 0,
  });
}

/// Monthly statistics helper class.
class _MonthlyStats {
  final String month;
  double income;
  double expense;

  _MonthlyStats({
    required this.month,
    this.income = 0,
    this.expense = 0,
  });

  double get net => income - expense;
}

/// Result of XLSX export operation.
class XlsxExportResult {
  final String filePath;
  final int transactionCount;
  final int accountCount;
  final int categoryCount;
  final int sheetCount;

  XlsxExportResult({
    required this.filePath,
    required this.transactionCount,
    required this.accountCount,
    required this.categoryCount,
    required this.sheetCount,
  });
}
