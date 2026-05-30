part of '../database.dart';

/// Data Access Object for accounts.
@DriftAccessor(tables: [Accounts, Commodities])
class AccountsDao extends DatabaseAccessor<LocalFinanceDatabase> with _$AccountsDaoMixin {
  AccountsDao(super.db);

  /// Gets all accounts.
  Future<List<Account>> getAll() => select(accounts).get();

  /// Gets an account by ID.
  Future<Account?> getById(String id) {
    return (select(accounts)..where((a) => a.id.equals(id))).getSingleOrNull();
  }

  /// Gets accounts by type.
  Future<List<Account>> getByType(String accountType) {
    return (select(accounts)..where((a) => a.accountType.equals(accountType))).get();
  }

  /// Gets child accounts of a parent.
  Future<List<Account>> getChildren(String parentId) {
    return (select(accounts)..where((a) => a.parentId.equals(parentId))).get();
  }

  /// Creates a new account.
  Future<String> create(AccountsCompanion account) async {
    await into(accounts).insert(account);
    return account.id.value;
  }

  /// Updates an existing account.
  Future<void> updateAccount(AccountsCompanion account) async {
    await (update(accounts)..where((a) => a.id.equals(account.id.value))).write(account);
  }

  /// Deletes an account.
  Future<void> deleteAccount(String id) async {
    await (delete(accounts)..where((a) => a.id.equals(id))).go();
  }

  /// Watches all accounts.
  Stream<List<Account>> watchAll() => select(accounts).watch();

  /// Gets account with commodity info.
  Future<List<AccountWithCommodity>> getAccountsWithCommodity() {
    return (select(accounts).join([
      leftOuterJoin(commodities, commodities.id.equalsExp(accounts.commodityId)),
    ])).get().then((rows) {
      return rows.map((row) {
        return AccountWithCommodity(
          account: row.readTable(accounts),
          commodity: row.readTable(commodities),
        );
      }).toList();
    });
  }
}

/// Account with commodity info.
class AccountWithCommodity {
  final Account account;
  final Commodity commodity;

  AccountWithCommodity({required this.account, required this.commodity});
}

// ============================================================
// HIERARCHY METHODS
// ============================================================

extension AccountsDaoHierarchy on AccountsDao {
  /// Gets root accounts (no parent) by type.
  Future<List<Account>> getRootAccountsByType(String accountType) {
    return (select(accounts)
      ..where((a) => 
          a.accountType.equals(accountType) & 
          a.parentId.isNull()))
      .get();
  }

  /// Watches root accounts by type.
  Stream<List<Account>> watchRootAccountsByType(String accountType) {
    return (select(accounts)
      ..where((a) => 
          a.accountType.equals(accountType) & 
          a.parentId.isNull()))
      .watch();
  }

  /// Gets all descendant account IDs (recursive).
  Future<Set<String>> getDescendantIds(String accountId) async {
    final descendants = <String>{};
    await _collectDescendants(accountId, descendants);
    return descendants;
  }

  Future<void> _collectDescendants(String parentId, Set<String> descendants) async {
    final children = await getChildren(parentId);
    for (final child in children) {
      descendants.add(child.id);
      await _collectDescendants(child.id, descendants);
    }
  }

  /// Checks if an account has children.
  Future<bool> hasChildren(String accountId) async {
    final count = await (select(accounts)
      ..where((a) => a.parentId.equals(accountId)))
      .get()
      .then((list) => list.length);
    return count > 0;
  }

  /// Checks if setting newParentId as parent of accountId would create a circular reference.
  /// 
  /// A circular reference occurs when newParentId is already a descendant of accountId,
  /// or when newParentId is the same as accountId.
  Future<bool> wouldCreateCircularReference(String accountId, String? newParentId) async {
    if (newParentId == null) return false;
    if (newParentId == accountId) return true;
    
    // Traverse parent chain from newParentId to see if it reaches accountId
    String? currentId = newParentId;
    final visited = <String>{};
    
    while (currentId != null) {
      if (currentId == accountId) return true;
      if (visited.contains(currentId)) break; // Prevent infinite loop
      visited.add(currentId);
      
      final account = await getById(currentId);
      currentId = account?.parentId;
    }
    
    return false;
  }

  /// Checks if an account can have its type changed.
  /// Returns false if the account has any transactions (splits or journal entry lines).
  Future<bool> canChangeAccountType(String accountId) async {
    // Check for splits
    final hasSplits = await _hasSplits(accountId);
    if (hasSplits) return false;
    
    // Check for journal entry lines
    final hasJournalLines = await _hasJournalEntryLines(accountId);
    if (hasJournalLines) return false;
    
    return true;
  }

  /// Checks if an account can be deleted.
  /// Returns false if the account has transactions or has child accounts.
  Future<bool> canDeleteAccount(String accountId) async {
    // Check for child accounts
    if (await hasChildren(accountId)) return false;
    
    // Check for splits
    if (await _hasSplits(accountId)) return false;
    
    // Check for journal entry lines
    if (await _hasJournalEntryLines(accountId)) return false;
    
    return true;
  }

  /// Gets the count of transactions (splits) for an account.
  Future<int> getTransactionCount(String accountId) async {
    final db = this.db;
    final query = db.select(db.splits)
      ..where((s) => s.accountId.equals(accountId));
    return query.get().then((list) => list.length);
  }

  /// Gets the count of child accounts.
  Future<int> getChildCount(String accountId) async {
    return (select(accounts)
      ..where((a) => a.parentId.equals(accountId)))
      .get()
      .then((list) => list.length);
  }

  /// Checks if account has splits.
  Future<bool> _hasSplits(String accountId) async {
    final db = this.db;
    final query = db.select(db.splits)
      ..where((s) => s.accountId.equals(accountId));
    return query.get().then((list) => list.isNotEmpty);
  }

  /// Checks if account has journal entry lines.
  Future<bool> _hasJournalEntryLines(String accountId) async {
    final db = this.db;
    final query = db.select(db.journalEntryLines)
      ..where((j) => j.accountId.equals(accountId));
    return query.get().then((list) => list.isNotEmpty);
  }
}