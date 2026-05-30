import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart' as uuid_pkg;

import 'package:database/database.dart';
import 'package:core/core.dart' as domain;

final databaseProvider = Provider<LocalFinanceDatabase>((ref) {
  return LocalFinanceDatabase();
});

final accountsProvider = StreamProvider<List<Account>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.accounts).watch();
});

final accountsByTypeProvider = Provider.family<List<Account>, String>((ref, type) {
  final accounts = ref.watch(accountsProvider);
  return accounts.when(
    data: (list) => list.where((a) => a.accountType == type).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

// ============================================================
// HIERARCHY PROVIDERS - Account tree structure
// ============================================================

/// Provider for root accounts (no parent)
final rootAccountsProvider = Provider<List<Account>>((ref) {
  final accounts = ref.watch(accountsProvider);
  return accounts.when(
    data: (list) => list
        .where((a) => a.parentId == null && !a.isHidden)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider for children of a specific parent
final childAccountsProvider = Provider.family<List<Account>, String>((ref, parentId) {
  final accounts = ref.watch(accountsProvider);
  return accounts.when(
    data: (list) => list
        .where((a) => a.parentId == parentId && !a.isHidden)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Account node for tree structure with computed subtotal
class AccountTreeNode {
  final Account account;
  final List<AccountTreeNode> children;
  final double subtotal;

  AccountTreeNode({
    required this.account,
    required this.children,
    required this.subtotal,
  });

  bool get hasChildren => children.isNotEmpty;
  bool get isGroup => account.isPlaceholder || hasChildren;
}

/// Provider for account hierarchy tree grouped by account type
final accountHierarchyProvider = Provider<Map<String, List<AccountTreeNode>>>((ref) {
  final accounts = ref.watch(accountsProvider);
  final balancesAsync = ref.watch(accountBalancesProvider);
  
  return accounts.when(
    data: (list) {
      // Get balances from async value, default to empty map if loading/error
      final balances = balancesAsync.when(
        data: (b) => b,
        loading: () => <String, double>{},
        error: (_, __) => <String, double>{},
      );
      
      final result = <String, List<AccountTreeNode>>{};
      
      for (final type in ['ASSET', 'LIABILITY', 'EQUITY', 'INCOME', 'EXPENSE']) {
        final rootAccountsOfType = list
            .where((a) => 
                a.parentId == null && 
                a.accountType == type && 
                !a.isHidden)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        
        result[type] = rootAccountsOfType
            .map((account) => _buildTreeNode(account, list, balances))
            .toList();
      }
      
      return result;
    },
    loading: () => {},
    error: (_, __) => {},
  );
});

/// Helper to build tree node recursively
AccountTreeNode _buildTreeNode(
  Account account, 
  List<Account> allAccounts,
  Map<String, double> balances,
) {
  final children = allAccounts
      .where((a) => a.parentId == account.id && !a.isHidden)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  
  final childNodes = children
      .map((child) => _buildTreeNode(child, allAccounts, balances))
      .toList();
  
  // Subtotal = own balance + sum of children's subtotals (hybrid model)
  final ownBalance = balances[account.id] ?? 0.0;
  final childrenSubtotal = childNodes.fold(0.0, (sum, node) => sum + node.subtotal);
  
  return AccountTreeNode(
    account: account,
    children: childNodes,
    subtotal: ownBalance + childrenSubtotal,
  );
}

/// Provider for account balances (computed from transactions)
/// Calculates balance from splits, considering account type (debit/credit nature)
final accountBalancesProvider = StreamProvider<Map<String, double>>((ref) {
  final db = ref.watch(databaseProvider);
  final accountsAsync = ref.watch(accountsProvider);
  
  return accountsAsync.when(
    data: (accountList) {
      // Create account type lookup map
      final accountTypes = <String, String>{
        for (final acc in accountList) acc.id: acc.accountType,
      };
      
      // Watch all splits and compute balances
      return db.transactionsDao.watchAllSplits().map((splits) {
        final balances = <String, double>{};
        
        for (final split in splits) {
          final accountId = split.accountId;
          final accountType = accountTypes[accountId] ?? 'ASSET';
          
          // Convert rational to double: valueNum / valueDenom
          final value = split.valueNum.toDouble() / split.valueDenom.toDouble();
          
          // Apply accounting rules based on account type:
          // ASSET/EXPENSE: Debit increases balance (positive value = increase)
          // LIABILITY/EQUITY/INCOME: Credit increases balance (negative value = increase)
          // In splits, positive = debit, negative = credit
          final adjustedValue = _applyAccountTypeSign(accountType, value);
          
          balances[accountId] = (balances[accountId] ?? 0.0) + adjustedValue;
        }
        
        return balances;
      });
    },
    loading: () => Stream.value({}),
    error: (_, __) => Stream.value({}),
  );
});

/// Applies accounting sign convention based on account type.
/// ASSET/EXPENSE: Debit increases (positive value = increase)
/// LIABILITY/EQUITY/INCOME: Credit increases (negative value = increase)
double _applyAccountTypeSign(String accountType, double value) {
  switch (accountType.toUpperCase()) {
    case 'ASSET':
    case 'EXPENSE':
      // Debit increases balance
      return value;
    case 'LIABILITY':
    case 'EQUITY':
    case 'INCOME':
      // Credit increases balance (so debit decreases)
      return -value;
    default:
      return value;
  }
}

class AccountNotifier extends StateNotifier<AsyncValue<void>> {
  final LocalFinanceDatabase _db;

  AccountNotifier(this._db) : super(const AsyncValue.data(null));

  Future<void> createAccount({
    required String name,
    required String accountType,
    required String commodityId,
    String? parentId,
    String? code,
    String? description,
    bool isPlaceholder = false,
    int sortOrder = 0,
  }) async {
    state = const AsyncValue.loading();
    try {
      // NOTE: Circular reference check is not needed for new accounts
      // since they don't exist in the hierarchy yet
      
      final id = const uuid_pkg.Uuid().v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      await _db.into(_db.accounts).insert(
        AccountsCompanion.insert(
          id: id,
          name: name,
          accountType: accountType,
          commodityId: commodityId,
          parentId: drift.Value(parentId),
          code: drift.Value(code),
          description: drift.Value(description),
          isPlaceholder: drift.Value(isPlaceholder),
          sortOrder: drift.Value(sortOrder),
          createdAt: now,
          updatedAt: now,
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateAccount(Account account, {String? oldAccountType}) async {
    state = const AsyncValue.loading();
    try {
      // VALIDATION: Check for circular reference
      if (account.parentId != null) {
        final wouldCreateCycle = await _db.accountsDao.wouldCreateCircularReference(account.id, account.parentId);
        if (wouldCreateCycle) {
          throw ArgumentError('Cannot set parent: would create circular reference');
        }
      }
      
      // VALIDATION: Cannot make account its own parent
      if (account.parentId == account.id) {
        throw ArgumentError('Cannot make account its own parent');
      }
      
      // VALIDATION: Check if account type can be changed
      if (oldAccountType != null && oldAccountType != account.accountType) {
        final canChange = await _db.accountsDao.canChangeAccountType(account.id);
        if (!canChange) {
          throw ArgumentError('Cannot change account type: account has transactions');
        }
      }
      
      await (_db.update(_db.accounts)
        ..where((a) => a.id.equals(account.id))).write(
        AccountsCompanion(
          name: drift.Value(account.name),
          accountType: drift.Value(account.accountType),
          parentId: drift.Value(account.parentId),
          code: drift.Value(account.code),
          description: drift.Value(account.description),
          isPlaceholder: drift.Value(account.isPlaceholder),
          sortOrder: drift.Value(account.sortOrder),
          updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
          version: drift.Value(account.version + 1),
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteAccount(String id) async {
    state = const AsyncValue.loading();
    try {
      // VALIDATION: Check if account can be deleted
      final canDelete = await _db.accountsDao.canDeleteAccount(id);
      if (!canDelete) {
        final transactionCount = await _db.accountsDao.getTransactionCount(id);
        final childCount = await _db.accountsDao.getChildCount(id);
        throw ArgumentError('Cannot delete account: has $transactionCount transactions and $childCount child accounts');
      }
      
      await (_db.delete(_db.accounts)..where((a) => a.id.equals(id))).go();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ============================================================
  // REORDER METHODS - Drag-and-drop account reordering
  // ============================================================

  /// Reorders accounts within the same parent.
  /// 
  /// [accountIds] - List of account IDs in their new order.
  /// [parentId] - The parent account ID (null for root accounts).
  Future<void> reorderAccounts({
    required List<String> accountIds,
    String? parentId,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Update sortOrder for each account based on its position in the list
      for (var i = 0; i < accountIds.length; i++) {
        await (_db.update(_db.accounts)
          ..where((a) => a.id.equals(accountIds[i]))).write(
          AccountsCompanion(
            sortOrder: drift.Value(i),
            updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Moves an account to a new parent.
  /// 
  /// [accountId] - The account to move.
  /// [newParentId] - The new parent account ID (null to move to root).
  /// [newSortOrder] - Optional position in the new parent's children list.
  Future<void> moveAccount({
    required String accountId,
    String? newParentId,
    int? newSortOrder,
  }) async {
    state = const AsyncValue.loading();
    try {
      // VALIDATION: Check for circular reference
      if (newParentId != null) {
        final wouldCreateCycle = await _db.accountsDao.wouldCreateCircularReference(accountId, newParentId);
        if (wouldCreateCycle) {
          throw ArgumentError('Cannot move account: would create circular reference');
        }
      }
      
      // VALIDATION: Cannot make account its own parent
      if (newParentId == accountId) {
        throw ArgumentError('Cannot make account its own parent');
      }
      
      // Get the account to determine its type
      final account = await _db.accountsDao.getById(accountId);
      if (account == null) {
        throw ArgumentError('Account not found');
      }
      
      // If newParentId is provided, verify parent exists and has same type
      if (newParentId != null) {
        final newParent = await _db.accountsDao.getById(newParentId);
        if (newParent == null) {
          throw ArgumentError('New parent account not found');
        }
        // Allow moving to parent of same type only
        if (newParent.accountType != account.accountType) {
          throw ArgumentError('Cannot move account to parent of different type');
        }
      }
      
      // Determine the new sort order
      int sortOrder = newSortOrder ?? 0;
      if (newSortOrder == null && newParentId != null) {
        // Get current children of new parent to find max sortOrder
        final siblings = await _db.accountsDao.getChildren(newParentId);
        sortOrder = siblings.isEmpty ? 0 : siblings.map((s) => s.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
      } else if (newSortOrder == null) {
        // For root accounts, get max sortOrder for this type
        final rootAccounts = await _db.accountsDao.getRootAccountsByType(account.accountType);
        sortOrder = rootAccounts.isEmpty ? 0 : rootAccounts.map((s) => s.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
      }
      
      await (_db.update(_db.accounts)
        ..where((a) => a.id.equals(accountId))).write(
        AccountsCompanion(
          parentId: drift.Value(newParentId),
          sortOrder: drift.Value(sortOrder),
          updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
          version: drift.Value(account.version + 1),
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ============================================================
  // ACCOUNT CODE GENERATION - Hierarchy-based code generation
  // ============================================================

  /// Generates an account code based on hierarchy position.
  /// 
  /// Format: Root accounts get codes like "1000", "2000", etc.
  /// Children get codes like "1100", "1110", "1111" based on position.
  /// 
  /// [accountType] - The account type (ASSET=1xxx, LIABILITY=2xxx, etc.)
  /// [parentId] - The parent account ID (null for root).
  /// [position] - The position among siblings (0-indexed).
  Future<String> generateAccountCode({
    required String accountType,
    String? parentId,
    required int position,
  }) async {
    // Base codes for each account type
    final typeBaseCodes = {
      'ASSET': 1000,
      'LIABILITY': 2000,
      'EQUITY': 3000,
      'INCOME': 4000,
      'EXPENSE': 5000,
    };
    
    final baseCode = typeBaseCodes[accountType] ?? 1000;
    
    if (parentId == null) {
      // Root account: base code + position * 100
      // e.g., first ASSET root = 1000, second = 1100, third = 1200
      return '${baseCode + position * 100}';
    }
    
    // Get parent's code
    final parent = await _db.accountsDao.getById(parentId);
    if (parent == null || parent.code == null) {
      // If parent has no code, generate from base
      return '${baseCode + position * 100}';
    }
    
    // Parse parent code
    final parentCode = int.tryParse(parent.code!);
    if (parentCode == null) {
      return '${baseCode + position * 100}';
    }
    
    // Child code: parent code + position * 10 (for depth 2)
    // or parent code + position (for depth 3+)
    // Determine depth by counting digits
    final parentDepth = _getDepthFromCode(parentCode);
    
    if (parentDepth >= 3) {
      // At max depth (4 digits), just append position
      // This would create 5-digit codes which we avoid
      // Instead, use the last digit position
      final lastDigit = parentCode % 10;
      return '${parentCode - lastDigit + position.clamp(0, 9)}';
    }
    
    // Add a digit for the child position
    final multiplier = parentDepth == 1 ? 100 : 10;
    return '${parentCode + position * multiplier}';
  }
  
  /// Determines the depth level from a numeric account code.
  /// 1000 = depth 1 (root)
  /// 1100 = depth 2
  /// 1110 = depth 3
  /// 1111 = depth 4
  int _getDepthFromCode(int code) {
    if (code % 1000 == 0) return 1; // e.g., 1000, 2000
    if (code % 100 == 0) return 2;  // e.g., 1100, 2100
    if (code % 10 == 0) return 3;   // e.g., 1110, 2110
    return 4;                       // e.g., 1111, 2111
  }

  /// Regenerates codes for all accounts in a hierarchy branch.
  /// Useful after reordering to maintain consistent code numbering.
  Future<void> regenerateCodesForBranch(String parentId) async {
    state = const AsyncValue.loading();
    try {
      final children = await _db.accountsDao.getChildren(parentId);
      final parent = await _db.accountsDao.getById(parentId);
      
      for (var i = 0; i < children.length; i++) {
        final child = children[i];
        final newCode = await generateAccountCode(
          accountType: child.accountType,
          parentId: parentId,
          position: i,
        );
        
        await (_db.update(_db.accounts)
          ..where((a) => a.id.equals(child.id))).write(
          AccountsCompanion(
            code: drift.Value(newCode),
            sortOrder: drift.Value(i),
            updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
        
        // Recursively regenerate codes for grandchildren
        if (child.isPlaceholder) {
          await regenerateCodesForBranch(child.id);
        }
      }
      
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final accountNotifierProvider = StateNotifierProvider<AccountNotifier, AsyncValue<void>>((ref) {
  final db = ref.watch(databaseProvider);
  return AccountNotifier(db);
});

// ============================================================
// SEARCH & FILTER PROVIDERS
// ============================================================

/// Search query state provider
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Selected account type filter (null = all types)
final selectedAccountTypeFilterProvider = StateProvider<String?>((ref) => null);

/// Filtered account hierarchy based on search query and type filter
final filteredAccountHierarchyProvider = Provider<Map<String, List<AccountTreeNode>>>((ref) {
  final hierarchy = ref.watch(accountHierarchyProvider);
  final searchQuery = ref.watch(searchQueryProvider).toLowerCase().trim();
  final typeFilter = ref.watch(selectedAccountTypeFilterProvider);
  
  // If no filters, return original hierarchy
  if (searchQuery.isEmpty && typeFilter == null) {
    return hierarchy;
  }
  
  final result = <String, List<AccountTreeNode>>{};
  
  // Determine which types to show
  final typesToShow = typeFilter != null 
      ? [typeFilter] 
      : ['ASSET', 'LIABILITY', 'INCOME', 'EXPENSE'];
  
  for (final type in typesToShow) {
    final nodes = hierarchy[type];
    if (nodes == null || nodes.isEmpty) continue;
    
    // Filter nodes - show if node or any descendant matches search
    final filteredNodes = nodes
        .where((node) => _nodeMatchesFilter(node, searchQuery))
        .toList();
    
    if (filteredNodes.isNotEmpty) {
      result[type] = filteredNodes;
    }
  }
  
  return result;
});

/// Recursively check if node or any descendant matches search query
bool _nodeMatchesFilter(AccountTreeNode node, String searchQuery) {
  // If no search query, match all
  if (searchQuery.isEmpty) return true;
  
  // Check if this node's account name matches
  if (node.account.name.toLowerCase().contains(searchQuery)) {
    return true;
  }
  
  // Check if any child matches (recursive)
  for (final child in node.children) {
    if (_nodeMatchesFilter(child, searchQuery)) {
      return true;
    }
  }
  
  return false;
}