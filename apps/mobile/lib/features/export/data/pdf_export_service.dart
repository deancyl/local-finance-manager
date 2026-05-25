import 'dart:io';
import 'dart:typed_data';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:database/database.dart' as db;
import 'package:core/core.dart' hide Transaction, Split;
import 'package:decimal/decimal.dart';
import 'export_service.dart';
import '../../print/data/print_service.dart';

/// PDF export service for financial reports.
///
/// Generates PDF reports with:
/// - Income/Expense Summary
/// - Category Breakdown
/// - Monthly Trend Chart
class PdfExportService {
  final db.LocalFinanceDatabase _db;

  PdfExportService(this._db);

  /// Date formats
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _monthFormat = DateFormat('yyyy-MM');
  static final DateFormat _displayFormat = DateFormat('yyyy-MM-dd');

  /// Exports financial report to PDF format.
  Future<PdfExportResult> exportToPDF({
    required ExportFilters filters,
    String? customPath,
  }) async {
    // Fetch transactions with splits
    final transactionsWithSplits = await _fetchFilteredTransactions(filters);

    if (transactionsWithSplits.isEmpty) {
      throw ExportException('No transactions to export');
    }

    // Fetch reference data
    final accounts = await _db.select(_db.accounts).get();
    final categories = await _db.select(_db.categories).get();
    final commodities = await _db.select(_db.commodities).get();

    final accountMap = {for (var a in accounts) a.id: a};
    final categoryMap = {for (var c in categories) c.id: c};
    final commodityMap = {for (var c in commodities) c.id: c};

    // Calculate summary data
    final summary = _calculateSummary(transactionsWithSplits, categoryMap);
    final categoryBreakdown = _calculateCategoryBreakdown(
      transactionsWithSplits,
      categoryMap,
    );
    final monthlyTrend = _calculateMonthlyTrend(transactionsWithSplits);

    // Generate PDF
    final pdfBytes = await _generatePdf(
      filters: filters,
      summary: summary,
      categoryBreakdown: categoryBreakdown,
      monthlyTrend: monthlyTrend,
      transactionsWithSplits: transactionsWithSplits,
      accountMap: accountMap,
      categoryMap: categoryMap,
      commodityMap: commodityMap,
    );

    // Save file
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'financial_report_$timestamp.pdf';
    final filePath = await _savePdfFile(pdfBytes, fileName, customPath);

    return PdfExportResult(
      filePath: filePath,
      transactionCount: transactionsWithSplits.length,
      accountCount: accounts.length,
      categoryCount: categories.length,
      totalIncome: summary['income'] ?? 0.0,
      totalExpense: summary['expense'] ?? 0.0,
      netAmount: summary['net'] ?? 0.0,
    );
  }

  /// Generates the PDF document.
  Future<Uint8List> _generatePdf({
    required ExportFilters filters,
    required Map<String, double> summary,
    required List<CategoryBreakdown> categoryBreakdown,
    required List<MonthlyData> monthlyTrend,
    required List<(db.Transaction, List<db.Split>)> transactionsWithSplits,
    required Map<String, db.Account> accountMap,
    required Map<String, db.Category> categoryMap,
    required Map<String, db.Commodity> commodityMap,
  }) async {
    final pdf = pw.Document();

    // Determine date range text
    String dateRangeText;
    if (filters.startDate != null && filters.endDate != null) {
      dateRangeText =
          '${_displayFormat.format(filters.startDate!)} - ${_displayFormat.format(filters.endDate!)}';
    } else if (filters.startDate != null) {
      dateRangeText = '${_displayFormat.format(filters.startDate!)} - Present';
    } else if (filters.endDate != null) {
      dateRangeText = 'Until ${_displayFormat.format(filters.endDate!)}';
    } else {
      dateRangeText = 'All Time';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Title
            pw.Center(
              child: pw.Text(
                'Financial Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            // Date range
            pw.Center(
              child: pw.Text(
                dateRangeText,
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            // Generated date
            pw.Center(
              child: pw.Text(
                'Generated: ${_displayFormat.format(DateTime.now())}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey500,
                ),
              ),
            ),
            pw.SizedBox(height: 24),

            // Summary Section
            pw.Text(
              'Summary',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            _buildSummaryTable(summary),
            pw.SizedBox(height: 24),

            // Category Breakdown Section
            pw.Text(
              'Category Breakdown',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            _buildCategoryBreakdownTable(categoryBreakdown),
            pw.SizedBox(height: 24),

            // Monthly Trend Section
            if (monthlyTrend.isNotEmpty) ...[
              pw.Text(
                'Monthly Trend',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              _buildMonthlyTrendTable(monthlyTrend),
              pw.SizedBox(height: 24),
            ],

            // Transaction Details Section
            pw.Text(
              'Transaction Details',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            ..._buildTransactionRows(
              transactionsWithSplits,
              accountMap,
              categoryMap,
              commodityMap,
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey500,
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Builds the summary table.
  pw.Widget _buildSummaryTable(Map<String, double> summary) {
    final income = summary['income'] ?? 0.0;
    final expense = summary['expense'] ?? 0.0;
    final net = summary['net'] ?? 0.0;

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('Item', isHeader: true),
            _buildTableCell('Amount (CNY)', isHeader: true),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Total Income'),
            _buildTableCell(
              '+${income.toStringAsFixed(2)}',
              textColor: PdfColors.green700,
            ),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Total Expense'),
            _buildTableCell(
              '-${expense.toStringAsFixed(2)}',
              textColor: PdfColors.red700,
            ),
          ],
        ),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _buildTableCell('Net', isBold: true),
            _buildTableCell(
              '${net >= 0 ? '+' : ''}${net.toStringAsFixed(2)}',
              isBold: true,
              textColor: net >= 0 ? PdfColors.green700 : PdfColors.red700,
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the category breakdown table.
  pw.Widget _buildCategoryBreakdownTable(List<CategoryBreakdown> breakdown) {
    if (breakdown.isEmpty) {
      return pw.Text(
        'No category data',
        style: pw.TextStyle(fontSize: 12, color: PdfColors.grey500),
      );
    }

    final incomeCategories = breakdown.where((c) => c.isIncome).toList();
    final expenseCategories = breakdown.where((c) => !c.isIncome).toList();

    final rows = <pw.TableRow>[];

    // Header
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _buildTableCell('Category', isHeader: true),
          _buildTableCell('Type', isHeader: true),
          _buildTableCell('Amount', isHeader: true),
          _buildTableCell('Percent', isHeader: true),
          _buildTableCell('Count', isHeader: true),
        ],
      ),
    );

    // Income categories
    if (incomeCategories.isNotEmpty) {
      for (final cat in incomeCategories) {
        rows.add(
          pw.TableRow(
            children: [
              _buildTableCell(cat.name),
              _buildTableCell('Income'),
              _buildTableCell(
                '+${cat.amount.toStringAsFixed(2)}',
                textColor: PdfColors.green700,
              ),
              _buildTableCell('${cat.percentage.toStringAsFixed(1)}%'),
              _buildTableCell('${cat.count}'),
            ],
          ),
        );
      }
    }

    // Expense categories
    if (expenseCategories.isNotEmpty) {
      for (final cat in expenseCategories) {
        rows.add(
          pw.TableRow(
            children: [
              _buildTableCell(cat.name),
              _buildTableCell('Expense'),
              _buildTableCell(
                '-${cat.amount.toStringAsFixed(2)}',
                textColor: PdfColors.red700,
              ),
              _buildTableCell('${cat.percentage.toStringAsFixed(1)}%'),
              _buildTableCell('${cat.count}'),
            ],
          ),
        );
      }
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(1),
      },
      children: rows,
    );
  }

  /// Builds the monthly trend table.
  pw.Widget _buildMonthlyTrendTable(List<MonthlyData> monthlyTrend) {
    final rows = <pw.TableRow>[];

    // Header
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _buildTableCell('Month', isHeader: true),
          _buildTableCell('Income', isHeader: true),
          _buildTableCell('Expense', isHeader: true),
          _buildTableCell('Net', isHeader: true),
        ],
      ),
    );

    for (final month in monthlyTrend) {
      rows.add(
        pw.TableRow(
          children: [
            _buildTableCell(month.month),
            _buildTableCell(
              '+${month.income.toStringAsFixed(2)}',
              textColor: PdfColors.green700,
            ),
            _buildTableCell(
              '-${month.expense.toStringAsFixed(2)}',
              textColor: PdfColors.red700,
            ),
            _buildTableCell(
              '${month.net >= 0 ? '+' : ''}${month.net.toStringAsFixed(2)}',
              textColor: month.net >= 0 ? PdfColors.green700 : PdfColors.red700,
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
      children: rows,
    );
  }

  /// Builds transaction rows.
  List<pw.Widget> _buildTransactionRows(
    List<(db.Transaction, List<db.Split>)> transactionsWithSplits,
    Map<String, db.Account> accountMap,
    Map<String, db.Category> categoryMap,
    Map<String, db.Commodity> commodityMap,
  ) {
    final widgets = <pw.Widget>[];

    // Header row
    widgets.add(
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: {
          0: const pw.FlexColumnWidth(2), // Date
          1: const pw.FlexColumnWidth(3), // Description
          2: const pw.FlexColumnWidth(2), // Category
          3: const pw.FlexColumnWidth(2), // Account
          4: const pw.FlexColumnWidth(2), // Amount
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _buildTableCell('Date', isHeader: true),
              _buildTableCell('Description', isHeader: true),
              _buildTableCell('Category', isHeader: true),
              _buildTableCell('Account', isHeader: true),
              _buildTableCell('Amount', isHeader: true),
            ],
          ),
          ...transactionsWithSplits.expand((tuple) {
            final (transaction, splits) = tuple;
            return splits.map((split) {
              final account = accountMap[split.accountId];
              final category = split.categoryId != null ? categoryMap[split.categoryId] : null;
              final amount = split.valueNum / split.valueDenom.toDouble();
              final date = DateTime.fromMillisecondsSinceEpoch(transaction.postDate);

              return pw.TableRow(
                children: [
                  _buildTableCell(_dateFormat.format(date)),
                  _buildTableCell(transaction.description ?? ''),
                  _buildTableCell(category?.name ?? ''),
                  _buildTableCell(account?.name ?? ''),
                  _buildTableCell(
                    amount >= 0 ? '+${amount.toStringAsFixed(2)}' : amount.toStringAsFixed(2),
                    textColor: amount >= 0 ? PdfColors.green700 : PdfColors.red700,
                  ),
                ],
              );
            });
          }),
        ],
      ),
    );

    return widgets;
  }

  /// Helper to build a table cell.
  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    PdfColor textColor = PdfColors.black,
    int colSpan = 1,
    bool alignRight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor,
        ),
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  /// Calculates summary totals.
  Map<String, double> _calculateSummary(
    List<(db.Transaction, List<db.Split>)> transactionsWithSplits,
    Map<String, db.Category> categoryMap,
  ) {
    double income = 0;
    double expense = 0;

    for (final (transaction, splits) in transactionsWithSplits) {
      for (final split in splits) {
        final amount = split.valueNum / split.valueDenom.toDouble();
        final category = split.categoryId != null ? categoryMap[split.categoryId] : null;

        if (category != null && category.isIncome) {
          income += amount.abs();
        } else {
          expense += amount.abs();
        }
      }
    }

    return {
      'income': income,
      'expense': expense,
      'net': income - expense,
    };
  }

  /// Calculates category breakdown.
  List<CategoryBreakdown> _calculateCategoryBreakdown(
    List<(db.Transaction, List<db.Split>)> transactionsWithSplits,
    Map<String, db.Category> categoryMap,
  ) {
    final breakdown = <String, CategoryBreakdown>{};
    double totalIncome = 0;
    double totalExpense = 0;

    for (final (transaction, splits) in transactionsWithSplits) {
      for (final split in splits) {
        final amount = split.valueNum / split.valueDenom.toDouble();
        final category = split.categoryId != null ? categoryMap[split.categoryId] : null;

        if (category != null) {
          final existing = breakdown[category.id];
          if (existing != null) {
            breakdown[category.id] = CategoryBreakdown(
              id: category.id,
              name: category.name,
              isIncome: category.isIncome,
              amount: existing.amount + amount.abs(),
              count: existing.count + 1,
            );
          } else {
            breakdown[category.id] = CategoryBreakdown(
              id: category.id,
              name: category.name,
              isIncome: category.isIncome,
              amount: amount.abs(),
              count: 1,
            );
          }

          if (category.isIncome) {
            totalIncome += amount.abs();
          } else {
            totalExpense += amount.abs();
          }
        }
      }
    }

    // Calculate percentages
    return breakdown.values.map((cat) {
      final total = cat.isIncome ? totalIncome : totalExpense;
      return CategoryBreakdown(
        id: cat.id,
        name: cat.name,
        isIncome: cat.isIncome,
        amount: cat.amount,
        percentage: total > 0 ? (cat.amount / total) * 100 : 0,
        count: cat.count,
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  /// Calculates monthly trend.
  List<MonthlyData> _calculateMonthlyTrend(
    List<(db.Transaction, List<db.Split>)> transactionsWithSplits,
  ) {
    final monthlyData = <String, MonthlyData>{};

    for (final (transaction, splits) in transactionsWithSplits) {
      final date = DateTime.fromMillisecondsSinceEpoch(transaction.postDate);
      final monthKey = _monthFormat.format(date);

      final existing = monthlyData[monthKey] ?? MonthlyData(
        month: monthKey,
        income: 0,
        expense: 0,
      );

      for (final split in splits) {
        final amount = split.valueNum / split.valueDenom.toDouble();
        if (amount >= 0) {
          monthlyData[monthKey] = MonthlyData(
            month: monthKey,
            income: existing.income + amount,
            expense: existing.expense,
          );
        } else {
          monthlyData[monthKey] = MonthlyData(
            month: monthKey,
            income: existing.income,
            expense: existing.expense + amount.abs(),
          );
        }
      }
    }

    return monthlyData.values.toList()
      ..sort((a, b) => a.month.compareTo(b.month));
  }

  /// Fetches filtered transactions with their splits.
  Future<List<(db.Transaction, List<db.Split>)>> _fetchFilteredTransactions(
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

    final splitsByTransaction = <String, List<db.Split>>{};
    for (final split in allSplits) {
      splitsByTransaction.putIfAbsent(split.transactionId, () => []).add(split);
    }

    final result = <(db.Transaction, List<db.Split>)>[];
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

  /// Saves PDF file.
  Future<String> _savePdfFile(Uint8List bytes, String fileName, String? customPath) async {
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

  /// Exports balance sheet to PDF format.
  Future<PdfExportResult> exportBalanceSheetToPDF({
    required BalanceSheet balanceSheet,
    String? customPath,
  }) async {
    // Generate PDF
    final pdfBytes = await _generateBalanceSheetPdf(balanceSheet);

    // Save file
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final dateStr = _dateFormat.format(balanceSheet.asOfDate);
    final fileName = 'balance_sheet_$dateStr\_$timestamp.pdf';
    final filePath = await _savePdfFile(pdfBytes, fileName, customPath);

    return PdfExportResult(
      filePath: filePath,
      bytes: pdfBytes,
      transactionCount: 0,
      accountCount: balanceSheet.assets.items.length +
          balanceSheet.liabilities.items.length +
          balanceSheet.equity.items.length,
      categoryCount: 0,
      totalIncome: 0,
      totalExpense: 0,
      netAmount: 0,
    );
  }

  /// Exports balance sheet to PDF bytes (for printing).
  Future<Uint8List> exportBalanceSheetToPDFBytes({
    required BalanceSheet balanceSheet,
    PageSetup? pageSetup,
  }) async {
    return await _generateBalanceSheetPdf(balanceSheet, pageSetup: pageSetup);
  }

  /// Exports income statement to PDF bytes (for printing).
  Future<Uint8List> exportIncomeStatementToPDFBytes({
    required IncomeStatement incomeStatement,
    PageSetup? pageSetup,
  }) async {
    return await _generateIncomeStatementPdf(incomeStatement, pageSetup: pageSetup);
  }

  /// Generates the balance sheet PDF document.
  Future<Uint8List> _generateBalanceSheetPdf(
    BalanceSheet balanceSheet, {
    PageSetup? pageSetup,
  }) async {
    final pdf = pw.Document();
    final setup = pageSetup ?? const PageSetup();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: setup.effectiveFormat,
        margin: setup.margins,
        build: (pw.Context context) {
          return [
            // Title
            pw.Center(
              child: pw.Text(
                '资产负债表',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            // As of date
            pw.Center(
              child: pw.Text(
                '截止日期: ${_displayFormat.format(balanceSheet.asOfDate)}',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            // Generated date
            pw.Center(
              child: pw.Text(
                '生成时间: ${_displayFormat.format(balanceSheet.generatedAt)}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey500,
                ),
              ),
            ),
            pw.SizedBox(height: 24),

            // Assets Section
            pw.Text(
              '资 产',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green700,
              ),
            ),
            pw.SizedBox(height: 12),
            _buildBalanceSheetSectionTable(balanceSheet.assets, PdfColors.green700),
            pw.SizedBox(height: 24),

            // Liabilities Section
            pw.Text(
              '负 债',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red700,
              ),
            ),
            pw.SizedBox(height: 12),
            _buildBalanceSheetSectionTable(balanceSheet.liabilities, PdfColors.red700),
            pw.SizedBox(height: 24),

            // Equity Section
            pw.Text(
              '所有者权益',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.purple700,
              ),
            ),
            pw.SizedBox(height: 12),
            _buildBalanceSheetSectionTable(balanceSheet.equity, PdfColors.purple700),
            pw.SizedBox(height: 24),

            // Balance Verification
            _buildBalanceVerification(balanceSheet),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text(
              '第 ${context.pageNumber} 页，共 ${context.pagesCount} 页',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey500,
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Builds a balance sheet section table.
  pw.Widget _buildBalanceSheetSectionTable(
    BalanceSheetSection section,
    PdfColor color,
  ) {
    final rows = <pw.TableRow>[];

    // Header
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: color),
        children: [
          _buildTableCell('科目', isHeader: true),
          _buildTableCell('金额', isHeader: true, alignRight: true),
        ],
      ),
    );

    // Items
    for (final item in section.items) {
      _addBalanceSheetItemRows(rows, item, depth: 0);
    }

    // Total row
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: color),
        children: [
          _buildTableCell('合计', isBold: true),
          _buildTableCell(
            '¥${_formatDecimal(section.totalDecimal)}',
            isBold: true,
            alignRight: true,
            textColor: color,
          ),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(2),
      },
      children: rows,
    );
  }

  /// Recursively adds balance sheet item rows.
  void _addBalanceSheetItemRows(
    List<pw.TableRow> rows,
    BalanceSheetItem item, {
    required int depth,
  }) {
    final indent = '  ' * depth;
    final prefix = depth > 0 ? '├─ ' : '';

    rows.add(
      pw.TableRow(
        children: [
          pw.Padding(
            padding: pw.EdgeInsets.only(left: depth * 8.0, top: 6, bottom: 6, right: 8),
            child: pw.Text(
              '$indent$prefix${item.accountName}',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: depth == 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: pw.Text(
              '¥${_formatDecimal(item.amountDecimal)}',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: depth == 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );

    // Add children recursively
    if (item.children != null) {
      for (final child in item.children!) {
        _addBalanceSheetItemRows(rows, child, depth: depth + 1);
      }
    }
  }

  /// Builds the balance verification section.
  pw.Widget _buildBalanceVerification(BalanceSheet balanceSheet) {
    final isBalanced = balanceSheet.isBalanced;
    final statusColor = isBalanced ? PdfColors.green700 : PdfColors.red700;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: statusColor,
        border: pw.Border.all(color: statusColor),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Icon(
                pw.IconData(isBalanced ? 0xe5ca : 0xe001),
                color: statusColor,
                size: 20,
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                '平衡验证',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: statusColor,
                ),
              ),
              pw.Spacer(),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: statusColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Text(
                  isBalanced ? '平衡' : '不平衡',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('资产总计', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.Text(
                    '¥${_formatDecimal(balanceSheet.assets.totalDecimal)}',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green700),
                  ),
                ],
              ),
              pw.Text('=', style: pw.TextStyle(fontSize: 18)),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('负债合计', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.Text(
                    '¥${_formatDecimal(balanceSheet.liabilities.totalDecimal)}',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red700),
                  ),
                ],
              ),
              pw.Text('+', style: pw.TextStyle(fontSize: 18)),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('权益合计', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.Text(
                    '¥${_formatDecimal(balanceSheet.equity.totalDecimal)}',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700),
                  ),
                ],
              ),
            ],
          ),
          if (!isBalanced) ...[
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.red50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Row(
                children: [
                  pw.Icon(
                    pw.IconData(0xe002),
                    color: PdfColors.red700,
                    size: 16,
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    '差额: ¥${_formatDecimal(balanceSheet.difference)}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.red700,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Formats a Decimal value to string.
  String _formatDecimal(Decimal value) {
    final str = value.toString();
    if (str.contains('.')) {
      final parts = str.split('.');
      final decimal = parts[1].padRight(2, '0').substring(0, 2);
      return '${parts[0]}.$decimal';
    }
    return '$str.00';
  }

  /// Generates the income statement PDF document.
  Future<Uint8List> _generateIncomeStatementPdf(
    IncomeStatement incomeStatement, {
    PageSetup? pageSetup,
  }) async {
    final pdf = pw.Document();
    final setup = pageSetup ?? const PageSetup();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: setup.effectiveFormat,
        margin: setup.margins,
        build: (pw.Context context) {
          return [
            // Title
            pw.Center(
              child: pw.Text(
                '利润表',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            // Period
            pw.Center(
              child: pw.Text(
                '报告期间: ${_displayFormat.format(incomeStatement.startDate)} - ${_displayFormat.format(incomeStatement.endDate)}',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            // Generated date
            pw.Center(
              child: pw.Text(
                '生成时间: ${_displayFormat.format(DateTime.now())}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey500,
                ),
              ),
            ),
            pw.SizedBox(height: 24),

            // Revenues Section
            pw.Text(
              '收入',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green700,
              ),
            ),
            pw.SizedBox(height: 12),
            _buildIncomeStatementSectionTable(
              incomeStatement.revenues,
              PdfColors.green700,
            ),
            pw.SizedBox(height: 24),

            // Expenses Section
            pw.Text(
              '费用',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red700,
              ),
            ),
            pw.SizedBox(height: 12),
            _buildIncomeStatementSectionTable(
              incomeStatement.expenses,
              PdfColors.red700,
            ),
            pw.SizedBox(height: 24),

            // Net Income
            _buildNetIncomeCard(incomeStatement),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text(
              '第 ${context.pageNumber} 页，共 ${context.pagesCount} 页',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey500,
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Builds an income statement section table.
  pw.Widget _buildIncomeStatementSectionTable(
    IncomeStatementSection section,
    PdfColor color,
  ) {
    final rows = <pw.TableRow>[];

    // Header
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: color),
        children: [
          _buildTableCell('科目', isHeader: true),
          _buildTableCell('金额', isHeader: true, alignRight: true),
        ],
      ),
    );

    // Items
    for (final item in section.items) {
      _addIncomeStatementItemRows(rows, item, depth: 0);
    }

    // Total row
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: color),
        children: [
          _buildTableCell('合计', isBold: true),
          _buildTableCell(
            '¥${_formatDecimal(section.totalDecimal)}',
            isBold: true,
            alignRight: true,
            textColor: color,
          ),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(2),
      },
      children: rows,
    );
  }

  /// Recursively adds income statement item rows.
  void _addIncomeStatementItemRows(
    List<pw.TableRow> rows,
    IncomeStatementItem item, {
    required int depth,
  }) {
    final indent = '  ' * depth;
    final prefix = depth > 0 ? '├─ ' : '';

    rows.add(
      pw.TableRow(
        children: [
          pw.Padding(
            padding: pw.EdgeInsets.only(left: depth * 8.0, top: 6, bottom: 6, right: 8),
            child: pw.Text(
              '$indent$prefix${item.accountName}',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: depth == 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: pw.Text(
              '¥${_formatDecimal(item.amountDecimal)}',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: depth == 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );

    // Add children recursively
    if (item.children != null) {
      for (final child in item.children!) {
        _addIncomeStatementItemRows(rows, child, depth: depth + 1);
      }
    }
  }

  /// Builds the net income card.
  pw.Widget _buildNetIncomeCard(IncomeStatement incomeStatement) {
    final isProfit = incomeStatement.isProfit;
    final statusColor = isProfit ? PdfColors.green700 : PdfColors.red700;
    final statusText = isProfit ? '盈利' : '亏损';

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: statusColor,
        border: pw.Border.all(color: statusColor),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                '净利润',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: statusColor,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: statusColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Text(
                  statusText,
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            '¥${_formatDecimal(incomeStatement.netIncomeDecimal)}',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: statusColor,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('收入合计', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.Text(
                    '¥${_formatDecimal(incomeStatement.grossProfit)}',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green700),
                  ),
                ],
              ),
              pw.Text('-', style: pw.TextStyle(fontSize: 18)),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('费用合计', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.Text(
                    '¥${_formatDecimal(incomeStatement.totalExpenses)}',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red700),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Category breakdown data model.
class CategoryBreakdown {
  final String id;
  final String name;
  final bool isIncome;
  final double amount;
  final double percentage;
  final int count;

  CategoryBreakdown({
    required this.id,
    required this.name,
    required this.isIncome,
    required this.amount,
    this.percentage = 0,
    this.count = 0,
  });
}

/// Monthly data model.
class MonthlyData {
  final String month;
  final double income;
  final double expense;

  MonthlyData({
    required this.month,
    required this.income,
    required this.expense,
  });

  double get net => income - expense;
}

/// PDF export result.
class PdfExportResult {
  final String filePath;
  final Uint8List? bytes;
  final int transactionCount;
  final int accountCount;
  final int categoryCount;
  final double totalIncome;
  final double totalExpense;
  final double netAmount;

  PdfExportResult({
    required this.filePath,
    this.bytes,
    required this.transactionCount,
    required this.accountCount,
    required this.categoryCount,
    required this.totalIncome,
    required this.totalExpense,
    required this.netAmount,
  });
}
