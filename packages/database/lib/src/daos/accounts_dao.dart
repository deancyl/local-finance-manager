part of '../database.dart';

/// Data Access Object for accounts.
@DriftAccessor(tables: [Accounts, Commodities])
class AccountsDao extends DatabaseAccessor<LocalFinanceDatabase> 
    with _$AccountsDaoMixin, AuditableMixin {
  AccountsDao(super.db);

  /// Gets all accounts (excluding deleted).
  Future<List<Account>> getAll() => 
    (select(accounts)..where((a) => a.deletedAt.isNull())).get();

  /// Gets an account by ID.
  Future<Account?> getById(String id) {
    return (select(accounts)..where((a) => a.id.equals(id))).getSingleOrNull();
  }

  /// Gets accounts by type (excluding deleted).
  Future<List<Account>> getByType(String accountType) {
    return (select(accounts)..where((a) => 
      a.accountType.equals(accountType) & a.deletedAt.isNull())).get();
  }

  /// Gets child accounts of a parent (excluding deleted).
  Future<List<Account>> getChildren(String parentId) {
    return (select(accounts)..where((a) => 
      a.parentId.equals(parentId) & a.deletedAt.isNull())).get();
  }

  /// Creates a new account.
  Future<String> create(AccountsCompanion account) async {
    await into(accounts).insert(account);
    // Audit log for CREATE operation
    await logMutation(
      operation: 'CREATE',
      entityType: 'account',
      entityId: account.id.value,
      newValue: account.toJson(),
    );
    return account.id.value;
  }

  /// Updates an existing account.
  Future<void> updateAccount(AccountsCompanion account) async {
    // Get old value before update for audit log
    final oldAccount = await getById(account.id.value);
    await (update(accounts)..where((a) => a.id.equals(account.id.value))).write(account);
    // Audit log for UPDATE operation
    await logMutation(
      operation: 'UPDATE',
      entityType: 'account',
      entityId: account.id.value,
      oldValue: oldAccount?.toJson(),
      newValue: account.toJson(),
    );
  }

  /// Deletes an account (hard delete - admin use only).
  Future<void> hardDeleteAccount(String id) async {
    // Get old value before delete for audit log
    final oldAccount = await getById(id);
    await (delete(accounts)..where((a) => a.id.equals(id))).go();
    // Audit log for DELETE operation
    await logMutation(
      operation: 'DELETE',
      entityType: 'account',
      entityId: id,
      oldValue: oldAccount?.toJson(),
    );
  }

  /// Checks if an account can be deleted.
  /// Returns true if the account has no dependent records.
  Future<bool> canDelete(String accountId) async {
    // Check for splits referencing this account
    final splitsCount = await (select(db.splits)
      ..where((s) => s.accountId.equals(accountId)))
      .get()
      .then((list) => list.length);
    
    if (splitsCount > 0) {
      return false;
    }
    
    // Check for child accounts
    final hasChildAccounts = await hasChildren(accountId);
    if (hasChildAccounts) {
      return false;
    }
    
    return true;
  }

  /// Soft deletes an account by setting deletedAt timestamp.
  /// Returns true if successful, false if the account has dependent records.
  Future<bool> softDeleteAccount(String id) async {
    // Check if account can be deleted
    final canDeleteAccount = await canDelete(id);
    if (!canDeleteAccount) {
      // Audit log for failed delete attempt
      await logMutation(
        operation: 'SOFT_DELETE_FAILED',
        entityType: 'account',
        entityId: id,
        description: 'Cannot delete account: has dependent records (splits or child accounts)',
      );
      return false;
    }
    
    // Get old value for audit log
    final oldAccount = await getById(id);
    
    // Perform soft delete
    await (update(accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        deletedAt: Value(DateTime.now().millisecondsSinceEpoch),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    
    // Audit log for SOFT_DELETE operation
    await logMutation(
      operation: 'SOFT_DELETE',
      entityType: 'account',
      entityId: id,
      oldValue: oldAccount?.toJson(),
    );
    
    return true;
  }

  /// Watches all accounts (excluding deleted).
  Stream<List<Account>> watchAll() => 
    (select(accounts)..where((a) => a.deletedAt.isNull())).watch();

  /// Gets account with commodity info (excluding deleted).
  Future<List<AccountWithCommodity>> getAccountsWithCommodity() {
    return (select(accounts)..where((a) => a.deletedAt.isNull())).join([
      leftOuterJoin(commodities, commodities.id.equalsExp(accounts.commodityId)),
    ]).get().then((rows) {
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
  /// Gets root accounts (no parent) by type (excluding deleted).
  Future<List<Account>> getRootAccountsByType(String accountType) {
    return (select(accounts)
      ..where((a) => 
          a.accountType.equals(accountType) & 
          a.parentId.isNull() &
          a.deletedAt.isNull()))
      .get();
  }

  /// Watches root accounts by type (excluding deleted).
  Stream<List<Account>> watchRootAccountsByType(String accountType) {
    return (select(accounts)
      ..where((a) => 
          a.accountType.equals(accountType) & 
          a.parentId.isNull() &
          a.deletedAt.isNull()))
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

  /// Checks if an account has children (excluding deleted).
  Future<bool> hasChildren(String accountId) async {
    final count = await (select(accounts)
      ..where((a) => a.parentId.equals(accountId) & a.deletedAt.isNull()))
      .get()
      .then((list) => list.length);
    return count > 0;
  }
}