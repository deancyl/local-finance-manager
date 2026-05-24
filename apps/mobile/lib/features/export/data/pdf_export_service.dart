import 'dart:io';
import 'dart:typed_data';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:database/database.dart';
import 'export_service.dart';

/// PDF export service for financial reports.
///
/// Generates PDF reports with:
/// - Income/Expense Summary
/// - Category Breakdown
/// - Monthly Trend Chart
class PdfExportService {
  final LocalFinanceDatabase _db;

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
    required List<(Transaction, List<Split>)> transactionsWithSplits,
    required Map<String, Account> accountMap,
    required Map<String, Category> categoryMap,
    required Map<String, Commodity> commodityMap,
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
    List<(Transaction, List<Split>)> transactionsWithSplits,
    Map<String, Account> accountMap,
    Map<String, Category> categoryMap,
    Map<String, Commodity> commodityMap,
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
      ),
    );
  }

  /// Calculates summary totals.
  Map<String, double> _calculateSummary(
    List<(Transaction, List<Split>)> transactionsWithSplits,
    Map<String, Category> categoryMap,
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
    List<(Transaction, List<Split>)> transactionsWithSplits,
    Map<String, Category> categoryMap,
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
    List<(Transaction, List<Split>)> transactionsWithSplits,
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
  final int transactionCount;
  final int accountCount;
  final int categoryCount;
  final double totalIncome;
  final double totalExpense;
  final double netAmount;

  PdfExportResult({
    required this.filePath,
    required this.transactionCount,
    required this.accountCount,
    required this.categoryCount,
    required this.totalIncome,
    required this.totalExpense,
    required this.netAmount,
  });
}
