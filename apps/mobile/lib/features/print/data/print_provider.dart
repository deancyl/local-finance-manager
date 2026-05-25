import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:database/database.dart';
import '../data/print_service.dart';
import '../../export/data/pdf_export_service.dart';
import '../../export/data/export_service.dart';
import '../../reports/data/balance_sheet_provider.dart';
import '../../reports/data/income_statement_provider.dart';
import 'package:core/core.dart';

/// Print service provider.
final printServiceProvider = Provider<PrintService>((ref) {
  return PrintService();
});

/// Page setup configuration provider.
final pageSetupProvider = StateProvider<PageSetup>((ref) {
  return const PageSetup();
});

/// PDF export service provider.
final pdfExportServiceProvider = Provider<PdfExportService>((ref) {
  final db = ref.watch(databaseProvider);
  return PdfExportService(db);
});

/// Print preview provider for balance sheet.
final printBalanceSheetPreviewProvider =
    FutureProvider.family<Uint8List, PageSetup>((ref, setup) async {
  final balanceSheet = ref.watch(balanceSheetProvider).valueOrNull;
  if (balanceSheet == null) {
    throw Exception('资产负债表数据未加载');
  }

  final pdfService = ref.watch(pdfExportServiceProvider);
  return pdfService.exportBalanceSheetToPDFBytes(
    balanceSheet: balanceSheet,
    pageSetup: setup,
  );
});

/// Print preview provider for income statement.
final printIncomeStatementPreviewProvider =
    FutureProvider.family<Uint8List, PageSetup>((ref, setup) async {
  final statementWithComparison =
      ref.watch(incomeStatementProvider).valueOrNull;
  if (statementWithComparison == null) {
    throw Exception('利润表数据未加载');
  }

  final pdfService = ref.watch(pdfExportServiceProvider);
  return pdfService.exportIncomeStatementToPDFBytes(
    incomeStatement: statementWithComparison.current,
    pageSetup: setup,
  );
});

/// Print preview provider for transactions.
final printTransactionsPreviewProvider =
    FutureProvider.family<Uint8List, ExportFilters>((ref, filters) async {
  final pdfService = ref.watch(pdfExportServiceProvider);
  final result = await pdfService.exportToPDF(filters: filters);
  return result.bytes;
});