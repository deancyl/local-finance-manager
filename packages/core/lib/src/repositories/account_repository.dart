import '../models/account.dart';

/// Repository interface for account operations.
abstract class AccountRepository {
  /// Gets all accounts.
  Future<List<Account>> getAll();

  /// Gets an account by ID.
  Future<Account?> getById(String id);

  /// Gets accounts by type.
  Future<List<Account>> getByType(AccountType type);

  /// Gets child accounts of a parent account.
  Future<List<Account>> getChildren(String parentId);

  /// Creates a new account.
  Future<Account> create(Account account);

  /// Updates an existing account.
  Future<Account> update(Account account);

  /// Deletes an account.
  Future<void> delete(String id);

  /// Gets the account hierarchy as a tree structure.
  Future<List<AccountNode>> getHierarchy();

  /// Gets the current balance of an account.
  Future<double> getBalance(String id);
}

/// Node in the account hierarchy tree.
class AccountNode {
  final Account account;
  final List<AccountNode> children;

  AccountNode({required this.account, this.children = const []});

  /// Returns true if this node has children.
  bool get hasChildren => children.isNotEmpty;
}