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
}