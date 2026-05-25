import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart' as uuid_pkg;

import 'package:database/database.dart';
import '../../accounts/data/account_provider.dart';

// ============================================================
// COMMAND PATTERN - Undoable Operations
// ============================================================

/// Base class for all undoable commands
abstract class UndoableCommand {
  final String id;
  final DateTime timestamp;
  final String description;
  
  UndoableCommand({
    String? id,
    DateTime? timestamp,
    required this.description,
  }) : id = id ?? const uuid_pkg.Uuid().v4(),
       timestamp = timestamp ?? DateTime.now();

  /// Execute the command
  Future<void> execute(LocalFinanceDatabase db);
  
  /// Undo the command
  Future<void> undo(LocalFinanceDatabase db);
  
  /// Get a summary of the command for display
  String get summary;
  
  /// Serialize to JSON for persistence
  Map<String, dynamic> toJson();
  
  /// Command type identifier for deserialization
  String get type;
}

/// Command for creating an account
class CreateAccountCommand extends UndoableCommand {
  final String accountId;
  final String name;
  final String accountType;
  final String commodityId;
  final String? parentId;
  final String? code;
  final String? accountDescription;
  final bool isPlaceholder;
  final int sortOrder;

  CreateAccountCommand({
    required this.accountId,
    required this.name,
    required this.accountType,
    required this.commodityId,
    this.parentId,
    this.code,
    this.accountDescription,
    this.isPlaceholder = false,
    this.sortOrder = 0,
    String? id,
    DateTime? timestamp,
  }) : super(
    id: id,
    timestamp: timestamp,
    description: '创建账户: $name',
  );

  @override
  String get type => 'create_account';

  @override
  String get summary => '创建账户 "$name"';

  @override
  Future<void> execute(LocalFinanceDatabase db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        id: accountId,
        name: name,
        accountType: accountType,
        commodityId: commodityId,
        parentId: drift.Value(parentId),
        code: drift.Value(code),
        description: drift.Value(accountDescription),
        isPlaceholder: drift.Value(isPlaceholder),
        isHidden: const drift.Value(false),
        sortOrder: drift.Value(sortOrder),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<void> undo(LocalFinanceDatabase db) async {
    await (db.delete(db.accounts)..where((a) => a.id.equals(accountId))).go();
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'description': description,
    'accountId': accountId,
    'name': name,
    'accountType': accountType,
    'commodityId': commodityId,
    'parentId': parentId,
    'code': code,
    'accountDescription': accountDescription,
    'isPlaceholder': isPlaceholder,
    'sortOrder': sortOrder,
  };

  factory CreateAccountCommand.fromJson(Map<String, dynamic> json) {
    return CreateAccountCommand(
      id: json['id'],
      accountId: json['accountId'],
      name: json['name'],
      accountType: json['accountType'],
      commodityId: json['commodityId'],
      parentId: json['parentId'],
      code: json['code'],
      accountDescription: json['accountDescription'],
      isPlaceholder: json['isPlaceholder'] ?? false,
      sortOrder: json['sortOrder'] ?? 0,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Command for updating an account
class UpdateAccountCommand extends UndoableCommand {
  final Account before;
  final Account after;

  UpdateAccountCommand({
    required this.before,
    required this.after,
    String? id,
    DateTime? timestamp,
  }) : super(
    id: id,
    timestamp: timestamp,
    description: '更新账户: ${after.name}',
  );

  @override
  String get type => 'update_account';

  @override
  String get summary => '更新账户 "${after.name}"';

  @override
  Future<void> execute(LocalFinanceDatabase db) async {
    await (db.update(db.accounts)..where((a) => a.id.equals(after.id))).write(
      AccountsCompanion(
        name: drift.Value(after.name),
        accountType: drift.Value(after.accountType),
        parentId: drift.Value(after.parentId),
        code: drift.Value(after.code),
        description: drift.Value(after.description),
        isPlaceholder: drift.Value(after.isPlaceholder),
        isHidden: drift.Value(after.isHidden),
        sortOrder: drift.Value(after.sortOrder),
        updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
        version: drift.Value(after.version + 1),
      ),
    );
  }

  @override
  Future<void> undo(LocalFinanceDatabase db) async {
    await (db.update(db.accounts)..where((a) => a.id.equals(before.id))).write(
      AccountsCompanion(
        name: drift.Value(before.name),
        accountType: drift.Value(before.accountType),
        parentId: drift.Value(before.parentId),
        code: drift.Value(before.code),
        description: drift.Value(before.description),
        isPlaceholder: drift.Value(before.isPlaceholder),
        isHidden: drift.Value(before.isHidden),
        sortOrder: drift.Value(before.sortOrder),
        updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
        version: drift.Value(before.version),
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'description': description,
    'before': {
      'id': before.id,
      'name': before.name,
      'accountType': before.accountType,
      'commodityId': before.commodityId,
      'parentId': before.parentId,
      'code': before.code,
      'description': before.description,
      'isPlaceholder': before.isPlaceholder,
      'isHidden': before.isHidden,
      'sortOrder': before.sortOrder,
      'createdAt': before.createdAt,
      'version': before.version,
    },
    'after': {
      'id': after.id,
      'name': after.name,
      'accountType': after.accountType,
      'commodityId': after.commodityId,
      'parentId': after.parentId,
      'code': after.code,
      'description': after.description,
      'isPlaceholder': after.isPlaceholder,
      'isHidden': after.isHidden,
      'sortOrder': after.sortOrder,
      'createdAt': after.createdAt,
      'version': after.version,
    },
  };

  factory UpdateAccountCommand.fromJson(Map<String, dynamic> json) {
    return UpdateAccountCommand(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      before: Account(
        id: json['before']['id'],
        name: json['before']['name'],
        accountType: json['before']['accountType'],
        commodityId: json['before']['commodityId'],
        parentId: json['before']['parentId'],
        code: json['before']['code'],
        description: json['before']['description'],
        isPlaceholder: json['before']['isPlaceholder'],
        isHidden: json['before']['isHidden'] ?? false,
        sortOrder: json['before']['sortOrder'],
        createdAt: json['before']['createdAt'],
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        version: json['before']['version'],
      ),
      after: Account(
        id: json['after']['id'],
        name: json['after']['name'],
        accountType: json['after']['accountType'],
        commodityId: json['after']['commodityId'],
        parentId: json['after']['parentId'],
        code: json['after']['code'],
        description: json['after']['description'],
        isPlaceholder: json['after']['isPlaceholder'],
        isHidden: json['after']['isHidden'] ?? false,
        sortOrder: json['after']['sortOrder'],
        createdAt: json['after']['createdAt'],
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        version: json['after']['version'],
      ),
    );
  }
}

/// Command for deleting an account
class DeleteAccountCommand extends UndoableCommand {
  final Account account;

  DeleteAccountCommand({
    required this.account,
    String? id,
    DateTime? timestamp,
  }) : super(
    id: id,
    timestamp: timestamp,
    description: '删除账户: ${account.name}',
  );

  @override
  String get type => 'delete_account';

  @override
  String get summary => '删除账户 "${account.name}"';

  @override
  Future<void> execute(LocalFinanceDatabase db) async {
    await (db.delete(db.accounts)..where((a) => a.id.equals(account.id))).go();
  }

  @override
  Future<void> undo(LocalFinanceDatabase db) async {
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        id: account.id,
        name: account.name,
        accountType: account.accountType,
        commodityId: account.commodityId,
        parentId: drift.Value(account.parentId),
        code: drift.Value(account.code),
        description: drift.Value(account.description),
        isPlaceholder: drift.Value(account.isPlaceholder),
        isHidden: drift.Value(account.isHidden),
        sortOrder: drift.Value(account.sortOrder),
        createdAt: account.createdAt,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'description': description,
    'account': {
      'id': account.id,
      'name': account.name,
      'accountType': account.accountType,
      'commodityId': account.commodityId,
      'parentId': account.parentId,
      'code': account.code,
      'description': account.description,
      'isPlaceholder': account.isPlaceholder,
      'isHidden': account.isHidden,
      'sortOrder': account.sortOrder,
      'createdAt': account.createdAt,
      'version': account.version,
    },
  };

  factory DeleteAccountCommand.fromJson(Map<String, dynamic> json) {
    final acc = json['account'];
    return DeleteAccountCommand(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      account: Account(
        id: acc['id'],
        name: acc['name'],
        accountType: acc['accountType'],
        commodityId: acc['commodityId'],
        parentId: acc['parentId'],
        code: acc['code'],
        description: acc['description'],
        isPlaceholder: acc['isPlaceholder'],
        isHidden: acc['isHidden'] ?? false,
        sortOrder: acc['sortOrder'],
        createdAt: acc['createdAt'],
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        version: acc['version'],
      ),
    );
  }
}

/// Command for creating a transaction with splits
class CreateTransactionCommand extends UndoableCommand {
  final String transactionId;
  final int postDate;
  final String currencyId;
  final String? transactionDescription;
  final String? notes;
  final List<SplitData> splits;

  CreateTransactionCommand({
    required this.transactionId,
    required this.postDate,
    required this.currencyId,
    this.transactionDescription,
    this.notes,
    required this.splits,
    String? id,
    DateTime? timestamp,
  }) : super(
    id: id,
    timestamp: timestamp,
    description: '创建交易: ${transactionDescription ?? "无描述"}',
  );

  @override
  String get type => 'create_transaction';

  @override
  String get summary => '创建交易 "${transactionDescription ?? "无描述"}"';

  @override
  Future<void> execute(LocalFinanceDatabase db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.transaction(() async {
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: transactionId,
          postDate: postDate,
          enterDate: now,
          currencyId: currencyId,
          description: drift.Value(transactionDescription),
          notes: drift.Value(notes),
          createdAt: now,
          updatedAt: now,
        ),
      );
      
      for (final split in splits) {
        await db.into(db.splits).insert(
          SplitsCompanion.insert(
            id: split.id,
            transactionId: transactionId,
            accountId: split.accountId,
            categoryId: drift.Value(split.categoryId),
            costCenterId: drift.Value(split.costCenterId),
            valueNum: split.valueNum,
            valueDenom: drift.Value(split.valueDenom),
            quantityNum: split.quantityNum,
            quantityDenom: drift.Value(split.quantityDenom),
            memo: drift.Value(split.memo),
            createdAt: now,
          ),
        );
      }
    });
  }

  @override
  Future<void> undo(LocalFinanceDatabase db) async {
    await db.transaction(() async {
      await (db.delete(db.splits)..where((s) => s.transactionId.equals(transactionId))).go();
      await (db.delete(db.transactions)..where((t) => t.id.equals(transactionId))).go();
    });
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'description': description,
    'transactionId': transactionId,
    'postDate': postDate,
    'currencyId': currencyId,
    'transactionDescription': transactionDescription,
    'notes': notes,
    'splits': splits.map((s) => s.toJson()).toList(),
  };

  factory CreateTransactionCommand.fromJson(Map<String, dynamic> json) {
    return CreateTransactionCommand(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      transactionId: json['transactionId'],
      postDate: json['postDate'],
      currencyId: json['currencyId'],
      transactionDescription: json['transactionDescription'],
      notes: json['notes'],
      splits: (json['splits'] as List).map((s) => SplitData.fromJson(s)).toList(),
    );
  }
}

/// Data class for split information
class SplitData {
  final String id;
  final String accountId;
  final String? categoryId;
  final String? costCenterId;
  final int valueNum;
  final int valueDenom;
  final int quantityNum;
  final int quantityDenom;
  final String? memo;

  const SplitData({
    required this.id,
    required this.accountId,
    this.categoryId,
    this.costCenterId,
    required this.valueNum,
    this.valueDenom = 100,
    required this.quantityNum,
    this.quantityDenom = 100,
    this.memo,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'accountId': accountId,
    'categoryId': categoryId,
    'costCenterId': costCenterId,
    'valueNum': valueNum,
    'valueDenom': valueDenom,
    'quantityNum': quantityNum,
    'quantityDenom': quantityDenom,
    'memo': memo,
  };

  factory SplitData.fromJson(Map<String, dynamic> json) {
    return SplitData(
      id: json['id'],
      accountId: json['accountId'],
      categoryId: json['categoryId'],
      costCenterId: json['costCenterId'],
      valueNum: json['valueNum'],
      valueDenom: json['valueDenom'] ?? 100,
      quantityNum: json['quantityNum'],
      quantityDenom: json['quantityDenom'] ?? 100,
      memo: json['memo'],
    );
  }
}

/// Command for updating a transaction
class UpdateTransactionCommand extends UndoableCommand {
  final Transaction before;
  final Transaction after;
  final List<Split> beforeSplits;
  final List<Split> afterSplits;

  UpdateTransactionCommand({
    required this.before,
    required this.after,
    required this.beforeSplits,
    required this.afterSplits,
    String? id,
    DateTime? timestamp,
  }) : super(
    id: id,
    timestamp: timestamp,
    description: '更新交易: ${after.description ?? "无描述"}',
  );

  @override
  String get type => 'update_transaction';

  @override
  String get summary => '更新交易 "${after.description ?? "无描述"}"';

  @override
  Future<void> execute(LocalFinanceDatabase db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.transaction(() async {
      await (db.update(db.transactions)..where((t) => t.id.equals(after.id))).write(
        TransactionsCompanion(
          postDate: drift.Value(after.postDate),
          description: drift.Value(after.description),
          notes: drift.Value(after.notes),
          updatedAt: drift.Value(now),
        ),
      );
      
      // Delete old splits and insert new ones
      await (db.delete(db.splits)..where((s) => s.transactionId.equals(after.id))).go();
      
      for (final split in afterSplits) {
        await db.into(db.splits).insert(
          SplitsCompanion.insert(
            id: split.id,
            transactionId: after.id,
            accountId: split.accountId,
            categoryId: drift.Value(split.categoryId),
            costCenterId: drift.Value(split.costCenterId),
            valueNum: split.valueNum,
            valueDenom: drift.Value(split.valueDenom),
            quantityNum: split.quantityNum,
            quantityDenom: drift.Value(split.quantityDenom),
            memo: drift.Value(split.memo),
            createdAt: split.createdAt,
          ),
        );
      }
    });
  }

  @override
  Future<void> undo(LocalFinanceDatabase db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.transaction(() async {
      await (db.update(db.transactions)..where((t) => t.id.equals(before.id))).write(
        TransactionsCompanion(
          postDate: drift.Value(before.postDate),
          description: drift.Value(before.description),
          notes: drift.Value(before.notes),
          updatedAt: drift.Value(now),
        ),
      );
      
      // Delete current splits and restore old ones
      await (db.delete(db.splits)..where((s) => s.transactionId.equals(before.id))).go();
      
      for (final split in beforeSplits) {
        await db.into(db.splits).insert(
          SplitsCompanion.insert(
            id: split.id,
            transactionId: before.id,
            accountId: split.accountId,
            categoryId: drift.Value(split.categoryId),
            costCenterId: drift.Value(split.costCenterId),
            valueNum: split.valueNum,
            valueDenom: drift.Value(split.valueDenom),
            quantityNum: split.quantityNum,
            quantityDenom: drift.Value(split.quantityDenom),
            memo: drift.Value(split.memo),
            createdAt: split.createdAt,
          ),
        );
      }
    });
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'description': description,
    'before': _transactionToJson(before),
    'after': _transactionToJson(after),
    'beforeSplits': beforeSplits.map(_splitToJson).toList(),
    'afterSplits': afterSplits.map(_splitToJson).toList(),
  };

  Map<String, dynamic> _transactionToJson(Transaction t) => {
    'id': t.id,
    'postDate': t.postDate,
    'enterDate': t.enterDate,
    'currencyId': t.currencyId,
    'description': t.description,
    'notes': t.notes,
    'createdAt': t.createdAt,
    'updatedAt': t.updatedAt,
    'version': t.version,
  };

  Map<String, dynamic> _splitToJson(Split s) => {
    'id': s.id,
    'transactionId': s.transactionId,
    'accountId': s.accountId,
    'categoryId': s.categoryId,
    'costCenterId': s.costCenterId,
    'valueNum': s.valueNum,
    'valueDenom': s.valueDenom,
    'quantityNum': s.quantityNum,
    'quantityDenom': s.quantityDenom,
    'memo': s.memo,
    'createdAt': s.createdAt,
  };

  factory UpdateTransactionCommand.fromJson(Map<String, dynamic> json) {
    // Note: Full deserialization would require more complex parsing
    // This is a simplified version
    throw UnimplementedError('Deserialization not implemented for UpdateTransactionCommand');
  }
}

/// Command for deleting a transaction
class DeleteTransactionCommand extends UndoableCommand {
  final Transaction transaction;
  final List<Split> splits;

  DeleteTransactionCommand({
    required this.transaction,
    required this.splits,
    String? id,
    DateTime? timestamp,
  }) : super(
    id: id,
    timestamp: timestamp,
    description: '删除交易: ${transaction.description ?? "无描述"}',
  );

  @override
  String get type => 'delete_transaction';

  @override
  String get summary => '删除交易 "${transaction.description ?? "无描述"}"';

  @override
  Future<void> execute(LocalFinanceDatabase db) async {
    await db.transaction(() async {
      await (db.delete(db.splits)..where((s) => s.transactionId.equals(transaction.id))).go();
      await (db.delete(db.transactions)..where((t) => t.id.equals(transaction.id))).go();
    });
  }

  @override
  Future<void> undo(LocalFinanceDatabase db) async {
    await db.transaction(() async {
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: transaction.id,
          postDate: transaction.postDate,
          enterDate: transaction.enterDate,
          currencyId: transaction.currencyId,
          description: drift.Value(transaction.description),
          notes: drift.Value(transaction.notes),
          createdAt: transaction.createdAt,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      
      for (final split in splits) {
        await db.into(db.splits).insert(
          SplitsCompanion.insert(
            id: split.id,
            transactionId: transaction.id,
            accountId: split.accountId,
            categoryId: drift.Value(split.categoryId),
            costCenterId: drift.Value(split.costCenterId),
            valueNum: split.valueNum,
            valueDenom: drift.Value(split.valueDenom),
            quantityNum: split.quantityNum,
            quantityDenom: drift.Value(split.quantityDenom),
            memo: drift.Value(split.memo),
            createdAt: split.createdAt,
          ),
        );
      }
    });
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'description': description,
    'transaction': {
      'id': transaction.id,
      'postDate': transaction.postDate,
      'enterDate': transaction.enterDate,
      'currencyId': transaction.currencyId,
      'description': transaction.description,
      'notes': transaction.notes,
      'createdAt': transaction.createdAt,
      'updatedAt': transaction.updatedAt,
      'version': transaction.version,
    },
    'splits': splits.map((s) => {
      'id': s.id,
      'accountId': s.accountId,
      'categoryId': s.categoryId,
      'costCenterId': s.costCenterId,
      'valueNum': s.valueNum,
      'valueDenom': s.valueDenom,
      'quantityNum': s.quantityNum,
      'quantityDenom': s.quantityDenom,
      'memo': s.memo,
      'createdAt': s.createdAt,
    }).toList(),
  };

  factory DeleteTransactionCommand.fromJson(Map<String, dynamic> json) {
    throw UnimplementedError('Deserialization not implemented for DeleteTransactionCommand');
  }
}

// ============================================================
// UNDO/REDO MANAGER
// ============================================================

/// State for the undo/redo system
class UndoRedoState {
  final List<UndoableCommand> undoStack;
  final List<UndoableCommand> redoStack;
  final int maxStackSize;

  const UndoRedoState({
    this.undoStack = const [],
    this.redoStack = const [],
    this.maxStackSize = 50,
  });

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
  
  String? get undoDescription => undoStack.isNotEmpty ? undoStack.last.description : null;
  String? get redoDescription => redoStack.isNotEmpty ? redoStack.last.description : null;

  UndoRedoState copyWith({
    List<UndoableCommand>? undoStack,
    List<UndoableCommand>? redoStack,
  }) {
    return UndoRedoState(
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      maxStackSize: maxStackSize,
    );
  }
}

/// Notifier for managing undo/redo operations
class UndoRedoNotifier extends StateNotifier<UndoRedoState> {
  final LocalFinanceDatabase _db;
  final Ref _ref;

  UndoRedoNotifier(this._db, this._ref) : super(const UndoRedoState());

  /// Execute a command and add it to the undo stack
  Future<void> executeCommand(UndoableCommand command) async {
    try {
      await command.execute(_db);
      
      // Add to undo stack, clear redo stack
      final newUndoStack = [...state.undoStack, command];
      
      // Limit stack size
      if (newUndoStack.length > state.maxStackSize) {
        newUndoStack.removeAt(0);
      }
      
      state = state.copyWith(
        undoStack: newUndoStack,
        redoStack: [], // Clear redo stack on new action
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Undo the last command
  Future<void> undo() async {
    if (!state.canUndo) return;
    
    final command = state.undoStack.last;
    
    try {
      await command.undo(_db);
      
      // Move from undo to redo stack
      state = state.copyWith(
        undoStack: state.undoStack.sublist(0, state.undoStack.length - 1),
        redoStack: [...state.redoStack, command],
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Redo the last undone command
  Future<void> redo() async {
    if (!state.canRedo) return;
    
    final command = state.redoStack.last;
    
    try {
      await command.execute(_db);
      
      // Move from redo to undo stack
      state = state.copyWith(
        undoStack: [...state.undoStack, command],
        redoStack: state.redoStack.sublist(0, state.redoStack.length - 1),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Clear all undo/redo history
  void clearHistory() {
    state = const UndoRedoState();
  }

  /// Get undo history for display
  List<UndoableCommand> getUndoHistory({int limit = 10}) {
    return state.undoStack.reversed.take(limit).toList();
  }

  /// Get redo history for display
  List<UndoableCommand> getRedoHistory({int limit = 10}) {
    return state.redoStack.reversed.take(limit).toList();
  }
}

/// Provider for undo/redo state
final undoRedoProvider = StateNotifierProvider<UndoRedoNotifier, UndoRedoState>((ref) {
  final db = ref.watch(databaseProvider);
  return UndoRedoNotifier(db, ref);
});

/// Provider for checking if undo is available
final canUndoProvider = Provider<bool>((ref) {
  return ref.watch(undoRedoProvider).canUndo;
});

/// Provider for checking if redo is available
final canRedoProvider = Provider<bool>((ref) {
  return ref.watch(undoRedoProvider).canRedo;
});

/// Provider for undo description
final undoDescriptionProvider = Provider<String?>((ref) {
  return ref.watch(undoRedoProvider).undoDescription;
});

/// Provider for redo description
final redoDescriptionProvider = Provider<String?>((ref) {
  return ref.watch(undoRedoProvider).redoDescription;
});

// ============================================================
// HELPER EXTENSIONS
// ============================================================

/// Extension to easily add undo/redo support to operations
extension UndoRedoExtension on UndoRedoNotifier {
  /// Execute a create account operation with undo support
  Future<void> createAccountWithUndo({
    required String name,
    required String accountType,
    required String commodityId,
    String? parentId,
    String? code,
    String? accountDescription,
    bool isPlaceholder = false,
    int sortOrder = 0,
  }) async {
    final accountId = const uuid_pkg.Uuid().v4();
    
    await executeCommand(
      CreateAccountCommand(
        accountId: accountId,
        name: name,
        accountType: accountType,
        commodityId: commodityId,
        parentId: parentId,
        code: code,
        accountDescription: accountDescription,
        isPlaceholder: isPlaceholder,
        sortOrder: sortOrder,
      ),
    );
  }

  /// Execute an update account operation with undo support
  Future<void> updateAccountWithUndo(Account before, Account after) async {
    await executeCommand(
      UpdateAccountCommand(before: before, after: after),
    );
  }

  /// Execute a delete account operation with undo support
  Future<void> deleteAccountWithUndo(Account account) async {
    await executeCommand(
      DeleteAccountCommand(account: account),
    );
  }

  /// Execute a create transaction operation with undo support
  Future<void> createTransactionWithUndo({
    required String transactionId,
    required int postDate,
    required String currencyId,
    String? transactionDescription,
    String? notes,
    required List<SplitData> splits,
  }) async {
    await executeCommand(
      CreateTransactionCommand(
        transactionId: transactionId,
        postDate: postDate,
        currencyId: currencyId,
        transactionDescription: transactionDescription,
        notes: notes,
        splits: splits,
      ),
    );
  }

  /// Execute an update transaction operation with undo support
  Future<void> updateTransactionWithUndo({
    required Transaction before,
    required Transaction after,
    required List<Split> beforeSplits,
    required List<Split> afterSplits,
  }) async {
    await executeCommand(
      UpdateTransactionCommand(
        before: before,
        after: after,
        beforeSplits: beforeSplits,
        afterSplits: afterSplits,
      ),
    );
  }

  /// Execute a delete transaction operation with undo support
  Future<void> deleteTransactionWithUndo({
    required Transaction transaction,
    required List<Split> splits,
  }) async {
    await executeCommand(
      DeleteTransactionCommand(
        transaction: transaction,
        splits: splits,
      ),
    );
  }
}
