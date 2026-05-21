import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:database/database.dart';

/// CSV validation result
class CSVValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final int rowCount;
  final List<String> headers;
  final List<Map<String, String>> previewRows;

  CSVValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.rowCount = 0,
    this.headers = const [],
    this.previewRows = const [],
  });
}

/// Import preview data
class ImportPreview {
  final String format;
  final String? exportType;
  final String? version;
  final DateTime? exportedAt;
  final int transactionCount;
  final int accountCount;
  final int categoryCount;
  final List<String> warnings;
  final List<String> errors;

  ImportPreview({
    required this.format,
    this.exportType,
    this.version,
    this.exportedAt,
    this.transactionCount = 0,
    this.accountCount = 0,
    this.categoryCount = 0,
    this.warnings = const [],
    this.errors = const [],
  });
}

/// Import result statistics
class ImportResult {
  final int transactionsImported;
  final int accountsImported;
  final int categoriesImported;
  final int skippedCount;
  final List<String> errors;

  ImportResult({
    this.transactionsImported = 0,
    this.accountsImported = 0,
    this.categoriesImported = 0,
    this.skippedCount = 0,
    this.errors = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
  int get totalImported =>
      transactionsImported + accountsImported + categoriesImported;
}

/// Service for importing data from CSV and JSON files
class ImportService {
  final LocalFinanceDatabase _db;

  ImportService(this._db);

  /// Expected CSV headers (Chinese)
  static const List<String> expectedHeaders = [
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
  ];

  /// Validates CSV file format and content
  Future<CSVValidationResult> validateCSVFormat(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return CSVValidationResult(
          isValid: false,
          errors: ['文件不存在'],
        );
      }

      final content = await file.readAsString(encoding: utf8);
      
      // Remove BOM if present
      String csvContent = content;
      if (content.startsWith('\u{FEFF}')) {
        csvContent = content.substring(1);
      }

      // Parse CSV
      final rows = const CsvToListConverter().convert(csvContent);
      
      if (rows.isEmpty) {
        return CSVValidationResult(
          isValid: false,
          errors: ['文件为空'],
        );
      }

      // Extract headers
      final headerRow = rows.first;
      final headers = headerRow.map((h) => h.toString()).toList();

      // Check required headers
      final errors = <String>[];
      final warnings = <String>[];

      // Check for minimum required headers
      final requiredHeaders = ['日期', '描述', '账户', '金额'];
      for (final required in requiredHeaders) {
        if (!headers.contains(required)) {
          errors.add('缺少必需列: $required');
        }
      }

      // Parse data rows for preview
      final previewRows = <Map<String, String>>[];
      final dataRows = rows.skip(1).take(5).toList();

      for (final row in dataRows) {
        final rowMap = <String, String>{};
        for (var i = 0; i < headers.length && i < row.length; i++) {
          rowMap[headers[i]] = row[i].toString();
        }
        previewRows.add(rowMap);
      }

      // Validate data rows
      int validRowCount = 0;
      for (final row in rows.skip(1)) {
        if (row.length >= 4) {
          // Check if amount is valid
          final amountStr = _getColumnValue(row, headers, '金额');
          if (amountStr != null) {
            final amount = double.tryParse(amountStr);
            if (amount == null) {
              warnings.add('行 ${validRowCount + 2}: 金额格式无效 "$amountStr"');
            }
          }
          validRowCount++;
        }
      }

      return CSVValidationResult(
        isValid: errors.isEmpty,
        errors: errors,
        warnings: warnings,
        rowCount: validRowCount,
        headers: headers,
        previewRows: previewRows,
      );
    } catch (e) {
      return CSVValidationResult(
        isValid: false,
        errors: ['解析文件失败: $e'],
      );
    }
  }

  /// Gets import preview from file
  Future<ImportPreview> getImportPreview(String filePath) async {
    try {
      final file = File(filePath);
      final extension = filePath.toLowerCase().split('.').last;

      if (extension == 'json') {
        return _getJsonPreview(file);
      } else if (extension == 'csv') {
        return _getCSVPreview(file);
      } else {
        return ImportPreview(
          format: extension,
          errors: ['不支持的文件格式: $extension'],
        );
      }
    } catch (e) {
      return ImportPreview(
        format: 'unknown',
        errors: ['读取文件失败: $e'],
      );
    }
  }

  /// Imports transactions from CSV file
  Future<ImportResult> importTransactionsFromCSV(
    String filePath, {
    bool skipDuplicates = true,
    String? defaultAccountId,
    String? defaultCurrencyId,
  }) async {
    final result = ImportResult(errors: []);
    final errors = <String>[];

    try {
      final file = File(filePath);
      String content = await file.readAsString(encoding: utf8);

      // Remove BOM if present
      if (content.startsWith('\u{FEFF}')) {
        content = content.substring(1);
      }

      final rows = const CsvToListConverter().convert(content);

      if (rows.isEmpty) {
        return ImportResult(errors: ['文件为空']);
      }

      // Extract headers
      final headers = rows.first.map((h) => h.toString()).toList();
      final dataRows = rows.skip(1).toList();

      // Get existing accounts and categories
      final accounts = await _db.select(_db.accounts).get();
      final categories = await _db.select(_db.categories).get();
      final commodities = await _db.select(_db.commodities).get();

      final accountByName = {for (var a in accounts) a.name: a};
      final categoryByName = {for (var c in categories) c.name: c};
      final commodityByMnemonic = {for (var c in commodities) c.mnemonic: c};

      // Get default currency
      final defaultCurrency = defaultCurrencyId ??
          commodities.firstWhere((c) => c.mnemonic == 'CNY', orElse: () => commodities.first).id;

      int imported = 0;
      int skipped = 0;

      await _db.transaction(() async {
        for (var i = 0; i < dataRows.length; i++) {
          final row = dataRows[i];
          if (row.length < 4) continue;

          try {
            // Parse row data
            final dateStr = _getColumnValue(row, headers, '日期') ?? '';
            final description = _getColumnValue(row, headers, '描述') ?? '';
            final accountName = _getColumnValue(row, headers, '账户') ?? '';
            final categoryName = _getColumnValue(row, headers, '分类');
            final amountStr = _getColumnValue(row, headers, '金额') ?? '0';
            final currencyStr = _getColumnValue(row, headers, '货币') ?? 'CNY';
            final notes = _getColumnValue(row, headers, '备注') ?? '';
            final externalId = _getColumnValue(row, headers, '外部ID');

            // Parse date
            DateTime? postDate;
            try {
              postDate = DateFormat('yyyy-MM-dd').parse(dateStr);
            } catch (_) {
              try {
                postDate = DateFormat('yyyy/MM/dd').parse(dateStr);
              } catch (_) {
                postDate = DateTime.now();
              }
            }

            // Parse amount
            final amount = double.tryParse(amountStr) ?? 0.0;
            if (amount == 0) {
              skipped++;
              continue;
            }

            // Find or use default account
            Account? account;
            if (accountName.isNotEmpty) {
              account = accountByName[accountName];
            }
            if (account == null && defaultAccountId != null) {
              account = accounts.firstWhere((a) => a.id == defaultAccountId, orElse: () => accounts.first);
            }
            if (account == null) {
              errors.add('行 ${i + 2}: 找不到账户 "$accountName"');
              skipped++;
              continue;
            }

            // Find category (optional)
            String? categoryId;
            if (categoryName != null && categoryName.isNotEmpty) {
              final category = categoryByName[categoryName];
              categoryId = category?.id;
            }

            // Find currency
            String currencyId = defaultCurrency;
            if (currencyStr.isNotEmpty) {
              final commodity = commodityByMnemonic[currencyStr];
              if (commodity != null) {
                currencyId = commodity.id;
              }
            }

            // Check for duplicates
            if (skipDuplicates && externalId != null && externalId.isNotEmpty) {
              final exists = await _db.transactionsDao.existsByExternalId(externalId);
              if (exists) {
                skipped++;
                continue;
              }
            }

            // Create transaction
            final transactionId = const Uuid().v4();
            final splitId = const Uuid().v4();
            final now = DateTime.now().millisecondsSinceEpoch;
            final amountNum = (amount * 100).round();

            await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                id: transactionId,
                postDate: postDate.millisecondsSinceEpoch,
                enterDate: now,
                currencyId: currencyId,
                description: drift.Value(description),
                notes: drift.Value(notes),
                externalId: drift.Value(externalId),
                createdAt: now,
                updatedAt: now,
              ),
            );

            await _db.into(_db.splits).insert(
              SplitsCompanion.insert(
                id: splitId,
                transactionId: transactionId,
                accountId: account.id,
                categoryId: drift.Value(categoryId),
                valueNum: amountNum,
                quantityNum: amountNum,
                createdAt: now,
              ),
            );

            imported++;
          } catch (e) {
            errors.add('行 ${i + 2}: 导入失败 - $e');
          }
        }
      });

      return ImportResult(
        transactionsImported: imported,
        skippedCount: skipped,
        errors: errors,
      );
    } catch (e) {
      return ImportResult(errors: ['导入失败: $e']);
    }
  }

  /// Imports data from JSON file
  Future<ImportResult> importFromJSON(
    String filePath, {
    bool skipDuplicates = true,
    bool mergeAccounts = false,
    bool mergeCategories = false,
  }) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString(encoding: utf8);
      final data = jsonDecode(content) as Map<String, dynamic>;

      final exportType = data['exportType'] as String? ?? 'full';
      final errors = <String>[];

      int transactionsImported = 0;
      int accountsImported = 0;
      int categoriesImported = 0;

      await _db.transaction(() async {
        // Import commodities first (if present)
        if (data['commodities'] != null) {
          await _importCommodities(data['commodities'] as List);
        }

        // Import accounts (if present)
        if (data['accounts'] != null) {
          accountsImported = await _importAccounts(
            data['accounts'] as List,
            merge: mergeAccounts,
          );
        }

        // Import categories (if present)
        if (data['categories'] != null) {
          categoriesImported = await _importCategories(
            data['categories'] as List,
            merge: mergeCategories,
          );
        }

        // Import transactions (if present)
        if (data['transactions'] != null) {
          final result = await _importTransactions(
            data['transactions'] as List,
            skipDuplicates: skipDuplicates,
          );
          transactionsImported = result;
        }

        // Import budgets (if present)
        if (data['budgets'] != null) {
          await _importBudgets(data['budgets'] as List);
        }
      });

      return ImportResult(
        transactionsImported: transactionsImported,
        accountsImported: accountsImported,
        categoriesImported: categoriesImported,
        errors: errors,
      );
    } catch (e) {
      return ImportResult(errors: ['导入失败: $e']);
    }
  }

  /// Picks a file for import
  Future<String?> pickImportFile({List<String>? allowedExtensions}) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择导入文件',
      type: FileType.custom,
      allowedExtensions: allowedExtensions ?? ['json', 'csv'],
      allowMultiple: false,
    );

    return result?.files.first.path;
  }

  // Private helper methods

  Future<ImportPreview> _getJsonPreview(File file) async {
    try {
      final content = await file.readAsString(encoding: utf8);
      final data = jsonDecode(content) as Map<String, dynamic>;

      return ImportPreview(
        format: 'JSON',
        exportType: data['exportType'] as String?,
        version: data['version'] as String?,
        exportedAt: data['exportedAt'] != null
            ? DateTime.tryParse(data['exportedAt'] as String)
            : null,
        transactionCount: (data['transactions'] as List?)?.length ?? 0,
        accountCount: (data['accounts'] as List?)?.length ?? 0,
        categoryCount: (data['categories'] as List?)?.length ?? 0,
      );
    } catch (e) {
      return ImportPreview(
        format: 'JSON',
        errors: ['解析JSON失败: $e'],
      );
    }
  }

  Future<ImportPreview> _getCSVPreview(File file) async {
    final validation = await validateCSVFormat(file.path);

    return ImportPreview(
      format: 'CSV',
      transactionCount: validation.rowCount,
      warnings: validation.warnings,
      errors: validation.errors,
    );
  }

  String? _getColumnValue(List<dynamic> row, List<String> headers, String columnName) {
    final index = headers.indexOf(columnName);
    if (index < 0 || index >= row.length) return null;
    return row[index]?.toString();
  }

  Future<void> _importCommodities(List commodities) async {
    for (final c in commodities) {
      final data = c as Map<String, dynamic>;
      final id = data['id'] as String;

      // Check if exists
      final existing = await (_db.select(_db.commodities)
            ..where((c) => c.id.equals(id)))
          .getSingleOrNull();

      if (existing == null) {
        await _db.into(_db.commodities).insert(
          CommoditiesCompanion.insert(
            id: id,
            mnemonic: data['mnemonic'] as String,
            fullname: drift.Value(data['fullname'] as String?),
            fraction: drift.Value(data['fraction'] as int? ?? 100),
            quoteSource: drift.Value(data['quoteSource'] as String?),
            quoteTz: drift.Value(data['quoteTZ'] as String?),
          ),
        );
      }
    }
  }

  Future<int> _importAccounts(List accounts, {bool merge = false}) async {
    int imported = 0;

    for (final a in accounts) {
      final data = a as Map<String, dynamic>;
      final id = data['id'] as String;

      if (!merge) {
        // Check if exists
        final existing = await (_db.select(_db.accounts)
              ..where((a) => a.id.equals(id)))
            .getSingleOrNull();

        if (existing != null) continue;
      }

      await _db.into(_db.accounts).insert(
        AccountsCompanion.insert(
          id: id,
          name: data['name'] as String,
          accountType: data['accountType'] as String,
          commodityId: data['commodityId'] as String,
          parentId: drift.Value(data['parentId'] as String?),
          code: drift.Value(data['code'] as String?),
          description: drift.Value(data['description'] as String?),
          isPlaceholder: drift.Value(data['isPlaceholder'] as bool? ?? false),
          isHidden: drift.Value(data['isHidden'] as bool? ?? false),
          sortOrder: drift.Value(data['sortOrder'] as int? ?? 0),
          createdAt: data['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
          updatedAt: data['updatedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        ),
        mode: merge ? drift.InsertMode.insertOrReplace : drift.InsertMode.insert,
      );
      imported++;
    }

    return imported;
  }

  Future<int> _importCategories(List categories, {bool merge = false}) async {
    int imported = 0;

    for (final c in categories) {
      final data = c as Map<String, dynamic>;
      final id = data['id'] as String;

      if (!merge) {
        final existing = await (_db.select(_db.categories)
              ..where((c) => c.id.equals(id)))
            .getSingleOrNull();

        if (existing != null) continue;
      }

      await _db.into(_db.categories).insert(
        CategoriesCompanion.insert(
          id: id,
          name: data['name'] as String,
          isIncome: drift.Value(data['isIncome'] as bool? ?? false),
          parentId: drift.Value(data['parentId'] as String?),
          icon: drift.Value(data['icon'] as String?),
          color: drift.Value(data['color'] as String?),
          sortOrder: drift.Value(data['sortOrder'] as int? ?? 0),
          createdAt: data['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
          updatedAt: data['updatedAt'] != null
              ? DateTime.parse(data['updatedAt'] as String)
              : DateTime.now(),
        ),
        mode: merge ? drift.InsertMode.insertOrReplace : drift.InsertMode.insert,
      );
      imported++;
    }

    return imported;
  }

  Future<int> _importTransactions(List transactions, {bool skipDuplicates = true}) async {
    int imported = 0;

    for (final t in transactions) {
      final data = t as Map<String, dynamic>;
      final id = data['id'] as String;
      final externalId = data['externalId'] as String?;

      // Check for duplicates
      if (skipDuplicates && externalId != null) {
        final exists = await _db.transactionsDao.existsByExternalId(externalId);
        if (exists) continue;
      }

      // Check if transaction exists
      final existing = await (_db.select(_db.transactions)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();

      if (existing != null) continue;

      final now = DateTime.now().millisecondsSinceEpoch;

      // Insert transaction
      await _db.into(_db.transactions).insert(
        TransactionsCompanion.insert(
          id: id,
          postDate: data['postDate'] as int,
          enterDate: data['enterDate'] as int? ?? now,
          currencyId: data['currencyId'] as String,
          description: drift.Value(data['description'] as String?),
          referenceNum: drift.Value(data['referenceNum'] as String?),
          notes: drift.Value(data['notes'] as String?),
          importBatchId: drift.Value(data['importBatchId'] as String?),
          externalId: drift.Value(externalId),
          isDoubleEntry: drift.Value(data['isDoubleEntry'] as bool? ?? false),
          idempotencyKey: drift.Value(data['idempotencyKey'] as String?),
          version: drift.Value(data['version'] as int? ?? 1),
          createdAt: data['createdAt'] as int? ?? now,
          updatedAt: data['updatedAt'] as int? ?? now,
        ),
      );

      // Insert splits
      final splits = data['splits'] as List?;
      if (splits != null) {
        for (final s in splits) {
          final splitData = s as Map<String, dynamic>;
          await _db.into(_db.splits).insert(
            SplitsCompanion.insert(
              id: splitData['id'] as String? ?? const Uuid().v4(),
              transactionId: id,
              accountId: splitData['accountId'] as String,
              categoryId: drift.Value(splitData['categoryId'] as String?),
              memo: drift.Value(splitData['memo'] as String?),
              valueNum: splitData['valueNum'] as int,
              valueDenom: drift.Value(splitData['valueDenom'] as int? ?? 1),
              quantityNum: splitData['quantityNum'] as int,
              quantityDenom: drift.Value(splitData['quantityDenom'] as int? ?? 1),
              reconcileState: drift.Value(splitData['reconcileState'] as String? ?? 'n'),
              reconcileDate: drift.Value(splitData['reconcileDate'] as int?),
              version: drift.Value(splitData['version'] as int? ?? 1),
              createdAt: splitData['createdAt'] as int? ?? now,
            ),
          );
        }
      }

      imported++;
    }

    return imported;
  }

  Future<void> _importBudgets(List budgets) async {
    for (final b in budgets) {
      final data = b as Map<String, dynamic>;
      final id = data['id'] as String;

      final existing = await (_db.select(_db.budgets)
            ..where((b) => b.id.equals(id)))
          .getSingleOrNull();

      if (existing != null) continue;

      await _db.into(_db.budgets).insert(
        BudgetsCompanion.insert(
          id: id,
          name: data['name'] as String,
          categoryId: drift.Value(data['categoryId'] as String?),
          amount: data['amount'] as int,
          periodType: data['periodType'] as String,
          startDate: data['startDate'] as int,
          endDate: drift.Value(data['endDate'] as int?),
          rollover: drift.Value(data['rollover'] as bool? ?? false),
          createdAt: data['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
          updatedAt: data['updatedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
  }
}
