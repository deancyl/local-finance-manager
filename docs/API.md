# API Documentation

## Core Models

### Account

Represents a financial account in the chart of accounts.

```dart
class Account {
  final String id;
  final String name;
  final AccountType accountType;  // ASSET, LIABILITY, EQUITY, INCOME, EXPENSE
  final String? parentId;
  final String commodityId;
  final String? code;
  final String? description;
  final bool isPlaceholder;
  final bool isHidden;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
}
```

### Transaction

Represents a financial transaction (journal entry).

```dart
class Transaction {
  final String id;
  final String? description;
  final DateTime postDate;
  final DateTime enterDate;
  final String commodityId;
  final String? referenceNumber;
  final String? notes;
  final String? importBatchId;
  final String? externalId;
  final bool isDoubleEntry;
  final String? idempotencyKey;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}
```

### Split

Represents a single debit or credit entry within a transaction.

```dart
class Split {
  final String id;
  final String transactionId;
  final String accountId;
  final String? memo;
  final int valueNum;          // Amount numerator
  final int valueDenom;        // Amount denominator (default: 1)
  final int quantityNum;       // For multi-currency
  final int quantityDenom;
  final ReconcileState reconcileState;  // none, cleared, reconciled, voided
  final DateTime? reconcileDate;
  final int version;
  final DateTime createdAt;
  
  // Computed properties
  double get value => valueNum / valueDenom;
  bool get isDebit => valueNum < 0;
  bool get isCredit => valueNum > 0;
}
```

### Category

Represents a transaction category.

```dart
class Category {
  final String id;
  final String name;
  final String? parentId;
  final String? icon;
  final String? color;
  final bool isIncome;
  final int sortOrder;
  final DateTime createdAt;
}
```

### Budget

Represents a spending limit for a category.

```dart
class Budget {
  final String id;
  final String name;
  final String? categoryId;
  final int amountNum;
  final int amountDenom;
  final String commodityId;
  final BudgetPeriod period;  // MONTHLY, YEARLY, CUSTOM
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime createdAt;
  
  double get amount => amountNum / amountDenom;
}
```

## Repository Interfaces

### AccountRepository

```dart
abstract class AccountRepository {
  Future<List<Account>> getAll();
  Future<Account?> getById(String id);
  Future<List<Account>> getByType(AccountType type);
  Future<List<Account>> getChildren(String parentId);
  Future<Account> create(Account account);
  Future<Account> update(Account account);
  Future<void> delete(String id);
  Future<List<AccountNode>> getHierarchy();
  Future<double> getBalance(String id);
}
```

### TransactionRepository

```dart
abstract class TransactionRepository {
  Future<List<Transaction>> getAll();
  Future<Transaction?> getById(String id);
  Future<List<Transaction>> getByDateRange(DateTime start, DateTime end);
  Future<List<Transaction>> getByAccount(String accountId);
  Future<Transaction> create(Transaction transaction, List<Split> splits);
  Future<Transaction> update(Transaction transaction, List<Split> splits);
  Future<void> delete(String id);
  Future<List<Split>> getSplits(String transactionId);
  Future<bool> existsByExternalId(String externalId);
  Future<List<Transaction>> search(TransactionQuery query);
}
```

## Use Cases

### AddTransaction

Creates a new transaction with single or double-entry support.

```dart
class AddTransaction {
  // Single-entry transaction
  Future<Transaction> addSingleEntry({
    required String accountId,
    required double amount,
    required DateTime date,
    String? description,
    String? categoryId,
    String? notes,
    String? externalId,
  });

  // Double-entry transaction
  Future<Transaction> addDoubleEntry({
    required String description,
    required DateTime date,
    required String currencyId,
    required List<SplitInput> splitInputs,
    String? notes,
    String? externalId,
  });
}
```

### GetBalance

Calculates account balances and net worth.

```dart
class GetBalance {
  Future<AccountBalance> getAccountBalance(String accountId);
  Future<List<AccountBalance>> getAllBalances();
  Future<double> getTotalBalanceByType(String accountType);
  Future<double> getNetWorth();
}
```

### ImportTransactions

Imports transactions from external sources.

```dart
class ImportTransactions {
  Future<ImportBatch> import({
    required String sourceId,
    required List<ParsedTransaction> transactions,
    String? filename,
    bool skipDuplicates = true,
  });
  
  List<String> validate(List<ParsedTransaction> transactions);
}
```

## Providers (Riverpod)

### Database Provider

```dart
final databaseProvider = Provider<LocalFinanceDatabase>((ref) {
  return LocalFinanceDatabase();
});
```

### Account Providers

```dart
// Watch all accounts
final accountsProvider = StreamProvider<List<Account>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.accounts).watch();
});

// Account CRUD operations
final accountNotifierProvider = StateNotifierProvider<AccountNotifier, AsyncValue<void>>((ref) {
  final db = ref.watch(databaseProvider);
  return AccountNotifier(db);
});
```

### Transaction Providers

```dart
// Watch all transactions
final transactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.transactions)
    ..where((t) => t.deletedAt.isNull())
    ..orderBy([(t) => OrderingTerm.desc(t.postDate)]))
    .watch();
});

// Get splits for a transaction
final splitsForTransactionProvider = FutureProvider.family<List<Split>, String>((ref, transactionId) async {
  final db = ref.watch(databaseProvider);
  return (db.select(db.splits)..where((s) => s.transactionId.equals(transactionId))).get();
});
```

## Database Schema

### SQL Definition

```sql
-- Accounts table
CREATE TABLE accounts (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    account_type    TEXT NOT NULL,
    parent_id       TEXT REFERENCES accounts(id),
    commodity_id    TEXT NOT NULL REFERENCES commodities(id),
    code            TEXT,
    description     TEXT,
    is_placeholder  INTEGER DEFAULT 0,
    is_hidden       INTEGER DEFAULT 0,
    sort_order      INTEGER DEFAULT 0,
    created_at      INTEGER NOT NULL,
    updated_at      INTEGER NOT NULL,
    version         INTEGER DEFAULT 1
);

-- Transactions table
CREATE TABLE transactions (
    id              TEXT PRIMARY KEY,
    description     TEXT,
    post_date       INTEGER NOT NULL,
    enter_date      INTEGER NOT NULL,
    currency_id     TEXT NOT NULL REFERENCES commodities(id),
    reference_num   TEXT,
    notes           TEXT,
    import_batch_id TEXT REFERENCES import_batches(id),
    external_id     TEXT,
    is_double_entry INTEGER DEFAULT 0,
    idempotency_key TEXT UNIQUE,
    version         INTEGER DEFAULT 1,
    created_at      INTEGER NOT NULL,
    updated_at      INTEGER NOT NULL,
    deleted_at      INTEGER
);

-- Splits table
CREATE TABLE splits (
    id              TEXT PRIMARY KEY,
    transaction_id  TEXT NOT NULL REFERENCES transactions(id),
    account_id      TEXT NOT NULL REFERENCES accounts(id),
    memo            TEXT,
    value_num       INTEGER NOT NULL,
    value_denom     INTEGER NOT NULL DEFAULT 1,
    quantity_num    INTEGER NOT NULL,
    quantity_denom  INTEGER NOT NULL DEFAULT 1,
    reconcile_state TEXT DEFAULT 'n',
    reconcile_date  INTEGER,
    version         INTEGER DEFAULT 1,
    created_at      INTEGER NOT NULL
);

-- Indexes
CREATE INDEX idx_transactions_date ON transactions(post_date);
CREATE INDEX idx_transactions_external ON transactions(external_id, import_batch_id);
CREATE INDEX idx_splits_transaction ON splits(transaction_id);
CREATE INDEX idx_splits_account ON splits(account_id);
```

## Encryption API

### KeychainService

```dart
abstract class KeychainService {
  Future<void> storeKey(String keyName, String key);
  Future<String?> retrieveKey(String keyName);
  Future<void> deleteKey(String keyName);
  Future<bool> hasKey(String keyName);
  Future<String> generateAndStoreKey(String keyName, int length);
  Future<void> clearAll();
}
```

### EncryptionService

```dart
class EncryptionService {
  // Create from password
  factory EncryptionService.fromPassword(String password, {String? salt});
  
  // Encrypt/decrypt strings
  String encrypt(String plaintext);
  String decrypt(String ciphertext);
  
  // Encrypt/decrypt JSON maps
  String encryptMap(Map<String, dynamic> data);
  Map<String, dynamic> decryptMap(String ciphertext);
  
  // Generate random key
  static Uint8List generateKey();
}
```

## Error Handling

All async operations return `AsyncValue<T>` from Riverpod, which handles:
- `AsyncValue.data(T)` - Success with data
- `AsyncValue.loading()` - Operation in progress
- `AsyncValue.error(Object, StackTrace)` - Error occurred

Example usage in UI:
```dart
final dataAsync = ref.watch(someProvider);

return dataAsync.when(
  data: (data) => Text('Data: $data'),
  loading: () => CircularProgressIndicator(),
  error: (error, _) => Text('Error: $error'),
);
```