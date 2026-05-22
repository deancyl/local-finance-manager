import 'package:drift/drift.dart';

import 'connection/database_connection.dart';
import 'tables/commodities.dart';
import 'tables/accounts.dart';
import 'tables/transactions.dart';
import 'tables/categories.dart';
import 'tables/budgets.dart';
import 'tables/imports.dart';
import 'tables/recurring.dart';
import 'tables/attachments.dart';
import 'tables/tags.dart';
import 'tables/closing_entries.dart';
import 'tables/exchange_rates.dart';

part 'database.g.dart';
part 'daos/accounts_dao.dart';
part 'daos/transactions_dao.dart';
part 'daos/categories_dao.dart';
part 'daos/budgets_dao.dart';
part 'daos/import_sources_dao.dart';
part 'daos/tags_dao.dart';
part 'daos/recurring_dao.dart';
part 'daos/attachments_dao.dart';
part 'daos/splits_dao.dart';
part 'daos/closing_entries_dao.dart';
part 'daos/exchange_rates_dao.dart';

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
    RecurringTransactions,
    Attachments,
    Tags,
    TransactionTags,
    ClosingEntries,
    ExchangeRates,
  ],
)
class LocalFinanceDatabase extends _$LocalFinanceDatabase {
  LocalFinanceDatabase() : super(getDatabaseConnection());

  LocalFinanceDatabase.forTesting(QueryExecutor executor) : super(executor);

  late final AccountsDao accountsDao = AccountsDao(this);
  late final TransactionsDao transactionsDao = TransactionsDao(this);
  late final CategoriesDao categoriesDao = CategoriesDao(this);
  late final BudgetsDao budgetsDao = BudgetsDao(this);
  late final ImportSourcesDao importSourcesDao = ImportSourcesDao(this);
  late final TagsDao tagsDao = TagsDao(this);
  late final RecurringTransactionsDao recurringTransactionsDao = RecurringTransactionsDao(this);
  late final AttachmentsDao attachmentsDao = AttachmentsDao(this);
  late final SplitsDao splitsDao = SplitsDao(this);
  late final ClosingEntriesDao closingEntriesDao = ClosingEntriesDao(this);
  late final ExchangeRatesDao exchangeRatesDao = ExchangeRatesDao(this);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        
        // Insert default commodities
        await _insertDefaultCommodities();
        
        // Insert default categories
        await _insertDefaultCategories();
        
        // Insert default account groups
        await _insertDefaultAccountGroups();
        
        // Performance: Composite index for budget queries
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_splits_category_date '
          'ON splits(category_id, transaction_id)',
        );
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(categories, categories.version);
          await m.addColumn(categories, categories.updatedAt);
          await m.addColumn(categories, categories.deletedAt);
          await m.addColumn(budgets, budgets.version);
          await m.addColumn(budgets, budgets.updatedAt);
          await m.addColumn(budgets, budgets.deletedAt);
          await m.addColumn(importSources, importSources.version);
          await m.addColumn(importSources, importSources.updatedAt);
          await m.addColumn(importBatches, importBatches.version);
          await m.addColumn(importBatches, importBatches.updatedAt);
        }
        if (from < 3) {
          // Add categoryId to Splits table for category-based reporting
          await m.addColumn(splits, splits.categoryId);
        }
        if (from < 4) {
          // Performance: Composite index for budget queries
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_splits_category_date '
            'ON splits(category_id, transaction_id)',
          );
        }
        if (from < 5) {
          // Version 5: Add recurring transactions, attachments, and tags support
          
          // Create recurring transactions table
          await m.createTable(recurringTransactions);
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_recurring_next_date '
            'ON recurring_transactions(next_date) WHERE is_active = 1',
          );
          
          // Create attachments table
          await m.createTable(attachments);
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_attachments_transaction '
            'ON attachments(transaction_id)',
          );
          
          // Create tags table
          await m.createTable(tags);
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_tags_name '
            'ON tags(name)',
          );
          
          // Create transaction_tags junction table
          await m.createTable(transactionTags);
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_transaction_tags_tag '
            'ON transaction_tags(tag_id)',
          );
          
          // Insert default system tags
          await _insertDefaultTags();
        }
        if (from < 6) {
          // Version 6: Performance indexes for critical query paths
          
          // Transactions: Date range queries (most common filter)
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_transactions_post_date '
            'ON transactions(post_date)',
          );
          
          // Transactions: Soft delete filtering
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_transactions_deleted_at '
            'ON transactions(deleted_at)',
          );
          
          // Transactions: Import batch queries
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_transactions_import_batch '
            'ON transactions(import_batch_id)',
          );
          
          // Splits: Account balance calculations
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_splits_account '
            'ON splits(account_id)',
          );
          
          // Splits: Transaction lookup (JOIN optimization)
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_splits_transaction '
            'ON splits(transaction_id)',
          );
          
          // Splits: Reconciliation status filtering
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_splits_reconcile '
            'ON splits(reconcile_state)',
          );
          
          // Accounts: Hierarchy traversal
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_accounts_parent '
            'ON accounts(parent_id)',
          );
          
          // Accounts: Type filtering
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_accounts_type '
            'ON accounts(account_type)',
          );
          
          // Budgets: Category lookup
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_budgets_category '
            'ON budgets(category_id)',
          );
          
          // Budgets: Active budget filtering
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_budgets_active '
            'ON budgets(is_active) WHERE is_active = 1',
          );
          
          // Categories: Hierarchy traversal
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_categories_parent '
            'ON categories(parent_id)',
          );
          
          // Import batches: Source tracking
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_import_batches_source '
            'ON import_batches(source_id)',
          );
          
          // Import batches: Date ordering
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_import_batches_date '
            'ON import_batches(imported_at)',
          );
        }
        if (from < 7) {
          // Version 7: Add liquidity_type column to accounts for balance sheet grouping
          await m.addColumn(accounts, accounts.liquidityType);
        }
        if (from < 8) {
          // Version 8: Add closing entries table for closing process
          await m.createTable(closingEntries);
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_closing_entries_fiscal_period '
            'ON closing_entries(fiscal_period_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_closing_entries_type '
            'ON closing_entries(closing_type)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_closing_entries_status '
            'ON closing_entries(status)',
          );
        }
        if (from < 9) {
          // Version 9: Add exchange rates table for multi-currency support
          await m.createTable(exchangeRates);
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_exchange_rates_from_currency '
            'ON exchange_rates(from_currency)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_exchange_rates_to_currency '
            'ON exchange_rates(to_currency)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_exchange_rates_date '
            'ON exchange_rates(date)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_exchange_rates_currencies_date '
            'ON exchange_rates(from_currency, to_currency, date)',
          );
        }
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
            updatedAt: DateTime.now(),
          ),
          CategoriesCompanion.insert(
            id: 'transport',
            name: '交通',
            icon: const Value('directions_car'),
            color: const Value('#2196F3'),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now(),
          ),
          CategoriesCompanion.insert(
            id: 'shopping',
            name: '购物',
            icon: const Value('shopping_cart'),
            color: const Value('#E91E63'),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now(),
          ),
          CategoriesCompanion.insert(
            id: 'entertainment',
            name: '娱乐',
            icon: const Value('movie'),
            color: const Value('#9C27B0'),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now(),
          ),
          CategoriesCompanion.insert(
            id: 'health',
            name: '医疗',
            icon: const Value('local_hospital'),
            color: const Value('#4CAF50'),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now(),
          ),
          CategoriesCompanion.insert(
            id: 'education',
            name: '教育',
            icon: const Value('school'),
            color: const Value('#FF9800'),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now(),
          ),
          CategoriesCompanion.insert(
            id: 'other_expense',
            name: '其他支出',
            icon: const Value('more_horiz'),
            color: const Value('#607D8B'),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now(),
          ),
          // Income categories
          CategoriesCompanion.insert(
            id: 'salary',
            name: '工资',
            icon: const Value('account_balance_wallet'),
            color: const Value('#4CAF50'),
            isIncome: const Value(true),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now(),
          ),
          CategoriesCompanion.insert(
            id: 'bonus',
            name: '奖金',
            icon: const Value('card_giftcard'),
            color: const Value('#8BC34A'),
            isIncome: const Value(true),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now(),
          ),
          CategoriesCompanion.insert(
            id: 'investment',
            name: '投资收益',
            icon: const Value('trending_up'),
            color: const Value('#CDDC39'),
            isIncome: const Value(true),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now(),
          ),
          CategoriesCompanion.insert(
            id: 'other_income',
            name: '其他收入',
            icon: const Value('attach_money'),
            color: const Value('#00BCD4'),
            isIncome: const Value(true),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now(),
          ),
        ],
      );
    });
  }

  Future<void> _insertDefaultAccountGroups() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await batch((batch) {
      batch.insertAll(
        accounts,
        [
          // ASSET groups
          AccountsCompanion.insert(
            id: 'asset_bank_accounts',
            name: '银行账户',
            accountType: 'ASSET',
            commodityId: 'CNY',
            isPlaceholder: const Value(true),
            sortOrder: const Value(1),
            createdAt: now,
            updatedAt: now,
          ),
          AccountsCompanion.insert(
            id: 'asset_cash',
            name: '现金',
            accountType: 'ASSET',
            commodityId: 'CNY',
            isPlaceholder: const Value(true),
            sortOrder: const Value(2),
            createdAt: now,
            updatedAt: now,
          ),
          AccountsCompanion.insert(
            id: 'asset_investments',
            name: '投资账户',
            accountType: 'ASSET',
            commodityId: 'CNY',
            isPlaceholder: const Value(true),
            sortOrder: const Value(3),
            createdAt: now,
            updatedAt: now,
          ),
          AccountsCompanion.insert(
            id: 'asset_receivables',
            name: '应收款项',
            accountType: 'ASSET',
            commodityId: 'CNY',
            isPlaceholder: const Value(true),
            sortOrder: const Value(4),
            createdAt: now,
            updatedAt: now,
          ),
          // LIABILITY groups
          AccountsCompanion.insert(
            id: 'liability_credit_cards',
            name: '信用卡',
            accountType: 'LIABILITY',
            commodityId: 'CNY',
            isPlaceholder: const Value(true),
            sortOrder: const Value(1),
            createdAt: now,
            updatedAt: now,
          ),
          AccountsCompanion.insert(
            id: 'liability_loans',
            name: '贷款',
            accountType: 'LIABILITY',
            commodityId: 'CNY',
            isPlaceholder: const Value(true),
            sortOrder: const Value(2),
            createdAt: now,
            updatedAt: now,
          ),
          AccountsCompanion.insert(
            id: 'liability_payables',
            name: '应付款项',
            accountType: 'LIABILITY',
            commodityId: 'CNY',
            isPlaceholder: const Value(true),
            sortOrder: const Value(3),
            createdAt: now,
            updatedAt: now,
          ),
          // INCOME groups
          AccountsCompanion.insert(
            id: 'income_salary',
            name: '工资收入',
            accountType: 'INCOME',
            commodityId: 'CNY',
            isPlaceholder: const Value(true),
            sortOrder: const Value(1),
            createdAt: now,
            updatedAt: now,
          ),
          AccountsCompanion.insert(
            id: 'income_investment',
            name: '投资收益',
            accountType: 'INCOME',
            commodityId: 'CNY',
            isPlaceholder: const Value(true),
            sortOrder: const Value(2),
            createdAt: now,
            updatedAt: now,
          ),
          AccountsCompanion.insert(
            id: 'income_other',
            name: '其他收入',
            accountType: 'INCOME',
            commodityId: 'CNY',
            isPlaceholder: const Value(true),
            sortOrder: const Value(3),
            createdAt: now,
            updatedAt: now,
          ),
          // EXPENSE groups
          AccountsCompanion.insert(
            id: 'expense_daily',
            name: '日常生活',
            accountType: 'EXPENSE',
            commodityId: 'CNY',
            isPlaceholder: const Value(true),
            sortOrder: const Value(1),
            createdAt: now,
            updatedAt: now,
          ),
          AccountsCompanion.insert(
            id: 'expense_transport',
            name: '交通出行',
            accountType: 'EXPENSE',
            commodityId: 'CNY',
            isPlaceholder: const Value(true),
            sortOrder: const Value(2),
            createdAt: now,
            updatedAt: now,
          ),
          AccountsCompanion.insert(
            id: 'expense_entertainment',
            name: '娱乐休闲',
            accountType: 'EXPENSE',
            commodityId: 'CNY',
            isPlaceholder: const Value(true),
            sortOrder: const Value(3),
            createdAt: now,
            updatedAt: now,
          ),
          AccountsCompanion.insert(
            id: 'expense_health',
            name: '医疗健康',
            accountType: 'EXPENSE',
            commodityId: 'CNY',
            isPlaceholder: const Value(true),
            sortOrder: const Value(4),
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
    });
  }

  Future<void> _insertDefaultTags() async {
    await batch((batch) {
      batch.insertAll(
        tags,
        [
          TagsCompanion.insert(
            id: 'tax-deductible',
            name: 'tax-deductible',
            color: const Value('#4CAF50'),
            description: const Value('Tax deductible expenses'),
            isSystem: const Value(true),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
          TagsCompanion.insert(
            id: 'business',
            name: 'business',
            color: const Value('#2196F3'),
            description: const Value('Business related transactions'),
            isSystem: const Value(true),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
          TagsCompanion.insert(
            id: 'reimbursable',
            name: 'reimbursable',
            color: const Value('#FF9800'),
            description: const Value('Expenses eligible for reimbursement'),
            isSystem: const Value(true),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
          TagsCompanion.insert(
            id: 'pending',
            name: 'pending',
            color: const Value('#9E9E9E'),
            description: const Value('Transactions pending review'),
            isSystem: const Value(true),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
      );
    });
  }
}