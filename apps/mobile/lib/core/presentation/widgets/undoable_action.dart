import 'package:database/database.dart';

/// Represents an action that can be undone.
/// 
/// Stores the deleted transaction and its associated splits
/// for potential restoration within the undo window.
class UndoableAction {
  /// The deleted transaction
  final Transaction transaction;
  
  /// The splits associated with the transaction
  final List<Split> splits;
  
  /// When this action was performed (for timeout tracking)
  final DateTime performedAt;
  
  /// Type of action (currently only delete supported)
  final UndoableActionType type;

  const UndoableAction({
    required this.transaction,
    required this.splits,
    required this.performedAt,
    required this.type,
  });

  /// Creates an undoable delete action
  factory UndoableAction.delete({
    required Transaction transaction,
    required List<Split> splits,
  }) {
    return UndoableAction(
      transaction: transaction,
      splits: splits,
      performedAt: DateTime.now(),
      type: UndoableActionType.delete,
    );
  }

  /// Whether this action is still within the undo window
  bool isWithinUndoWindow(Duration window) {
    return DateTime.now().difference(performedAt) < window;
  }

  @override
  String toString() {
    return 'UndoableAction(type: $type, transactionId: ${transaction.id}, performedAt: $performedAt)';
  }
}

/// Types of actions that can be undone
enum UndoableActionType {
  delete,
  // Future: archive, move, etc.
}
