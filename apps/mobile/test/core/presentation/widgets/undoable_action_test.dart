import 'package:flutter_test/flutter_test.dart';
import 'package:finance_app/core/presentation/widgets/undoable_action.dart';
import 'package:database/database.dart';

void main() {
  group('UndoableAction', () {
    test('creates delete action with correct properties', () {
      final transaction = Transaction(
        id: 'test-transaction-id',
        postDate: DateTime.now().millisecondsSinceEpoch,
        enterDate: DateTime.now().millisecondsSinceEpoch,
        currencyId: 'CNY',
        description: 'Test transaction',
        notes: 'Test notes',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      
      final splits = [
        Split(
          id: 'test-split-id',
          transactionId: 'test-transaction-id',
          accountId: 'test-account-id',
          valueNum: 10000,
          quantityNum: 10000,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      ];
      
      final action = UndoableAction.delete(
        transaction: transaction,
        splits: splits,
      );
      
      expect(action.type, UndoableActionType.delete);
      expect(action.transaction.id, 'test-transaction-id');
      expect(action.splits.length, 1);
      expect(action.splits.first.transactionId, 'test-transaction-id');
    });

    test('isWithinUndoWindow returns true for recent action', () {
      final transaction = Transaction(
        id: 'test-id',
        postDate: DateTime.now().millisecondsSinceEpoch,
        enterDate: DateTime.now().millisecondsSinceEpoch,
        currencyId: 'CNY',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      
      final action = UndoableAction.delete(
        transaction: transaction,
        splits: [],
      );
      
      // Should be within 5 second window immediately after creation
      expect(action.isWithinUndoWindow(const Duration(seconds: 5)), true);
    });

    test('isWithinUndoWindow returns false for old action', () {
      final transaction = Transaction(
        id: 'test-id',
        postDate: DateTime.now().millisecondsSinceEpoch,
        enterDate: DateTime.now().millisecondsSinceEpoch,
        currencyId: 'CNY',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      
      final action = UndoableAction(
        transaction: transaction,
        splits: [],
        performedAt: DateTime.now().subtract(const Duration(seconds: 10)),
        type: UndoableActionType.delete,
      );
      
      // Should be outside 5 second window after 10 seconds
      expect(action.isWithinUndoWindow(const Duration(seconds: 5)), false);
    });
  });
}