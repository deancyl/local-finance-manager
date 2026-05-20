import 'package:database/database.dart' as db;
import 'package:core/core.dart';
import 'package:drift/drift.dart' as drift;

/// Implementation of AccountRepository using Drift database.
class AccountRepositoryImpl implements AccountRepository {
  final db.LocalFinanceDatabase _db;

  AccountRepositoryImpl(this._db);

  @override
  Future<List<Account>> getAll() async {
    final accounts = await _db.select(_db.accounts).get();
    return accounts.map(_mapToAccount).toList();
  }

  @override
  Future<Account?> getById(String id) async {
    final account = await (_db.select(_db.accounts)
      ..where((a) => a.id.equals(id))
    ).getSingleOrNull();
    
    return account != null ? _mapToAccount(account) : null;
  }

  @override
  Future<List<Account>> getByType(AccountType type) async {
    final typeStr = _accountTypeToString(type);
    final accounts = await (_db.select(_db.accounts)
      ..where((a) => a.accountType.equals(typeStr))
    ).get();
    
    return accounts.map(_mapToAccount).toList();
  }

  @override
  Future<List<Account>> getChildren(String parentId) async {
    final accounts = await (_db.select(_db.accounts)
      ..where((a) => a.parentId.equals(parentId))
    ).get();
    
    return accounts.map(_mapToAccount).toList();
  }

  @override
  Future<Account> create(Account account) async {
    await _db.into(_db.accounts).insert(
      db.AccountsCompanion.insert(
        id: account.id,
        name: account.name,
        accountType: _accountTypeToString(account.accountType),
        commodityId: account.commodityId,
        parentId: drift.Value(account.parentId),
        code: drift.Value(account.code),
        description: drift.Value(account.description),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    
    return account;
  }

  @override
  Future<Account> update(Account account) async {
    await (_db.update(_db.accounts)
      ..where((a) => a.id.equals(account.id))
    ).write(
      db.AccountsCompanion(
        name: drift.Value(account.name),
        accountType: drift.Value(_accountTypeToString(account.accountType)),
        parentId: drift.Value(account.parentId),
        code: drift.Value(account.code),
        description: drift.Value(account.description),
        updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    
    return account;
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.accounts)..where((a) => a.id.equals(id))).go();
  }

  @override
  Future<List<AccountNode>> getHierarchy() async {
    final allAccounts = await getAll();
    final rootAccounts = allAccounts.where((a) => a.parentId == null).toList();
    
    return rootAccounts.map((account) => _buildNode(account, allAccounts)).toList();
  }

  @override
  Future<double> getBalance(String id) async {
    // Sum all splits for this account
    final splits = await (_db.select(_db.splits)
      ..where((s) => s.accountId.equals(id))
    ).get();
    
    // Sum valueNum (stored in cents) and convert to yuan
    final totalCents = splits.fold<int>(0, (sum, split) => sum + split.valueNum);
    return totalCents / 100.0;
  }

  AccountNode _buildNode(Account account, List<Account> allAccounts) {
    final children = allAccounts
        .where((a) => a.parentId == account.id)
        .map((child) => _buildNode(child, allAccounts))
        .toList();
    
    return AccountNode(account: account, children: children);
  }

  Account _mapToAccount(db.Account dbAccount) {
    return Account(
      id: dbAccount.id,
      name: dbAccount.name,
      accountType: _stringToAccountType(dbAccount.accountType),
      commodityId: dbAccount.commodityId,
      parentId: dbAccount.parentId,
      code: dbAccount.code,
      description: dbAccount.description,
      isPlaceholder: dbAccount.isPlaceholder,
      isHidden: dbAccount.isHidden,
      sortOrder: dbAccount.sortOrder,
      createdAt: DateTime.fromMillisecondsSinceEpoch(dbAccount.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(dbAccount.updatedAt),
      version: dbAccount.version,
    );
  }

  String _accountTypeToString(AccountType type) {
    switch (type) {
      case AccountType.asset:
        return 'ASSET';
      case AccountType.liability:
        return 'LIABILITY';
      case AccountType.equity:
        return 'EQUITY';
      case AccountType.income:
        return 'INCOME';
      case AccountType.expense:
        return 'EXPENSE';
    }
  }

  AccountType _stringToAccountType(String type) {
    switch (type) {
      case 'ASSET':
        return AccountType.asset;
      case 'LIABILITY':
        return AccountType.liability;
      case 'EQUITY':
        return AccountType.equity;
      case 'INCOME':
        return AccountType.income;
      case 'EXPENSE':
        return AccountType.expense;
      default:
        return AccountType.asset;
    }
  }
}
