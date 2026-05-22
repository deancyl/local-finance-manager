import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:database/database.dart';
import 'package:flutter_test/flutter_test.dart';

/// Creates an in-memory database for testing
LocalFinanceDatabase createTestDatabase() {
  return LocalFinanceDatabase.forTesting(
    NativeDatabase.memory(),
  );
}

void main() {
  late LocalFinanceDatabase db;

  setUp(() async {
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('Database initialization', () {
    test('creates database successfully', () {
      expect(db, isNotNull);
    });

    test('has correct schema version', () {
      expect(db.schemaVersion, equals(10));
    });

    test('initializes all DAOs', () {
      expect(db.accountsDao, isNotNull);
      expect(db.transactionsDao, isNotNull);
      expect(db.categoriesDao, isNotNull);
      expect(db.budgetsDao, isNotNull);
      expect(db.tagsDao, isNotNull);
    });

    test('creates default commodities on initialization', () async {
      final commodities = await db.select(db.commodities).get();
      
      expect(commodities.length, greaterThanOrEqualTo(2));
      
      final cnyIds = commodities.where((c) => c.id == 'CNY');
      expect(cnyIds.length, equals(1));
      
      final usdIds = commodities.where((c) => c.id == 'USD');
      expect(usdIds.length, equals(1));
    });

    test('creates default categories on initialization', () async {
      final allCategories = await db.select(db.categories).get();
      
      expect(allCategories.length, greaterThan(0));
      
      // Check for some expected default categories
      final foodCategory = allCategories.where((c) => c.id == 'food');
      expect(foodCategory.length, equals(1));
      expect(foodCategory.first.name, equals('餐饮'));
      
      final salaryCategory = allCategories.where((c) => c.id == 'salary');
      expect(salaryCategory.length, equals(1));
      expect(salaryCategory.first.isIncome, isTrue);
    });

    test('creates default account groups on initialization', () async {
      final allAccounts = await db.select(db.accounts).get();
      
      expect(allAccounts.length, greaterThan(0));
      
      // Check for placeholder accounts
      final bankAccounts = allAccounts.where(
        (a) => a.id == 'asset_bank_accounts',
      );
      expect(bankAccounts.length, equals(1));
      expect(bankAccounts.first.isPlaceholder, isTrue);
      expect(bankAccounts.first.accountType, equals('ASSET'));
    });

    test('creates default tags on initialization', () async {
      final allTags = await db.select(db.tags).get();
      
      expect(allTags.length, greaterThan(0));
      
      final taxDeductible = allTags.where((t) => t.id == 'tax-deductible');
      expect(taxDeductible.length, equals(1));
      expect(taxDeductible.first.isSystem, isTrue);
    });
  });

  group('AccountsDao CRUD operations', () {
    test('creates and retrieves account', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final accountId = await db.accountsDao.create(
        AccountsCompanion.insert(
          id: 'test_account',
          name: 'Test Account',
          accountType: 'ASSET',
          commodityId: 'CNY',
          createdAt: now,
          updatedAt: now,
        ),
      );
      
      expect(accountId, equals('test_account'));
      
      final account = await db.accountsDao.getById('test_account');
      expect(account, isNotNull);
      expect(account!.name, equals('Test Account'));
      expect(account.accountType, equals('ASSET'));
    });

    test('updates account', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      await db.accountsDao.create(
        AccountsCompanion.insert(
          id: 'update_test',
          name: 'Original Name',
          accountType: 'ASSET',
          commodityId: 'CNY',
          createdAt: now,
          updatedAt: now,
        ),
      );
      
      await db.accountsDao.updateAccount(
        AccountsCompanion(
          id: const Value('update_test'),
          name: const Value('Updated Name'),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      
      final account = await db.accountsDao.getById('update_test');
      expect(account!.name, equals('Updated Name'));
    });

    test('deletes account', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      await db.accountsDao.create(
        AccountsCompanion.insert(
          id: 'delete_test',
          name: 'To Be Deleted',
          accountType: 'ASSET',
          commodityId: 'CNY',
          createdAt: now,
          updatedAt: now,
        ),
      );
      
      var account = await db.accountsDao.getById('delete_test');
      expect(account, isNotNull);
      
      await db.accountsDao.deleteAccount('delete_test');
      
      account = await db.accountsDao.getById('delete_test');
      expect(account, isNull);
    });

    test('gets accounts by type', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      await db.accountsDao.create(
        AccountsCompanion.insert(
          id: 'expense_account',
          name: 'Expense Account',
          accountType: 'EXPENSE',
          commodityId: 'CNY',
          createdAt: now,
          updatedAt: now,
        ),
      );
      
      final expenseAccounts = await db.accountsDao.getByType('EXPENSE');
      expect(expenseAccounts.length, greaterThan(0));
      expect(expenseAccounts.any((a) => a.id == 'expense_account'), isTrue);
    });

    test('gets child accounts', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Create parent account
      await db.accountsDao.create(
        AccountsCompanion.insert(
          id: 'parent_account',
          name: 'Parent',
          accountType: 'ASSET',
          commodityId: 'CNY',
          isPlaceholder: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
      
      // Create child accounts
      await db.accountsDao.create(
        AccountsCompanion.insert(
          id: 'child_account_1',
          name: 'Child 1',
          accountType: 'ASSET',
          commodityId: 'CNY',
          parentId: const Value('parent_account'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      
      await db.accountsDao.create(
        AccountsCompanion.insert(
          id: 'child_account_2',
          name: 'Child 2',
          accountType: 'ASSET',
          commodityId: 'CNY',
          parentId: const Value('parent_account'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      
      final children = await db.accountsDao.getChildren('parent_account');
      expect(children.length, equals(2));
    });

    test('watches all accounts', () async {
      final accountList = await db.accountsDao.watchAll().first;
      expect(accountList, isA<List<Account>>());
    });

    test('gets accounts with commodity info', () async {
      final accountsWithCommodity = await db.accountsDao.getAccountsWithCommodity();
      expect(accountsWithCommodity, isA<List<AccountWithCommodity>>());
      
      // All accounts should have commodity info
      for (final item in accountsWithCommodity) {
        expect(item.account, isNotNull);
        expect(item.commodity, isNotNull);
      }
    });
  });

  group('AccountsDao hierarchy methods', () {
    test('gets root accounts by type', () async {
      final rootAssets = await db.accountsDao.getRootAccountsByType('ASSET');
      
      // Should have default placeholder accounts
      expect(rootAssets.length, greaterThan(0));
      
      // All should have no parent
      for (final account in rootAssets) {
        expect(account.parentId, isNull);
        expect(account.accountType, equals('ASSET'));
      }
    });

    test('checks if account has children', () async {
      // Default placeholder accounts should have no children initially
      final hasChildren = await db.accountsDao.hasChildren('asset_bank_accounts');
      expect(hasChildren, isFalse);
    });

    test('gets descendant IDs recursively', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Create a hierarchy
      await db.accountsDao.create(
        AccountsCompanion.insert(
          id: 'root_test',
          name: 'Root',
          accountType: 'ASSET',
          commodityId: 'CNY',
          isPlaceholder: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
      
      await db.accountsDao.create(
        AccountsCompanion.insert(
          id: 'child_test_1',
          name: 'Child 1',
          accountType: 'ASSET',
          commodityId: 'CNY',
          parentId: const Value('root_test'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      
      await db.accountsDao.create(
        AccountsCompanion.insert(
          id: 'grandchild_test',
          name: 'Grandchild',
          accountType: 'ASSET',
          commodityId: 'CNY',
          parentId: const Value('child_test_1'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      
      final descendants = await db.accountsDao.getDescendantIds('root_test');
      expect(descendants.length, equals(2));
      expect(descendants.contains('child_test_1'), isTrue);
      expect(descendants.contains('grandchild_test'), isTrue);
    });
  });

  group('Categories table', () {
    test('creates and retrieves category', () async {
      final id = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: 'test_category',
          name: 'Test Category',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now(),
        ),
      );
      
      expect(id, equals('test_category'));
      
      final category = await (db.select(db.categories)
        ..where((c) => c.id.equals('test_category')))
        .getSingleOrNull();
      
      expect(category, isNotNull);
      expect(category!.name, equals('Test Category'));
    });

    test('category has income flag', () async {
      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: 'income_category',
          name: 'Income',
          isIncome: const Value(true),
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now(),
        ),
      );
      
      final category = await (db.select(db.categories)
        ..where((c) => c.id.equals('income_category')))
        .getSingleOrNull();
      
      expect(category!.isIncome, isTrue);
    });
  });

  group('Commodities table', () {
    test('creates and retrieves commodity', () async {
      await db.into(db.commodities).insert(
        CommoditiesCompanion.insert(
          id: 'EUR',
          namespace: 'CURRENCY',
          mnemonic: 'EUR',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          fullName: const Value('Euro'),
        ),
      );
      
      final commodity = await (db.select(db.commodities)
        ..where((c) => c.id.equals('EUR')))
        .getSingleOrNull();
      
      expect(commodity, isNotNull);
      expect(commodity!.mnemonic, equals('EUR'));
      expect(commodity.fullName, equals('Euro'));
    });

    test('commodity has unique namespace/mnemonic constraint', () async {
      // This should succeed (unique combination)
      await db.into(db.commodities).insert(
        CommoditiesCompanion.insert(
          id: 'STOCK1',
          namespace: 'STOCK',
          mnemonic: 'AAPL',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      
      // Attempting to insert same namespace/mnemonic should fail
      expect(
        () => db.into(db.commodities).insert(
          CommoditiesCompanion.insert(
            id: 'STOCK2',
            namespace: 'STOCK',
            mnemonic: 'AAPL', // Same as above
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        ),
        throwsA(anything),
      );
    });
  });

  group('Tags table', () {
    test('creates and retrieves tag', () async {
      await db.into(db.tags).insert(
        TagsCompanion.insert(
          id: 'custom_tag',
          name: 'custom_tag',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      
      final tag = await (db.select(db.tags)
        ..where((t) => t.id.equals('custom_tag')))
        .getSingleOrNull();
      
      expect(tag, isNotNull);
      expect(tag!.name, equals('custom_tag'));
    });

    test('tag can have color and description', () async {
      await db.into(db.tags).insert(
        TagsCompanion.insert(
          id: 'colored_tag',
          name: 'colored_tag',
          color: const Value('#FF0000'),
          description: const Value('A red tag'),
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      
      final tag = await (db.select(db.tags)
        ..where((t) => t.id.equals('colored_tag')))
        .getSingleOrNull();
      
      expect(tag!.color, equals('#FF0000'));
      expect(tag.description, equals('A red tag'));
    });
  });

  group('Database migrations', () {
    test('database starts at latest schema version', () async {
      // Verify we can access all tables without errors
      await db.select(db.commodities).get();
      await db.select(db.accounts).get();
      await db.select(db.categories).get();
      await db.select(db.tags).get();
      await db.select(db.budgets).get();
      await db.select(db.exchangeRates).get();
      await db.costCenters.get().get();
      await db.closingEntries.get().get();
    });
  });
}
