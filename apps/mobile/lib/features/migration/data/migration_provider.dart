import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:path_provider/path_provider.dart';
import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

// ============================================================
// MIGRATION MODELS
// ============================================================

/// Migration source type
enum MigrationSource {
  gnucash,
  quicken,
  mint,
  yNAB,
  other,
}

/// Migration result
class MigrationResult {
  final int accountsImported;
  final int transactionsImported;
  final int categoriesImported;
  final List<String> errors;
  final List<String> warnings;

  const MigrationResult({
    required this.accountsImported,
    required this.transactionsImported,
    required this.categoriesImported,
    this.errors = const [],
    this.warnings = const [],
  });

  bool get isSuccess => errors.isEmpty;
  int get totalImported => accountsImported + transactionsImported + categoriesImported;
}

// ============================================================
// MIGRATION SERVICE
// ============================================================

/// Service for migrating data from other finance applications
class MigrationService {
  final LocalFinanceDatabase _db;

  MigrationService(this._db);

  /// Import from JSON export
  Future<MigrationResult> importFromJson(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return const MigrationResult(
        accountsImported: 0,
        transactionsImported: 0,
        categoriesImported: 0,
        errors: ['文件不存在'],
      );
    }

    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      int accountsImported = 0;
      int transactionsImported = 0;
      int categoriesImported = 0;
      final errors = <String>[];
      final warnings = <String>[];

      // Import accounts
      if (data['accounts'] != null) {
        for (final accountData in data['accounts'] as List) {
          try {
            await _importAccount(accountData as Map<String, dynamic>);
            accountsImported++;
          } catch (e) {
            errors.add('导入账户失败: $e');
          }
        }
      }

      // Import categories
      if (data['categories'] != null) {
        for (final categoryData in data['categories'] as List) {
          try {
            await _importCategory(categoryData as Map<String, dynamic>);
            categoriesImported++;
          } catch (e) {
            errors.add('导入分类失败: $e');
          }
        }
      }

      // Import transactions
      if (data['transactions'] != null) {
        for (final txnData in data['transactions'] as List) {
          try {
            await _importTransaction(txnData as Map<String, dynamic>);
            transactionsImported++;
          } catch (e) {
            errors.add('导入交易失败: $e');
          }
        }
      }

      // Import splits
      if (data['splits'] != null) {
        for (final splitData in data['splits'] as List) {
          try {
            await _importSplit(splitData as Map<String, dynamic>);
          } catch (e) {
            warnings.add('导入分录失败: $e');
          }
        }
      }

      return MigrationResult(
        accountsImported: accountsImported,
        transactionsImported: transactionsImported,
        categoriesImported: categoriesImported,
        errors: errors,
        warnings: warnings,
      );
    } catch (e) {
      return MigrationResult(
        accountsImported: 0,
        transactionsImported: 0,
        categoriesImported: 0,
        errors: ['解析文件失败: $e'],
      );
    }
  }

  Future<void> _importAccount(Map<String, dynamic> data) async {
    await _db.into(_db.accounts).insert(
      AccountsCompanion.insert(
        id: data['id'] as String,
        name: data['name'] as String,
        accountType: data['accountType'] as String,
        commodityId: data['commodityId'] as String,
        parentId: drift.Value(data['parentId'] as String?),
        code: drift.Value(data['code'] as String?),
        description: drift.Value(data['description'] as String?),
        isPlaceholder: drift.Value(data['isPlaceholder'] as bool? ?? false),
        isHidden: drift.Value(data['isHidden'] as bool? ?? false),
        sortOrder: drift.Value(data['sortOrder'] as int? ?? 0),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      mode: drift.InsertMode.insertOrReplace,
    );
  }

  Future<void> _importCategory(Map<String, dynamic> data) async {
    await _db.into(_db.categories).insert(
      CategoriesCompanion.insert(
        id: data['id'] as String,
        name: data['name'] as String,
        parentId: drift.Value(data['parentId'] as String?),
        isIncome: drift.Value(data['isIncome'] as bool? ?? false),
        icon: drift.Value(data['icon'] as String?),
        color: drift.Value(data['color'] as String?),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now(),
      ),
      mode: drift.InsertMode.insertOrReplace,
    );
  }

  Future<void> _importTransaction(Map<String, dynamic> data) async {
    await _db.into(_db.transactions).insert(
      TransactionsCompanion.insert(
        id: data['id'] as String,
        postDate: data['postDate'] as int,
        enterDate: data['enterDate'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        currencyId: data['currencyId'] as String,
        description: drift.Value(data['description'] as String?),
        notes: drift.Value(data['notes'] as String?),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      mode: drift.InsertMode.insertOrReplace,
    );
  }

  Future<void> _importSplit(Map<String, dynamic> data) async {
    await _db.into(_db.splits).insert(
      SplitsCompanion.insert(
        id: data['id'] as String,
        transactionId: data['transactionId'] as String,
        accountId: data['accountId'] as String,
        categoryId: drift.Value(data['categoryId'] as String?),
        valueNum: data['valueNum'] as int,
        quantityNum: data['quantityNum'] as int? ?? data['valueNum'] as int,
        memo: drift.Value(data['memo'] as String?),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
      mode: drift.InsertMode.insertOrReplace,
    );
  }

  /// Validate migration file
  Future<bool> validateMigrationFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return false;

    try {
      final content = await file.readAsString();
      final data = jsonDecode(content);

      if (data is! Map<String, dynamic>) return false;
      if (!data.containsKey('version')) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  LocalFinanceDatabase get db => _db;
}

// ============================================================
// PROVIDERS
// ============================================================

final migrationServiceProvider = Provider<MigrationService>((ref) {
  final db = ref.watch(databaseProvider);
  return MigrationService(db);
});
