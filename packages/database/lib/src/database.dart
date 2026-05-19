import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'tables/commodities.dart';
import 'tables/accounts.dart';
import 'tables/transactions.dart';
import 'tables/categories.dart';
import 'tables/budgets.dart';
import 'tables/imports.dart';
import 'daos/accounts_dao.dart';
import 'daos/transactions_dao.dart';
import 'daos/categories_dao.dart';
import 'daos/budgets_dao.dart';
import 'daos/import_sources_dao.dart';

part 'database.g.dart';

/// Local finance database with all tables.
@DriftDatabase(
  tables: [
    Commodities,
    Accounts,
    Transactions,
    Splits,
    Categories,
    Budgets,
    ImportSources,
    ImportBatches,
  ],
)
class LocalFinanceDatabase extends _$LocalFinanceDatabase {
  LocalFinanceDatabase() : super(_openConnection());

  LocalFinanceDatabase.connect(DatabaseConnection connection) : super.connect(connection);

  late final AccountsDao accountsDao = AccountsDao(this);
  late final TransactionsDao transactionsDao = TransactionsDao(this);
  late final CategoriesDao categoriesDao = CategoriesDao(this);
  late final BudgetsDao budgetsDao = BudgetsDao(this);
  late final ImportSourcesDao importSourcesDao = ImportSourcesDao(this);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        
        // Insert default commodities
        await _insertDefaultCommodities();
        
        // Insert default categories
        await _insertDefaultCategories();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle future migrations here
      },
    );
  }

  Future<void> _insertDefaultCommodities() async {
    await batch((batch) {
      batch.insertAll(
        commodities,
        [
          CommoditiesCompanion.insert(
            id: 'CNY',
            namespace: 'CURRENCY',
            mnemonic: 'CNY',
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            fullName: const Value('Chinese Yuan'),
          ),
          CommoditiesCompanion.insert(
            id: 'USD',
            namespace: 'CURRENCY',
            mnemonic: 'USD',
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            fullName: const Value('US Dollar'),
          ),
        ],
      );
    });
  }

  Future<void> _insertDefaultCategories() async {
    await batch((batch) {
      batch.insertAll(
        categories,
        [
          // Expense categories
          CategoriesCompanion.insert(
            id: 'food',
            name: '餐饮',
            icon: const Value('restaurant'),
            color: const Value('#FF5722'),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
          CategoriesCompanion.insert(
            id: 'transport',
            name: '交通',
            icon: const Value('directions_car'),
            color: const Value('#2196F3'),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
          CategoriesCompanion.insert(
            id: 'shopping',
            name: '购物',
            icon: const Value('shopping_cart'),
            color: const Value('#E91E63'),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
          CategoriesCompanion.insert(
            id: 'entertainment',
            name: '娱乐',
            icon: const Value('movie'),
            color: const Value('#9C27B0'),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
          CategoriesCompanion.insert(
            id: 'health',
            name: '医疗',
            icon: const Value('local_hospital'),
            color: const Value('#4CAF50'),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
          CategoriesCompanion.insert(
            id: 'education',
            name: '教育',
            icon: const Value('school'),
            color: const Value('#FF9800'),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
          CategoriesCompanion.insert(
            id: 'other_expense',
            name: '其他支出',
            icon: const Value('more_horiz'),
            color: const Value('#607D8B'),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
          // Income categories
          CategoriesCompanion.insert(
            id: 'salary',
            name: '工资',
            icon: const Value('account_balance_wallet'),
            color: const Value('#4CAF50'),
            isIncome: const Value(true),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
          CategoriesCompanion.insert(
            id: 'bonus',
            name: '奖金',
            icon: const Value('card_giftcard'),
            color: const Value('#8BC34A'),
            isIncome: const Value(true),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
          CategoriesCompanion.insert(
            id: 'investment',
            name: '投资收益',
            icon: const Value('trending_up'),
            color: const Value('#CDDC39'),
            isIncome: const Value(true),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
          CategoriesCompanion.insert(
            id: 'other_income',
            name: '其他收入',
            icon: const Value('attach_money'),
            color: const Value('#00BCD4'),
            isIncome: const Value(true),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
      );
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Put the database file in the app's documents directory
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'finance.db'));

    // Also work around limitations on old Android versions
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    }

    // Open the database
    return NativeDatabase.createInBackground(file);
  });
}

/// Workaround for SQLCipher on old Android versions.
Future<void> applyWorkaroundToOpenSqlCipherOnOldAndroidVersions() async {
  if (Platform.isAndroid) {
    await ensureSqlCipherIsLoadedOnAndroid();
  }
}

/// Ensures SQLCipher is loaded on Android.
Future<void> ensureSqlCipherIsLoadedOnAndroid() async {
  final db = sqlite3.openInMemory();
  db.dispose();
}