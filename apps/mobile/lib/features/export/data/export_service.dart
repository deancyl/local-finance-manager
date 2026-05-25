import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:database/database.dart' as db;
import 'package:core/core.dart';
import 'package:decimal/decimal.dart';
import 'qif_export_service.dart';
import 'ofx_export_service.dart';
import 'pdf_export_service.dart';

/// Export filter options
class ExportFilters {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? categoryId;
  final String? accountId;
  final bool includeDeleted;

  const ExportFilters({
    this.startDate,
    this.endDate,
    this.categoryId,
    this.accountId,
    this.includeDeleted = false,
  });

  bool get hasFilters =>
      startDate != null ||
      endDate != null ||
      categoryId != null ||
      accountId != null;
}

/// Export result containing file path and statistics
class ExportResult {
  final String filePath;
  final int transactionCount;
  final int accountCount;
  final int categoryCount;
  final int attachmentCount;
  final String format;

  ExportResult({
    required this.filePath,
    required this.transactionCount,
    required this.accountCount,
    required this.categoryCount,
    this.attachmentCount = 0,
    required this.format,
  });
}

/// Service for exporting data to CSV and JSON formats
class ExportService {
  final db.LocalFinanceDatabase _db;

  ExportService(this._db);

  /// Date format for CSV export (Excel compatible)
  static final DateFormat _csvDateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _csvDateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  /// Exports transactions to CSV format (Excel compatible with UTF-8 BOM)
  Future<ExportResult> exportTransactionsToCSV({
    required ExportFilters filters,
    String? customPath,
  }) async {
    // Fetch transactions with splits
    final transactionsWithSplits = await _fetchFilteredTransactions(filters);

    if (transactionsWithSplits.isEmpty) {
      throw ExportException('没有可导出的交易记录');
    }

    // Build CSV rows
    final rows = <List<String>>[];

    // Header row
    rows.add([
      '交易ID',
      '日期',
      '描述',
      '账户',
      '分类',
      '金额',
      '货币',
      '备注',
      '录入时间',
      '外部ID',
    ]);

    // Fetch accounts and categories for name lookup
    final accounts = await _db.select(_db.accounts).get();
    final categories = await _db.select(_db.categories).get();
    final commodities = await _db.select(_db.commodities).get();

    final accountMap = {for (var a in accounts) a.id: a};
    final categoryMap = {for (var c in categories) c.id: c};
    final commodityMap = {for (var c in commodities) c.id: c};

    // Data rows
    for (final (transaction, splits) in transactionsWithSplits) {
      for (final split in splits) {
        final account = accountMap[split.accountId];
        final category = split.categoryId != null ? categoryMap[split.categoryId] : null;
        final commodity = commodityMap[transaction.currencyId];

        // Calculate amount from split value
        final amount = split.valueNum / split.valueDenom.toDouble();

        rows.add([
          transaction.id,
          _csvDateFormat.format(DateTime.fromMillisecondsSinceEpoch(transaction.postDate)),
          transaction.description ?? '',
          account?.name ?? '',
          category?.name ?? '',
          amount.toStringAsFixed(2),
          commodity?.mnemonic ?? 'CNY',
          transaction.notes ?? '',
          _csvDateTimeFormat.format(DateTime.fromMillisecondsSinceEpoch(transaction.enterDate)),
          transaction.externalId ?? '',
        ]);
      }
    }

    // Convert to CSV string
    final csvString = const ListToCsvConverter().convert(rows);

    // Add UTF-8 BOM for Excel compatibility
    final bom = '\u{FEFF}';
    final csvWithBom = '$bom$csvString';

    // Save file
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'transactions_$timestamp.csv';
    final filePath = await _saveFile(csvWithBom, fileName, customPath);

    return ExportResult(
      filePath: filePath,
      transactionCount: transactionsWithSplits.length,
      accountCount: accounts.length,
      categoryCount: categories.length,
      format: 'CSV',
    );
  }

  /// Exports transactions to JSON format
  Future<ExportResult> exportTransactionsToJSON({
    required ExportFilters filters,
    String? customPath,
  }) async {
    // Fetch transactions with splits
    final transactionsWithSplits = await _fetchFilteredTransactions(filters);

    if (transactionsWithSplits.isEmpty) {
      throw ExportException('没有可导出的交易记录');
    }

    // Fetch accounts and categories for reference
    final accounts = await _db.select(_db.accounts).get();
    final categories = await _db.select(_db.categories).get();
    final commodities = await _db.select(_db.commodities).get();

    // Build JSON structure
    final jsonData = {
      'version': '0.3.95',
      'exportedAt': DateTime.now().toIso8601String(),
      'exportType': 'transactions',
      'filters': {
        'startDate': filters.startDate?.toIso8601String(),
        'endDate': filters.endDate?.toIso8601String(),
        'categoryId': filters.categoryId,
        'accountId': filters.accountId,
      },
      'transactions': transactionsWithSplits.map((tuple) {
        final (transaction, splits) = tuple;
        return {
          'id': transaction.id,
          'description': transaction.description,
          'postDate': transaction.postDate,
          'enterDate': transaction.enterDate,
          'currencyId': transaction.currencyId,
          'referenceNum': transaction.referenceNum,
          'notes': transaction.notes,
          'externalId': transaction.externalId,
          'isDoubleEntry': transaction.isDoubleEntry,
          'splits': splits.map((s) => <String, dynamic>{
            'id': s.id,
            'accountId': s.accountId,
            'categoryId': s.categoryId,
            'memo': s.memo,
            'valueNum': s.valueNum,
            'valueDenom': s.valueDenom,
            'quantityNum': s.quantityNum,
            'quantityDenom': s.quantityDenom,
            'reconcileState': s.reconcileState,
          }).toList(),
        };
      }).toList(),
      'accounts': accounts.map((a) => <String, dynamic>{
        'id': a.id,
        'name': a.name,
        'type': a.accountType,
        'commodityId': a.commodityId,
      }).toList(),
      'categories': categories.map((c) => <String, dynamic>{
        'id': c.id,
        'name': c.name,
        'isIncome': c.isIncome,
      }).toList(),
      'commodities': commodities.map((c) => <String, dynamic>{
        'id': c.id,
        'mnemonic': c.mnemonic,
        'fullName': c.fullName,
      }).toList(),
    };

    // Convert to JSON string
    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);

    // Save file
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'transactions_$timestamp.json';
    final filePath = await _saveFile(jsonString, fileName, customPath);

    return ExportResult(
      filePath: filePath,
      transactionCount: transactionsWithSplits.length,
      accountCount: accounts.length,
      categoryCount: categories.length,
      format: 'JSON',
    );
  }

  /// Exports all accounts to JSON
  Future<ExportResult> exportAccountsToJSON({String? customPath}) async {
    final accounts = await _db.select(_db.accounts).get();
    final commodities = await _db.select(_db.commodities).get();

    if (accounts.isEmpty) {
      throw ExportException('没有可导出的账户');
    }

    final jsonData = {
      'version': '0.3.95',
      'exportedAt': DateTime.now().toIso8601String(),
      'exportType': 'accounts',
      'accounts': accounts.map((a) => <String, dynamic>{
        'id': a.id,
        'name': a.name,
        'accountType': a.accountType,
        'parentId': a.parentId,
        'commodityId': a.commodityId,
        'code': a.code,
        'description': a.description,
        'isPlaceholder': a.isPlaceholder,
        'isHidden': a.isHidden,
        'sortOrder': a.sortOrder,
        'createdAt': a.createdAt,
        'updatedAt': a.updatedAt,
        'version': a.version,
      }).toList(),
      'commodities': commodities.map((c) => <String, dynamic>{
        'id': c.id,
        'mnemonic': c.mnemonic,
        'fullName': c.fullName,
        'fraction': c.fraction,
      }).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'accounts_$timestamp.json';
    final filePath = await _saveFile(jsonString, fileName, customPath);

    return ExportResult(
      filePath: filePath,
      transactionCount: 0,
      accountCount: accounts.length,
      categoryCount: 0,
      format: 'JSON',
    );
  }

  /// Exports all categories to JSON
  Future<ExportResult> exportCategoriesToJSON({String? customPath}) async {
    final categories = await _db.select(_db.categories).get();

    if (categories.isEmpty) {
      throw ExportException('没有可导出的分类');
    }

    final jsonData = {
      'version': '0.3.95',
      'exportedAt': DateTime.now().toIso8601String(),
      'exportType': 'categories',
      'categories': categories.map((c) => <String, dynamic>{
        'id': c.id,
        'name': c.name,
        'parentId': c.parentId,
        'icon': c.icon,
        'color': c.color,
        'isIncome': c.isIncome,
        'sortOrder': c.sortOrder,
        'createdAt': c.createdAt,
      }).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'categories_$timestamp.json';
    final filePath = await _saveFile(jsonString, fileName, customPath);

    return ExportResult(
      filePath: filePath,
      transactionCount: 0,
      accountCount: 0,
      categoryCount: categories.length,
      format: 'JSON',
    );
  }

/// Exports full backup (all data including attachments)
  Future<ExportResult> exportFullBackup({String? customPath, bool includeAttachments = true}) async {
    // Fetch all data
    final transactions = await (_db.select(_db.transactions)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    final splits = await _db.select(_db.splits).get();
    final accounts = await _db.select(_db.accounts).get();
    final categories = await _db.select(_db.categories).get();
    final commodities = await _db.select(_db.commodities).get();
    final budgets = await _db.select(_db.budgets).get();
    final attachments = await _db.select(_db.attachments).get();

    // Build splits map
    final splitsByTransaction = <String, List<db.Split>>{};
    for (final split in splits) {
      splitsByTransaction.putIfAbsent(split.transactionId, () => []).add(split);
    }

    // Build attachments map
    final attachmentsByTransaction = <String, List<db.Attachment>>{};
    for (final attachment in attachments) {
      attachmentsByTransaction.putIfAbsent(attachment.transactionId, () => []).add(attachment);
    }

    final jsonData = {
      'version': '0.3.95',
      'exportedAt': DateTime.now().toIso8601String(),
      'exportType': 'full',
      'commodities': commodities.map((c) => <String, dynamic>{
        'id': c.id,
        'namespace': c.namespace,
        'mnemonic': c.mnemonic,
        'fullName': c.fullName,
        'fraction': c.fraction,
      }).toList(),
      'accounts': accounts.map((a) => <String, dynamic>{
        'id': a.id,
        'name': a.name,
        'accountType': a.accountType,
        'parentId': a.parentId,
        'commodityId': a.commodityId,
        'code': a.code,
        'description': a.description,
        'isPlaceholder': a.isPlaceholder,
        'isHidden': a.isHidden,
        'sortOrder': a.sortOrder,
        'createdAt': a.createdAt,
        'updatedAt': a.updatedAt,
        'version': a.version,
      }).toList(),
      'categories': categories.map((c) => <String, dynamic>{
        'id': c.id,
        'name': c.name,
        'parentId': c.parentId,
        'icon': c.icon,
        'color': c.color,
        'isIncome': c.isIncome,
        'sortOrder': c.sortOrder,
        'createdAt': c.createdAt,
        'version': c.version,
        'updatedAt': c.updatedAt.toIso8601String(),
        'deletedAt': c.deletedAt?.toIso8601String(),
      }).toList(),
      'transactions': transactions.map((t) {
        final transactionSplits = splitsByTransaction[t.id] ?? [];
        final transactionAttachments = attachmentsByTransaction[t.id] ?? [];
        return <String, dynamic>{
          'id': t.id,
          'description': t.description,
          'postDate': t.postDate,
          'enterDate': t.enterDate,
          'currencyId': t.currencyId,
          'referenceNum': t.referenceNum,
          'notes': t.notes,
          'importBatchId': t.importBatchId,
          'externalId': t.externalId,
          'isDoubleEntry': t.isDoubleEntry,
          'idempotencyKey': t.idempotencyKey,
          'version': t.version,
          'createdAt': t.createdAt,
          'updatedAt': t.updatedAt,
          'splits': transactionSplits.map((s) => <String, dynamic>{
            'id': s.id,
            'accountId': s.accountId,
            'categoryId': s.categoryId,
            'memo': s.memo,
            'valueNum': s.valueNum,
            'valueDenom': s.valueDenom,
            'quantityNum': s.quantityNum,
            'quantityDenom': s.quantityDenom,
            'reconcileState': s.reconcileState,
            'reconcileDate': s.reconcileDate,
            'version': s.version,
            'createdAt': s.createdAt,
          }).toList(),
          'attachments': transactionAttachments.map((a) => <String, dynamic>{
            'id': a.id,
            'fileName': a.fileName,
            'filePath': a.filePath,
            'fileType': a.fileType,
            'fileSize': a.fileSize,
            'thumbnailPath': a.thumbnailPath,
            'thumbnailWidth': a.thumbnailWidth,
            'thumbnailHeight': a.thumbnailHeight,
            'fileHash': a.fileHash,
            'description': a.description,
            'sortOrder': a.sortOrder,
            'createdAt': a.createdAt,
            'updatedAt': a.updatedAt,
          }).toList(),
        };
      }).toList(),
      'budgets': budgets.map((b) => <String, dynamic>{
        'id': b.id,
        'name': b.name,
        'categoryId': b.categoryId,
        'amountNum': b.amountNum,
        'amountDenom': b.amountDenom,
        'currencyId': b.currencyId,
        'period': b.period,
        'startDate': b.startDate,
        'endDate': b.endDate,
        'isActive': b.isActive,
        'createdAt': b.createdAt,
        'updatedAt': b.updatedAt.toIso8601String(),
      }).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'finance_backup_$timestamp.json';
    final filePath = await _saveFile(jsonString, fileName, customPath);

    return ExportResult(
      filePath: filePath,
      transactionCount: transactions.length,
      accountCount: accounts.length,
      categoryCount: categories.length,
      attachmentCount: attachments.length,
      format: 'JSON',
    );
  }

  /// Shares the exported file (mobile only)
  Future<void> shareFile(String filePath, {String? subject}) async {
    if (Platform.isAndroid || Platform.isIOS) {
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: subject ?? '财务数据导出',
      );
    }
  }

  /// Exports transactions to QIF format (Quicken/GnuCash compatible)
  Future<QifExportResult> exportTransactionsToQIF({
    required ExportFilters filters,
    String accountType = 'Cash',
    String? customPath,
  }) async {
    final qifService = QifExportService(_db);
    return qifService.exportToQIF(
      filters: filters,
      accountType: accountType,
      customPath: customPath,
    );
  }

  /// Exports a specific account to QIF format
  Future<QifExportResult> exportAccountToQIF({
    required String accountId,
    required ExportFilters filters,
    String? customPath,
  }) async {
    final qifService = QifExportService(_db);
    return qifService.exportAccountToQIF(
      accountId: accountId,
      filters: filters,
      customPath: customPath,
    );
  }

  /// Exports all accounts with transactions to QIF format
  Future<QifExportResult> exportAllToQIF({String? customPath}) async {
    final qifService = QifExportService(_db);
    return qifService.exportAllToQIF(customPath: customPath);
  }

  /// Exports transactions to OFX format (Microsoft Money/QuickBooks compatible)
  Future<OfxExportResult> exportTransactionsToOFX({
    required ExportFilters filters,
    String? bankId,
    String? accountId,
    String? customPath,
  }) async {
    final ofxService = OfxExportService(_db);
    return ofxService.exportToOFX(
      filters: filters,
      bankId: bankId,
      accountId: accountId,
      customPath: customPath,
    );
  }

  /// Exports a specific account to OFX format
  Future<OfxExportResult> exportAccountToOFX({
    required String accountId,
    required ExportFilters filters,
    String? bankId,
    String? customPath,
  }) async {
    final ofxService = OfxExportService(_db);
    return ofxService.exportAccountToOFX(
      accountId: accountId,
      filters: filters,
      bankId: bankId,
      customPath: customPath,
    );
  }

  /// Exports financial report to PDF format
  Future<PdfExportResult> exportTransactionsToPDF({
    required ExportFilters filters,
    String? customPath,
  }) async {
    final pdfService = PdfExportService(_db);
    return pdfService.exportToPDF(
      filters: filters,
      customPath: customPath,
    );
  }

  /// Exports balance sheet to PDF format
  Future<PdfExportResult> exportBalanceSheetToPDF({
    required BalanceSheet balanceSheet,
    String? customPath,
  }) async {
    final pdfService = PdfExportService(_db);
    return pdfService.exportBalanceSheetToPDF(
      balanceSheet: balanceSheet,
      customPath: customPath,
    );
  }

  /// Exports balance sheet to CSV format
  Future<ExportResult> exportBalanceSheetToCSV({
    required BalanceSheet balanceSheet,
    String? customPath,
  }) async {
    // Build CSV rows
    final rows = <List<String>>[];

    // Header
    rows.add(['资产负债表']);
    rows.add(['截止日期', DateFormat('yyyy-MM-dd').format(balanceSheet.asOfDate)]);
    rows.add(['生成时间', DateFormat('yyyy-MM-dd HH:mm:ss').format(balanceSheet.generatedAt)]);
    rows.add([]);

    // Assets Section
    rows.add(['资 产', '', '']);
    rows.add(['科目', '金额', '']);
    _addBalanceSheetItemsToCsv(rows, balanceSheet.assets.items, depth: 0);
    rows.add(['资产合计', '', '¥${_formatDecimal(balanceSheet.assets.totalDecimal)}']);
    rows.add([]);

    // Liabilities Section
    rows.add(['负 债', '', '']);
    rows.add(['科目', '金额', '']);
    _addBalanceSheetItemsToCsv(rows, balanceSheet.liabilities.items, depth: 0);
    rows.add(['负债合计', '', '¥${_formatDecimal(balanceSheet.liabilities.totalDecimal)}']);
    rows.add([]);

    // Equity Section
    rows.add(['所有者权益', '', '']);
    rows.add(['科目', '金额', '']);
    _addBalanceSheetItemsToCsv(rows, balanceSheet.equity.items, depth: 0);
    rows.add(['权益合计', '', '¥${_formatDecimal(balanceSheet.equity.totalDecimal)}']);
    rows.add([]);

    // Balance Verification
    rows.add(['平衡验证', '', '']);
    rows.add(['资产总计', '', '¥${_formatDecimal(balanceSheet.assets.totalDecimal)}']);
    rows.add(['负债合计', '', '¥${_formatDecimal(balanceSheet.liabilities.totalDecimal)}']);
    rows.add(['权益合计', '', '¥${_formatDecimal(balanceSheet.equity.totalDecimal)}']);
    rows.add(['平衡状态', '', balanceSheet.isBalanced ? '平衡' : '不平衡']);
    if (!balanceSheet.isBalanced) {
      rows.add(['差额', '', '¥${_formatDecimal(balanceSheet.difference)}']);
    }

    // Convert to CSV string
    final csvString = const ListToCsvConverter().convert(rows);

    // Add UTF-8 BOM for Excel compatibility
    final bom = '\u{FEFF}';
    final csvWithBom = '$bom$csvString';

    // Save file
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final dateStr = DateFormat('yyyyMMdd').format(balanceSheet.asOfDate);
    final fileName = 'balance_sheet_$dateStr\_$timestamp.csv';
    final filePath = await _saveFile(csvWithBom, fileName, customPath);

    return ExportResult(
      filePath: filePath,
      transactionCount: 0,
      accountCount: balanceSheet.assets.items.length +
          balanceSheet.liabilities.items.length +
          balanceSheet.equity.items.length,
      categoryCount: 0,
      format: 'CSV',
    );
  }

  /// Recursively adds balance sheet items to CSV rows.
  void _addBalanceSheetItemsToCsv(
    List<List<String>> rows,
    List<BalanceSheetItem> items, {
    required int depth,
  }) {
    for (final item in items) {
      final indent = '  ' * depth;
      rows.add([
        '$indent${item.accountName}',
        '¥${_formatDecimal(item.toDecimal)}',
        item.liquidityType == 'current' ? '流动' : '非流动',
      ]);

      if (item.children != null) {
        _addBalanceSheetItemsToCsv(rows, item.children!, depth: depth + 1);
      }
    }
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

  /// Fetches filtered transactions with their splits
  Future<List<(db.Transaction, List<db.Split>)>> _fetchFilteredTransactions(
    ExportFilters filters,
  ) async {
    // Build base query
    var query = _db.select(_db.transactions);

    if (!filters.includeDeleted) {
      query = query..where((t) => t.deletedAt.isNull());
    }

    query = query..orderBy([(t) => OrderingTerm.desc(t.postDate)]);

    // Apply date filters
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

    // Fetch splits for all transactions
    final transactionIds = transactions.map((t) => t.id).toList();
    final allSplits = await (_db.select(_db.splits)
          ..where((s) => s.transactionId.isIn(transactionIds)))
        .get();

    // Group splits by transaction
    final splitsByTransaction = <String, List<db.Split>>{};
    for (final split in allSplits) {
      splitsByTransaction.putIfAbsent(split.transactionId, () => []).add(split);
    }

    // Build result with category/account filtering
    final result = <(db.Transaction, List<db.Split>)>[];
    for (final transaction in transactions) {
      var splits = splitsByTransaction[transaction.id] ?? [];

      // Apply category filter
      if (filters.categoryId != null) {
        splits = splits.where((s) => s.categoryId == filters.categoryId).toList();
        if (splits.isEmpty) continue;
      }

      // Apply account filter
      if (filters.accountId != null) {
        splits = splits.where((s) => s.accountId == filters.accountId).toList();
        if (splits.isEmpty) continue;
      }

      result.add((transaction, splits));
    }

    return result;
  }

  /// Saves content to file
  Future<String> _saveFile(String content, String fileName, String? customPath) async {
    String filePath;

    if (customPath != null) {
      filePath = customPath;
    } else if (Platform.isAndroid || Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      filePath = '${directory.path}/$fileName';
    } else {
      // Desktop: use current directory or temp
      final directory = await getApplicationDocumentsDirectory();
      filePath = '${directory.path}/$fileName';
    }

    final file = File(filePath);
    await file.writeAsString(content, encoding: utf8);

    return filePath;
  }

  /// Exports all attachments to a ZIP archive.
  /// 
  /// Creates a ZIP file containing all attachment files organized by transaction.
  /// Returns the path to the created ZIP file.
  Future<String> exportAttachmentsToZip({String? customPath}) async {
    final attachments = await _db.select(_db.attachments).get();

    if (attachments.isEmpty) {
      throw ExportException('没有可导出的附件');
    }

    // Create archive
    final archive = Archive();

    for (final attachment in attachments) {
      final file = File(attachment.filePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        // Organize by transaction ID
        final archivePath = '${attachment.transactionId}/${attachment.fileName}';
        archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
      }
    }

    // Compress
    final compressed = ZipEncoder().encode(archive);
    if (compressed == null) {
      throw ExportException('压缩附件失败');
    }

    // Save file
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'attachments_$timestamp.zip';
    final filePath = customPath ?? await _getExportPath(fileName);

    final zipFile = File(filePath);
    await zipFile.writeAsBytes(compressed);

    return filePath;
  }

  /// Gets the default export path for a file.
  Future<String> _getExportPath(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$fileName';
  }
}

/// Exception for export operations
class ExportException implements Exception {
  final String message;
  ExportException(this.message);

  @override
  String toString() => message;
}
