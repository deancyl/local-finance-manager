import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/undo_redo_provider.dart';

/// Undo/Redo buttons for app bar
class UndoRedoButtons extends ConsumerWidget {
  const UndoRedoButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canUndo = ref.watch(canUndoProvider);
    final canRedo = ref.watch(canRedoProvider);
    final undoDesc = ref.watch(undoDescriptionProvider);
    final redoDesc = ref.watch(redoDescriptionProvider);
    final undoRedo = ref.read(undoRedoProvider.notifier);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Undo button
        IconButton(
          icon: const Icon(Icons.undo),
          tooltip: canUndo ? '撤销: $undoDesc' : '撤销',
          onPressed: canUndo
              ? () async {
                  try {
                    await undoRedo.undo();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('已撤销: $undoDesc'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('撤销失败: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              : null,
        ),
        // Redo button
        IconButton(
          icon: const Icon(Icons.redo),
          tooltip: canRedo ? '重做: $redoDesc' : '重做',
          onPressed: canRedo
              ? () async {
                  try {
                    await undoRedo.redo();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('已重做: $redoDesc'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('重做失败: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              : null,
        ),
      ],
    );
  }
}

/// Undo/Redo history panel
class UndoRedoHistoryPanel extends ConsumerWidget {
  const UndoRedoHistoryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(undoRedoProvider);
    final undoRedo = ref.read(undoRedoProvider.notifier);
    
    return AlertDialog(
      title: const Text('操作历史'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Undo stack
            if (state.undoStack.isNotEmpty) ...[
              Text(
                '可撤销的操作 (${state.undoStack.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: state.undoStack.length,
                  itemBuilder: (context, index) {
                    final reversedIndex = state.undoStack.length - 1 - index;
                    final command = state.undoStack[reversedIndex];
                    final isMostRecent = index == 0;
                    
                    return ListTile(
                      leading: Icon(
                        Icons.history,
                        color: isMostRecent 
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(
                        command.summary,
                        style: isMostRecent
                            ? TextStyle(fontWeight: FontWeight.bold)
                            : null,
                      ),
                      subtitle: Text(
                        _formatTimestamp(command.timestamp),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: isMostRecent
                          ? const Icon(Icons.arrow_back, size: 16)
                          : null,
                      onTap: isMostRecent
                          ? () async {
                              Navigator.of(context).pop();
                              await undoRedo.undo();
                            }
                          : null,
                    );
                  },
                ),
              ),
            ] else ...[
              const Center(
                child: Text('没有可撤销的操作'),
              ),
            ],
            
            const Divider(),
            
            // Redo stack
            if (state.redoStack.isNotEmpty) ...[
              Text(
                '可重做的操作 (${state.redoStack.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: state.redoStack.length,
                  itemBuilder: (context, index) {
                    final command = state.redoStack[index];
                    final isMostRecent = index == 0;
                    
                    return ListTile(
                      leading: Icon(
                        Icons.restore,
                        color: isMostRecent
                            ? Theme.of(context).colorScheme.secondary
                            : null,
                      ),
                      title: Text(command.summary),
                      subtitle: Text(
                        _formatTimestamp(command.timestamp),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: isMostRecent
                          ? const Icon(Icons.arrow_forward, size: 16)
                          : null,
                      onTap: isMostRecent
                          ? () async {
                              Navigator.of(context).pop();
                              await undoRedo.redo();
                            }
                          : null,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        if (state.undoStack.isNotEmpty || state.redoStack.isNotEmpty)
          TextButton(
            onPressed: () {
              undoRedo.clearHistory();
              Navigator.of(context).pop();
            },
            child: const Text('清空历史'),
          ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inSeconds < 60) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else {
      return '${diff.inDays}天前';
    }
  }
}

/// Undo/Redo status indicator for app bar
class UndoRedoStatus extends ConsumerWidget {
  const UndoRedoStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(undoRedoProvider);
    
    if (!state.canUndo && !state.canRedo) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.canUndo) ...[
            Icon(
              Icons.undo,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 2),
            Text(
              '${state.undoStack.length}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (state.canUndo && state.canRedo)
            const SizedBox(width: 8),
          if (state.canRedo) ...[
            Icon(
              Icons.redo,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 2),
            Text(
              '${state.redoStack.length}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Keyboard shortcuts for undo/redo
class UndoRedoShortcuts extends ConsumerWidget {
  final Widget child;

  const UndoRedoShortcuts({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final undoRedo = ref.read(undoRedoProvider.notifier);
    
    return Shortcuts(
      shortcuts: {
        // Ctrl+Z for undo
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyZ,
        ): UndoIntent(undoRedo),
        // Ctrl+Shift+Z for redo
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.keyZ,
        ): RedoIntent(undoRedo),
        // Ctrl+Y for redo (alternative)
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyY,
        ): RedoIntent(undoRedo),
      },
      child: Actions(
        actions: {
          UndoIntent: UndoAction(),
          RedoIntent: RedoAction(),
        },
        child: child,
      ),
    );
  }
}

// Intent classes for keyboard shortcuts
class UndoIntent extends Intent {
  final UndoRedoNotifier undoRedo;
  
  const UndoIntent(this.undoRedo);
}

class RedoIntent extends Intent {
  final UndoRedoNotifier undoRedo;
  
  const RedoIntent(this.undoRedo);
}

// Action classes for keyboard shortcuts
class UndoAction extends Action<UndoIntent> {
  @override
  Object? invoke(UndoIntent intent) {
    intent.undoRedo.undo();
    return null;
  }
}

class RedoAction extends Action<RedoIntent> {
  @override
  Object? invoke(RedoIntent intent) {
    intent.undoRedo.redo();
    return null;
  }
}
