import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:database/database.dart';
import 'export_service.dart';

/// OFX (Open Financial Exchange) export service.
///
/// Generates OFX files compatible with Microsoft Money, QuickBooks,
/// and other financial applications.
///
/// OFX Format Reference:
/// - XML-based format (OFX v2.x uses XML, v1.x uses SGML)
/// - Contains bank account information and transactions
/// - Supports bank accounts, credit cards, and investments
/// - Uses specific date/time formats (YYYYMMDDHHMMSS)
class OfxExportService {
  final LocalFinanceDatabase _db;

  OfxExportService(this._db);

  /// Date format for OFX (YYYYMMDD)
  static final DateFormat _ofxDateFormat = DateFormat('yyyyMMdd');

  /// Date/time format for OFX (YYYYMMDDHHMMSS)
  static final DateFormat _ofxDateTimeFormat = DateFormat('yyyyMMddHHmmss');

  /// OFX version
  static const String _ofxVersion = '211';

  /// OFX file version
  static const String _ofxFileVersion = '2.0.2';

  /// Exports transactions to OFX format.
  ///
  /// [filters] - Optional filters for date range, account, category
  /// [bankId] - Bank identifier (required for OFX)
  /// [accountId] - Account ID for OFX (uses first account if not specified)
  /// [customPath] - Optional custom file path
  Future<OfxExportResult> exportToOFX({
    required ExportFilters filters,
    String? bankId,
    String? accountId,
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

    // Determine primary account
    Account? primaryAccount;
    String? primaryAccountId = accountId ?? filters.accountId;

    if (primaryAccountId != null) {
      primaryAccount = accountMap[primaryAccountId];
    } else {
      // Find first asset account
      primaryAccount = accounts.firstWhere(
        (a) => a.accountType.toUpperCase() == 'ASSET',
        orElse: () => accounts.first,
      );
    }

    // Get currency
    final currency = primaryAccount != null
        ? commodityMap[primaryAccount.commodityId]
        : commodities.firstOrNull;

    // Calculate balance (simplified - would need actual balance calculation)
    double balance = 0;
    for (final (_, splits) in transactionsWithSplits) {
      for (final split in splits) {
        balance += split.valueNum / split.valueDenom.toDouble();
      }
    }

    // Build OFX content
    final ofxContent = _buildOfxContent(
      transactionsWithSplits: transactionsWithSplits,
      accountMap: accountMap,
      categoryMap: categoryMap,
      commodityMap: commodityMap,
      primaryAccount: primaryAccount,
      currency: currency,
      balance: balance,
      bankId: bankId ?? 'LOCALBANK',
    );

    // Save file
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'transactions_$timestamp.ofx';
    final filePath = await _saveFile(ofxContent, fileName, customPath);

    return OfxExportResult(
      filePath: filePath,
      transactionCount: transactionsWithSplits.length,
      accountCount: accounts.length,
      categoryCount: categories.length,
      currency: currency?.mnemonic ?? 'CNY',
      balance: balance,
    );
  }

  /// Exports transactions for a specific account to OFX format.
  Future<OfxExportResult> exportAccountToOFX({
    required String accountId,
    required ExportFilters filters,
    String? bankId,
    String? customPath,
  }) async {
    // Get account info
    final account = await (_db.select(_db.accounts)
          ..where((a) => a.id.equals(accountId)))
        .getSingleOrNull();

    if (account == null) {
      throw ExportException('账户不存在');
    }

    // Create new filters with account filter
    final accountFilters = ExportFilters(
      startDate: filters.startDate,
      endDate: filters.endDate,
      categoryId: filters.categoryId,
      accountId: accountId,
      includeDeleted: filters.includeDeleted,
    );

    return exportToOFX(
      filters: accountFilters,
      bankId: bankId,
      accountId: accountId,
      customPath: customPath,
    );
  }

  /// Builds the complete OFX XML content.
  String _buildOfxContent({
    required List<(Transaction, List<Split>)> transactionsWithSplits,
    required Map<String, Account> accountMap,
    required Map<String, Category> categoryMap,
    required Map<String, Commodity> commodityMap,
    required Account? primaryAccount,
    required Commodity? currency,
    required double balance,
    required String bankId,
  }) {
    final buffer = StringBuffer();

    // OFX header (XML declaration and processing instruction)
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="no"?>');
    buffer.writeln('<?OFX OFXHEADER="200" VERSION="$_ofxVersion" SECURITY="NONE" OLDFILEUID="NONE" NEWFILEUID="NONE"?>');
    buffer.writeln('<OFX>');
    buffer.writeln('  <SIGNONMSGSRSV1>');
    buffer.writeln('    <SONRS>');
    buffer.writeln('      <STATUS>');
    buffer.writeln('        <CODE>0</CODE>');
    buffer.writeln('        <SEVERITY>INFO</SEVERITY>');
    buffer.writeln('      </STATUS>');
    buffer.writeln('      <DTSERVER>${_ofxDateTimeFormat.format(DateTime.now())}</DTSERVER>');
    buffer.writeln('      <LANGUAGE>CHS</LANGUAGE>');
    buffer.writeln('    </SONRS>');
    buffer.writeln('  </SIGNONMSGSRSV1>');

    // Determine account type
    final accountType = _mapAccountTypeToOfx(primaryAccount?.accountType ?? 'ASSET');

    // Bank or Credit Card transactions
    if (accountType == 'CREDITLINE') {
      // Credit card statement
      buffer.writeln('  <CREDITCARDMSGSRSV1>');
      buffer.writeln('    <CCSTMTTRNRS>');
      buffer.writeln('      <TRNUID>${_generateUID()}');
      buffer.writeln('      <STATUS>');
      buffer.writeln('        <CODE>0</CODE>');
      buffer.writeln('        <SEVERITY>INFO</SEVERITY>');
      buffer.writeln('      </STATUS>');
      buffer.writeln('      <CCSTMTRS>');
      buffer.writeln('        <CURDEF>${currency?.mnemonic ?? 'CNY'}</CURDEF>');
      buffer.writeln('        <CCACCTFROM>');
      buffer.writeln('          <ACCTID>${_escapeXml(primaryAccount?.id ?? 'UNKNOWN')}</ACCTID>');
      buffer.writeln('        </CCACCTFROM>');
      buffer.writeln('        <BANKTRANLIST>');

      // Date range
      if (transactionsWithSplits.isNotEmpty) {
        final dates = transactionsWithSplits
            .map((t) => DateTime.fromMillisecondsSinceEpoch(t.$1.postDate))
            .toList();
        dates.sort();
        buffer.writeln('          <DTSTART>${_ofxDateFormat.format(dates.first)}</DTSTART>');
        buffer.writeln('          <DTEND>${_ofxDateFormat.format(dates.last)}</DTEND>');
      }

      // Transactions
      for (final (transaction, splits) in transactionsWithSplits) {
        _writeTransaction(buffer, transaction, splits, accountMap, categoryMap);
      }

      buffer.writeln('        </BANKTRANLIST>');
      buffer.writeln('        <LEDGERBAL>');
      buffer.writeln('          <BALAMT>${balance.toStringAsFixed(2)}</BALAMT>');
      buffer.writeln('          <DTASOF>${_ofxDateFormat.format(DateTime.now())}</DTASOF>');
      buffer.writeln('        </LEDGERBAL>');
      buffer.writeln('      </CCSTMTRS>');
      buffer.writeln('    </CCSTMTTRNRS>');
      buffer.writeln('  </CREDITCARDMSGSRSV1>');
    } else {
      // Bank statement
      buffer.writeln('  <BANKMSGSRSV1>');
      buffer.writeln('    <STMTTRNRS>');
      buffer.writeln('      <TRNUID>${_generateUID()}');
      buffer.writeln('      <STATUS>');
      buffer.writeln('        <CODE>0</CODE>');
      buffer.writeln('        <SEVERITY>INFO</SEVERITY>');
      buffer.writeln('      </STATUS>');
      buffer.writeln('      <STMTRS>');
      buffer.writeln('        <CURDEF>${currency?.mnemonic ?? 'CNY'}</CURDEF>');
      buffer.writeln('        <BANKACCTFROM>');
      buffer.writeln('          <BANKID>${_escapeXml(bankId)}</BANKID>');
      buffer.writeln('          <ACCTID>${_escapeXml(primaryAccount?.id ?? 'UNKNOWN')}</ACCTID>');
      buffer.writeln('          <ACCTTYPE>$accountType</ACCTTYPE>');
      buffer.writeln('        </BANKACCTFROM>');
      buffer.writeln('        <BANKTRANLIST>');

      // Date range
      if (transactionsWithSplits.isNotEmpty) {
        final dates = transactionsWithSplits
            .map((t) => DateTime.fromMillisecondsSinceEpoch(t.$1.postDate))
            .toList();
        dates.sort();
        buffer.writeln('          <DTSTART>${_ofxDateFormat.format(dates.first)}</DTSTART>');
        buffer.writeln('          <DTEND>${_ofxDateFormat.format(dates.last)}</DTEND>');
      }

      // Transactions
      for (final (transaction, splits) in transactionsWithSplits) {
        _writeTransaction(buffer, transaction, splits, accountMap, categoryMap);
      }

      buffer.writeln('        </BANKTRANLIST>');
      buffer.writeln('        <LEDGERBAL>');
      buffer.writeln('          <BALAMT>${balance.toStringAsFixed(2)}</BALAMT>');
      buffer.writeln('          <DTASOF>${_ofxDateFormat.format(DateTime.now())}</DTASOF>');
      buffer.writeln('        </LEDGERBAL>');
      buffer.writeln('      </STMTRS>');
      buffer.writeln('    </STMTTRNRS>');
      buffer.writeln('  </BANKMSGSRSV1>');
    }

    buffer.writeln('</OFX>');

    return buffer.toString();
  }

  /// Writes a single transaction to OFX format.
  void _writeTransaction(
    StringBuffer buffer,
    Transaction transaction,
    List<Split> splits,
    Map<String, Account> accountMap,
    Map<String, Category> categoryMap,
  ) {
    final postDate = DateTime.fromMillisecondsSinceEpoch(transaction.postDate);
    final dateStr = _ofxDateFormat.format(postDate);

    // Get primary split
    final primarySplit = splits.first;
    final amount = primarySplit.valueNum / primarySplit.valueDenom.toDouble();

    // Determine transaction type
    final trntype = amount < 0 ? 'DEBIT' : 'CREDIT';

    buffer.writeln('          <STMTTRN>');
    buffer.writeln('            <TRNTYPE>$trntype</TRNTYPE>');
    buffer.writeln('            <DTPOSTED>$dateStr</DTPOSTED>');
    buffer.writeln('            <TRNAMT>${amount.toStringAsFixed(2)}</TRNAMT>');
    buffer.writeln('            <FITID>${_escapeXml(transaction.id)}</FITID>');

    // Check number (if available)
    if (transaction.referenceNum != null && transaction.referenceNum!.isNotEmpty) {
      buffer.writeln('            <CHECKNUM>${_escapeXml(transaction.referenceNum!)}</CHECKNUM>');
    }

    // Payee/Name
    if (transaction.description != null && transaction.description!.isNotEmpty) {
      buffer.writeln('            <NAME>${_escapeXml(transaction.description!)}</NAME>');
    }

    // Memo
    if (transaction.notes != null && transaction.notes!.isNotEmpty) {
      buffer.writeln('            <MEMO>${_escapeXml(transaction.notes!)}</MEMO>');
    }

    // Category (as extended info)
    if (primarySplit.categoryId != null) {
      final category = categoryMap[primarySplit.categoryId];
      if (category != null) {
        buffer.writeln('            <CURRENCY>${_escapeXml(category.name)}</CURRENCY>');
      }
    }

    buffer.writeln('          </STMTTRN>');
  }

  /// Maps internal account type to OFX account type.
  String _mapAccountTypeToOfx(String accountType) {
    switch (accountType.toUpperCase()) {
      case 'ASSET':
        return 'CHECKING';
      case 'LIABILITY':
        return 'CREDITLINE';
      case 'EQUITY':
        return 'SAVINGS';
      default:
        return 'CHECKING';
    }
  }

  /// Generates a unique transaction ID.
  String _generateUID() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Escapes special characters for XML.
  String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;')
        .replaceAll('\n', ' ')
        .replaceAll('\r', '')
        .replaceAll('\t', ' ');
  }

  /// Fetches filtered transactions with their splits.
  Future<List<(Transaction, List<Split>)>> _fetchFilteredTransactions(
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
    final splitsByTransaction = <String, List<Split>>{};
    for (final split in allSplits) {
      splitsByTransaction.putIfAbsent(split.transactionId, () => []).add(split);
    }

    // Build result with category/account filtering
    final result = <(Transaction, List<Split>)>[];
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

/// Result of OFX export operation.
class OfxExportResult {
  final String filePath;
  final int transactionCount;
  final int accountCount;
  final int categoryCount;
  final String currency;
  final double balance;

  OfxExportResult({
    required this.filePath,
    required this.transactionCount,
    required this.accountCount,
    required this.categoryCount,
    required this.currency,
    required this.balance,
  });
}
