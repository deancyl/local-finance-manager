import 'package:flutter/material.dart';

/// Shows an undo snackbar with a 5-second timeout.
/// 
/// This snackbar provides an "撤销" (Undo) action button that allows
/// users to restore a deleted item within the timeout window.
/// 
/// Usage:
/// ```dart
/// showUndoSnackBar(
///   context: context,
///   message: '交易已删除',
///   onUndo: () => restoreDeletedItem(),
/// );
/// ```
void showUndoSnackBar({
  required BuildContext context,
  required String message,
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 5),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(
            Icons.delete_outline,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.primary,
      duration: duration,
      action: SnackBarAction(
        label: '撤销',
        textColor: Colors.white,
        onPressed: onUndo,
      ),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}

/// Extension on BuildContext for showing undo snack bars.
extension UndoSnackBarExtension on BuildContext {
  /// Shows an undo snack bar with a customizable action.
  void showUndoSnackBar({
    required String message,
    required VoidCallback onUndo,
    Duration duration = const Duration(seconds: 5),
  }) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.delete_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(this).colorScheme.primary,
        duration: duration,
        action: SnackBarAction(
          label: '撤销',
          textColor: Colors.white,
          onPressed: onUndo,
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
