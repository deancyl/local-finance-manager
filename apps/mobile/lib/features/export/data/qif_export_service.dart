import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:database/database.dart';
import 'export_service.dart';

/// QIF (Quicken Interchange Format) export service.
///
/// Generates QIF files compatible with Quicken, GnuCash, and other
/// personal finance applications.
///
/// QIF Format Reference:
/// - Each transaction starts with type header: !Type:Cash, !Type:Bank, etc.
/// - D: Date (MM/DD/YYYY or DD/MM/YYYY depending on locale)
/// - T: Amount (negative for expenses, positive for income)
/// - P: Payee/Description
/// - L: Category (can include account transfer with brackets [Account])
/// - M: Memo
/// - S: Split category (for split transactions)
/// - $: Split amount
/// - ^: Transaction end marker
class QifExportService {
  final LocalFinanceDatabase _db;

  QifExportService(this._db);

  /// Date format for QIF (US format: MM/DD/YYYY)
  static final DateFormat _qifDateFormat = DateFormat('MM/dd/yyyy');

  /// Exports transactions to QIF format.
  ///
  /// [filters] - Optional filters for date range, account, category
  /// [accountType] - QIF account type (Cash, Bank, CCard, Invst, etc.)
  /// [customPath] - Optional custom file path
  Future<QifExportResult> exportToQIF({
    required ExportFilters filters,
    String accountType = 'Cash',
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

    // Build QIF content
    final buffer = StringBuffer();

    // Write account header
    buffer.writeln('!Account');
    buffer.writeln('NExported Account');
    buffer.writeln('T$accountType');
    buffer.writeln('^');
    buffer.writeln();

    // Write transaction type header
    buffer.writeln('!Type:$accountType');

    // Track unique currencies
    final currenciesUsed = <String>{};

    // Write transactions
    for (final (transaction, splits) in transactionsWithSplits) {
      final commodity = commodityMap[transaction.currencyId];
      currenciesUsed.add(commodity?.mnemonic ?? 'CNY');

      final postDate = DateTime.fromMillisecondsSinceEpoch(transaction.postDate);
      final dateStr = _qifDateFormat.format(postDate);

      // For single-split transactions (simple format)
      if (splits.length == 1) {
        final split = splits.first;
        final account = accountMap[split.accountId];
        final category = split.categoryId != null ? categoryMap[split.categoryId] : null;

        // Amount: negative for expenses, positive for income
        final amount = split.valueNum / split.valueDenom.toDouble();

        // Date
        buffer.writeln('D$dateStr');

        // Amount
        buffer.writeln('T${amount.toStringAsFixed(2)}');

        // Payee/Description
        if (transaction.description != null && transaction.description!.isNotEmpty) {
          buffer.writeln('P${_escapeQifField(transaction.description!)}');
        }

        // Category (L field)
        if (category != null) {
          buffer.writeln('L${_escapeQifField(category.name)}');
        } else if (account != null) {
          // Transfer to account (use brackets)
          buffer.writeln('L[${_escapeQifField(account.name)}]');
        }

        // Memo
        if (transaction.notes != null && transaction.notes!.isNotEmpty) {
          buffer.writeln('M${_escapeQifField(transaction.notes!)}');
        }

        // End of transaction
        buffer.writeln('^');
      } else {
        // Multi-split transaction
        // First, write the main transaction header
        buffer.writeln('D$dateStr');

        // Use first split's amount as primary (or sum)
        final primarySplit = splits.first;
        final primaryAmount = primarySplit.valueNum / primarySplit.valueDenom.toDouble();
        buffer.writeln('T${primaryAmount.toStringAsFixed(2)}');

        // Payee
        if (transaction.description != null && transaction.description!.isNotEmpty) {
          buffer.writeln('P${_escapeQifField(transaction.description!)}');
        }

        // Memo
        if (transaction.notes != null && transaction.notes!.isNotEmpty) {
          buffer.writeln('M${_escapeQifField(transaction.notes!)}');
        }

        // Write splits
        for (final split in splits) {
          final category = split.categoryId != null ? categoryMap[split.categoryId] : null;
          final account = accountMap[split.accountId];
          final splitAmount = split.valueNum / split.valueDenom.toDouble();

          // Split category
          if (category != null) {
            buffer.writeln('S${_escapeQifField(category.name)}');
          } else if (account != null) {
            buffer.writeln('S[${_escapeQifField(account.name)}]');
          }

          // Split memo
          if (split.memo != null && split.memo!.isNotEmpty) {
            buffer.writeln('E${_escapeQifField(split.memo!)}');
          }

          // Split amount
          buffer.writeln('\$${splitAmount.toStringAsFixed(2)}');
        }

        // End of transaction
        buffer.writeln('^');
      }
    }

    // Save file
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'transactions_$timestamp.qif';
    final filePath = await _saveFile(buffer.toString(), fileName, customPath);

    return QifExportResult(
      filePath: filePath,
      transactionCount: transactionsWithSplits.length,
      accountCount: accounts.length,
      categoryCount: categories.length,
      currencies: currenciesUsed.toList(),
      accountType: accountType,
    );
  }

  /// Exports transactions for a specific account to QIF format.
  ///
  /// This creates a QIF file optimized for importing into a specific
  /// account in Quicken/GnuCash.
  Future<QifExportResult> exportAccountToQIF({
    required String accountId,
    required ExportFilters filters,
    String? customPath,
  }) async {
    // Get account info
    final account = await (_db.select(_db.accounts)
          ..where((a) => a.id.equals(accountId)))
        .getSingleOrNull();

    if (account == null) {
      throw ExportException('账户不存在');
    }

    // Determine QIF account type based on account type
    final qifAccountType = _mapAccountTypeToQif(account.accountType);

    // Create new filters with account filter
    final accountFilters = ExportFilters(
      startDate: filters.startDate,
      endDate: filters.endDate,
      categoryId: filters.categoryId,
      accountId: accountId,
      includeDeleted: filters.includeDeleted,
    );

    return exportToQIF(
      filters: accountFilters,
      accountType: qifAccountType,
      customPath: customPath,
    );
  }

  /// Exports all accounts with their transactions to QIF format.
  ///
  /// Creates a comprehensive QIF file with account definitions
  /// and all transactions.
  Future<QifExportResult> exportAllToQIF({
    String? customPath,
  }) async {
    // Fetch all data
    final accounts = await _db.select(_db.accounts).get();
    final categories = await _db.select(_db.categories).get();
    final transactions = await (_db.select(_db.transactions)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.postDate)]))
        .get();
    final allSplits = await _db.select(_db.splits).get();
    final commodities = await _db.select(_db.commodities).get();

    if (transactions.isEmpty) {
      throw ExportException('没有可导出的交易记录');
    }

    final accountMap = {for (var a in accounts) a.id: a};
    final categoryMap = {for (var c in categories) c.id: c};
    final commodityMap = {for (var c in commodities) c.id: c};

    // Group splits by transaction
    final splitsByTransaction = <String, List<Split>>{};
    for (final split in allSplits) {
      splitsByTransaction.putIfAbsent(split.transactionId, () => []).add(split);
    }

    // Build QIF content
    final buffer = StringBuffer();

    // Write account list header
    buffer.writeln('!Option:AutoSwitch');
    buffer.writeln('!Account');

    // Write account definitions
    for (final account in accounts) {
      if (account.isHidden) continue;

      final qifType = _mapAccountTypeToQif(account.accountType);
      buffer.writeln('N${_escapeQifField(account.name)}');
      buffer.writeln('T$qifType');
      if (account.description != null && account.description!.isNotEmpty) {
        buffer.writeln('D${_escapeQifField(account.description!)}');
      }
      buffer.writeln('^');
    }

    buffer.writeln();

    // Track currencies
    final currenciesUsed = <String>{};

    // Write transactions grouped by account
    for (final account in accounts) {
      if (account.isHidden) continue;

      final qifType = _mapAccountTypeToQif(account.accountType);

      // Filter transactions for this account
      final accountTransactions = transactions.where((t) {
        final splits = splitsByTransaction[t.id] ?? [];
        return splits.any((s) => s.accountId == account.id);
      }).toList();

      if (accountTransactions.isEmpty) continue;

      // Write account header
      buffer.writeln('!Account');
      buffer.writeln('N${_escapeQifField(account.name)}');
      buffer.writeln('T$qifType');
      buffer.writeln('^');
      buffer.writeln();

      // Write transaction type header
      buffer.writeln('!Type:$qifType');

      for (final transaction in accountTransactions) {
        final splits = splitsByTransaction[transaction.id] ?? [];
        final splitsForAccount = splits.where((s) => s.accountId == account.id).toList();

        if (splitsForAccount.isEmpty) continue;

        final commodity = commodityMap[transaction.currencyId];
        currenciesUsed.add(commodity?.mnemonic ?? 'CNY');

        final postDate = DateTime.fromMillisecondsSinceEpoch(transaction.postDate);
        final dateStr = _qifDateFormat.format(postDate);

        // Use the split for this account
        final mainSplit = splitsForAccount.first;
        final amount = mainSplit.valueNum / mainSplit.valueDenom.toDouble();

        buffer.writeln('D$dateStr');
        buffer.writeln('T${amount.toStringAsFixed(2)}');

        if (transaction.description != null && transaction.description!.isNotEmpty) {
          buffer.writeln('P${_escapeQifField(transaction.description!)}');
        }

        // Category from the split
        if (mainSplit.categoryId != null) {
          final category = categoryMap[mainSplit.categoryId];
          if (category != null) {
            buffer.writeln('L${_escapeQifField(category.name)}');
          }
        }

        // If there are other splits, they represent transfers
        if (splits.length > 1) {
          final otherSplits = splits.where((s) => s.id != mainSplit.id).toList();
          for (final otherSplit in otherSplits) {
            final otherAccount = accountMap[otherSplit.accountId];
            if (otherAccount != null) {
              buffer.writeln('S[${_escapeQifField(otherAccount.name)}]');
              final splitAmount = otherSplit.valueNum / otherSplit.valueDenom.toDouble();
              buffer.writeln('\$${splitAmount.toStringAsFixed(2)}');
            }
          }
        }

        if (transaction.notes != null && transaction.notes!.isNotEmpty) {
          buffer.writeln('M${_escapeQifField(transaction.notes!)}');
        }

        buffer.writeln('^');
      }

      buffer.writeln();
    }

    // Write category list
    if (categories.isNotEmpty) {
      buffer.writeln('!Type:Cat');

      for (final category in categories) {
        buffer.writeln('N${_escapeQifField(category.name)}');
        // D for description (optional)
        // T for tax related (optional)
        // I if income category, E if expense category
        buffer.writeln(category.isIncome ? 'I' : 'E');
        buffer.writeln('^');
      }
    }

    // Save file
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'finance_export_$timestamp.qif';
    final filePath = await _saveFile(buffer.toString(), fileName, customPath);

    return QifExportResult(
      filePath: filePath,
      transactionCount: transactions.length,
      accountCount: accounts.where((a) => !a.isHidden).length,
      categoryCount: categories.length,
      currencies: currenciesUsed.toList(),
      accountType: 'Multiple',
    );
  }

  /// Maps internal account type to QIF account type.
  String _mapAccountTypeToQif(String accountType) {
    switch (accountType.toUpperCase()) {
      case 'ASSET':
        return 'Bank';
      case 'LIABILITY':
        return 'CCard';
      case 'EQUITY':
        return 'Oth A';
      case 'INCOME':
        return 'Inc';
      case 'EXPENSE':
        return 'Exp';
      default:
        return 'Cash';
    }
  }

  /// Escapes special characters in QIF fields.
  String _escapeQifField(String field) {
    return field
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

/// Result of QIF export operation.
class QifExportResult {
  final String filePath;
  final int transactionCount;
  final int accountCount;
  final int categoryCount;
  final List<String> currencies;
  final String accountType;

  QifExportResult({
    required this.filePath,
    required this.transactionCount,
    required this.accountCount,
    required this.categoryCount,
    required this.currencies,
    required this.accountType,
  });
}
