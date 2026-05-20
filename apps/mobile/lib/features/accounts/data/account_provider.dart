import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

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
      // VALIDATION: Check for circular reference
      if (parentId != null) {
        final wouldCreateCycle = await _wouldCreateCycle(parentId, parentId);
        if (wouldCreateCycle) {
          throw ArgumentError('Cannot set parent: would create circular reference');
        }
      }
      
      final id = const Uuid().v4();
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

  Future<void> updateAccount(Account account) async {
    state = const AsyncValue.loading();
    try {
      // VALIDATION: Check for circular reference
      if (account.parentId != null) {
        final wouldCreateCycle = await _wouldCreateCycle(account.id, account.parentId!);
        if (wouldCreateCycle) {
          throw ArgumentError('Cannot set parent: would create circular reference');
        }
      }
      
      // VALIDATION: Cannot make account its own parent
      if (account.parentId == account.id) {
        throw ArgumentError('Cannot make account its own parent');
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
      // VALIDATION: Check for children
      final children = await _db.accountsDao.getChildren(id);
      if (children.isNotEmpty) {
        throw ArgumentError('Cannot delete account with children. Move or delete children first.');
      }
      
      await (_db.delete(_db.accounts)..where((a) => a.id.equals(id))).go();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Checks if setting parentId would create a circular reference
  Future<bool> _wouldCreateCycle(String accountId, String newParentId) async {
    // Can't be own parent
    if (accountId == newParentId) return true;
    
    // Walk up the tree from newParentId to check if we reach accountId
    String? currentId = newParentId;
    final visited = <String>{};
    
    while (currentId != null) {
      if (visited.contains(currentId)) {
        // Cycle detected in existing tree (shouldn't happen, but safety check)
        return true;
      }
      visited.add(currentId);
      
      if (currentId == accountId) return true;
      
      final parent = await _db.accountsDao.getById(currentId);
      currentId = parent?.parentId;
    }
    
    return false;
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