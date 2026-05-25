import 'dart:io';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:database/database.dart';
import 'export_service.dart';

/// Excel (HTML-based) export service for financial data.
///
/// Generates HTML files that Excel can open, with:
/// - Transaction list with formatting
/// - Color-coded amounts
/// - Summary section
///
/// Note: For full XLSX support, consider using the `excel` package
/// when dependency conflicts are resolved.
class XlsxExportService {
  final LocalFinanceDatabase _db;

  XlsxExportService(this._db);

  /// Date formats
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _monthFormat = DateFormat('yyyy-MM');

  /// Exports transactions to Excel-compatible HTML format.
  ///
  /// This generates an HTML file with a table that Excel can open
  /// and save as XLSX if needed.
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

    // Calculate summary data
    double totalIncome = 0;
    double totalExpense = 0;
    final categoryTotals = <String, _CategoryStats>{};
    final monthlyData = <String, _MonthlyStats>{};

    for (final (transaction, splits) in transactionsWithSplits) {
      final postDate = DateTime.fromMillisecondsSinceEpoch(transaction.postDate);
      final monthKey = _monthFormat.format(postDate);
      final monthStats = monthlyData[monthKey] ?? _MonthlyStats(month: monthKey);

      for (final split in splits) {
        final amount = split.valueNum / split.valueDenom.toDouble();
        final category = split.categoryId != null ? categoryMap[split.categoryId] : null;

        if (category != null && category.isIncome) {
          totalIncome += amount.abs();
          monthStats.income += amount.abs();
        } else {
          totalExpense += amount.abs();
          monthStats.expense += amount.abs();
        }

        // Category totals
        if (category != null) {
          final stats = categoryTotals[category.id] ?? _CategoryStats(
            name: category.name,
            isIncome: category.isIncome,
          );
          stats.amount += amount.abs();
          stats.count++;
          categoryTotals[category.id] = stats;
        }

        if (amount >= 0) {
          monthStats.income += amount;
        } else {
          monthStats.expense += amount.abs();
        }
      }
      monthlyData[monthKey] = monthStats;
    }

    // Build HTML content
    final htmlContent = _buildHtmlContent(
      transactionsWithSplits: transactionsWithSplits,
      accountMap: accountMap,
      categoryMap: categoryMap,
      commodityMap: commodityMap,
      filters: filters,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      categoryTotals: categoryTotals,
      monthlyData: monthlyData,
      includeSummary: includeSummary,
      includeCategoryBreakdown: includeCategoryBreakdown,
      includeMonthlyTrend: includeMonthlyTrend,
    );

    // Save file
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'transactions_$timestamp.xls'; // .xls extension for Excel
    final filePath = await _saveFile(htmlContent, fileName, customPath);

    return XlsxExportResult(
      filePath: filePath,
      transactionCount: transactionsWithSplits.length,
      accountCount: accounts.length,
      categoryCount: categories.length,
      sheetCount: 1,
    );
  }

  /// Builds HTML content that Excel can open.
  String _buildHtmlContent({
    required List<(Transaction, List<Split>)> transactionsWithSplits,
    required Map<String, Account> accountMap,
    required Map<String, Category> categoryMap,
    required Map<String, Commodity> commodityMap,
    required ExportFilters filters,
    required double totalIncome,
    required double totalExpense,
    required Map<String, _CategoryStats> categoryTotals,
    required Map<String, _MonthlyStats> monthlyData,
    required bool includeSummary,
    required bool includeCategoryBreakdown,
    required bool includeMonthlyTrend,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<?mso-application progid="Excel.Sheet"?>');
    buffer.writeln('<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns="http://www.w3.org/TR/REC-html40">');
    buffer.writeln('<head>');
    buffer.writeln('<meta charset="UTF-8">');
    buffer.writeln('<style>');
    buffer.writeln('.header { background-color: #4472C4; color: white; font-weight: bold; }');
    buffer.writeln('.income { color: #00B050; }');
    buffer.writeln('.expense { color: #FF0000; }');
    buffer.writeln('.title { font-size: 16pt; font-weight: bold; }');
    buffer.writeln('.section { font-size: 12pt; font-weight: bold; margin-top: 20px; }');
    buffer.writeln('table { border-collapse: collapse; width: 100%; }');
    buffer.writeln('td, th { border: 1px solid #000000; padding: 5px; }');
    buffer.writeln('</style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');

    // Summary section
    if (includeSummary) {
      buffer.writeln('<p class="title">财务汇总报告</p>');

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

      buffer.writeln('<p>日期范围: $dateRangeText</p>');
      buffer.writeln('<p>生成时间: ${_dateFormat.format(DateTime.now())}</p>');
      buffer.writeln('<table>');
      buffer.writeln('<tr><td>收入合计</td><td class="income">${totalIncome.toStringAsFixed(2)}</td></tr>');
      buffer.writeln('<tr><td>支出合计</td><td class="expense">${totalExpense.toStringAsFixed(2)}</td></tr>');
      buffer.writeln('<tr><td>净收入</td><td class="${totalIncome >= totalExpense ? 'income' : 'expense'}">${(totalIncome - totalExpense).toStringAsFixed(2)}</td></tr>');
      buffer.writeln('<tr><td>交易笔数</td><td>${transactionsWithSplits.length}</td></tr>');
      buffer.writeln('</table>');
      buffer.writeln('<br/>');
    }

    // Category breakdown
    if (includeCategoryBreakdown && categoryTotals.isNotEmpty) {
      buffer.writeln('<p class="section">分类明细</p>');
      buffer.writeln('<table>');
      buffer.writeln('<tr class="header"><td>分类</td><td>类型</td><td>金额</td><td>笔数</td></tr>');

      final sortedCategories = categoryTotals.entries.toList()
        ..sort((a, b) => b.value.amount.compareTo(a.value.amount));

      for (final entry in sortedCategories) {
        final stats = entry.value;
        buffer.writeln('<tr>');
        buffer.writeln('<td>${_escapeHtml(stats.name)}</td>');
        buffer.writeln('<td>${stats.isIncome ? '收入' : '支出'}</td>');
        buffer.writeln('<td class="${stats.isIncome ? 'income' : 'expense'}">${stats.amount.toStringAsFixed(2)}</td>');
        buffer.writeln('<td>${stats.count}</td>');
        buffer.writeln('</tr>');
      }
      buffer.writeln('</table>');
      buffer.writeln('<br/>');
    }

    // Monthly trend
    if (includeMonthlyTrend && monthlyData.isNotEmpty) {
      buffer.writeln('<p class="section">月度趋势</p>');
      buffer.writeln('<table>');
      buffer.writeln('<tr class="header"><td>月份</td><td>收入</td><td>支出</td><td>净收入</td></tr>');

      final sortedMonths = monthlyData.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      for (final entry in sortedMonths) {
        final stats = entry.value;
        buffer.writeln('<tr>');
        buffer.writeln('<td>${stats.month}</td>');
        buffer.writeln('<td class="income">${stats.income.toStringAsFixed(2)}</td>');
        buffer.writeln('<td class="expense">${stats.expense.toStringAsFixed(2)}</td>');
        buffer.writeln('<td class="${stats.net >= 0 ? 'income' : 'expense'}">${stats.net.toStringAsFixed(2)}</td>');
        buffer.writeln('</tr>');
      }
      buffer.writeln('</table>');
      buffer.writeln('<br/>');
    }

    // Transaction details
    buffer.writeln('<p class="section">交易明细</p>');
    buffer.writeln('<table>');
    buffer.writeln('<tr class="header"><td>日期</td><td>描述</td><td>账户</td><td>分类</td><td>金额</td><td>货币</td><td>备注</td></tr>');

    for (final (transaction, splits) in transactionsWithSplits) {
      for (final split in splits) {
        final account = accountMap[split.accountId];
        final category = split.categoryId != null ? categoryMap[split.categoryId] : null;
        final commodity = commodityMap[transaction.currencyId];
        final amount = split.valueNum / split.valueDenom.toDouble();
        final postDate = DateTime.fromMillisecondsSinceEpoch(transaction.postDate);

        buffer.writeln('<tr>');
        buffer.writeln('<td>${_dateFormat.format(postDate)}</td>');
        buffer.writeln('<td>${_escapeHtml(transaction.description ?? '')}</td>');
        buffer.writeln('<td>${_escapeHtml(account?.name ?? '')}</td>');
        buffer.writeln('<td>${_escapeHtml(category?.name ?? '')}</td>');
        buffer.writeln('<td class="${amount >= 0 ? 'income' : 'expense'}">${amount.toStringAsFixed(2)}</td>');
        buffer.writeln('<td>${commodity?.mnemonic ?? 'CNY'}</td>');
        buffer.writeln('<td>${_escapeHtml(transaction.notes ?? '')}</td>');
        buffer.writeln('</tr>');
      }
    }

    buffer.writeln('</table>');
    buffer.writeln('</body>');
    buffer.writeln('</html>');

    return buffer.toString();
  }

  /// Escapes HTML special characters.
  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
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
    await file.writeAsString(content);

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
