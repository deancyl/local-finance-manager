import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

/// Keyboard shortcuts for desktop platforms
/// Provides Ctrl+N, Ctrl+S, Ctrl+E, Ctrl+D, Ctrl+F, Escape, Tab navigation

/// Shortcut action types
enum ShortcutAction {
  newTransaction,
  save,
  edit,
  delete,
  search,
  escape,
  tabNext,
  tabPrevious,
}

/// Callback type for shortcut actions
typedef ShortcutCallback = void Function(ShortcutAction action);

/// Platform-aware keyboard shortcuts widget
/// Wraps child with keyboard listeners on desktop platforms
class KeyboardShortcuts extends ConsumerStatefulWidget {
  final Widget child;
  final ShortcutCallback? onShortcut;
  final bool enabled;

  const KeyboardShortcuts({
    super.key,
    required this.child,
    this.onShortcut,
    this.enabled = true,
  });

  @override
  ConsumerState<KeyboardShortcuts> createState() => _KeyboardShortcutsState();
}

class _KeyboardShortcutsState extends ConsumerState<KeyboardShortcuts> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isDesktop {
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

    // Ctrl+N: New transaction
    if (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyN) {
      widget.onShortcut?.call(ShortcutAction.newTransaction);
      return KeyEventResult.handled;
    }

    // Ctrl+S: Save current form
    if (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyS) {
      widget.onShortcut?.call(ShortcutAction.save);
      return KeyEventResult.handled;
    }

    // Ctrl+E: Edit selected item
    if (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyE) {
      widget.onShortcut?.call(ShortcutAction.edit);
      return KeyEventResult.handled;
    }

    // Ctrl+D: Delete selected item
    if (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyD) {
      widget.onShortcut?.call(ShortcutAction.delete);
      return KeyEventResult.handled;
    }

    // Ctrl+F: Search
    if (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyF) {
      widget.onShortcut?.call(ShortcutAction.search);
      return KeyEventResult.handled;
    }

    // Escape: Close dialog/go back
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onShortcut?.call(ShortcutAction.escape);
      return KeyEventResult.handled;
    }

    // Tab: Navigate between fields
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      if (isShiftPressed) {
        widget.onShortcut?.call(ShortcutAction.tabPrevious);
      } else {
        widget.onShortcut?.call(ShortcutAction.tabNext);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) {
      return widget.child;
    }

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: widget.child,
    );
  }
}

/// Shortcuts action widget that provides default implementations
class ShortcutsActionWidget extends StatelessWidget {
  final Widget child;
  final VoidCallback? onNewTransaction;
  final VoidCallback? onSave;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSearch;
  final VoidCallback? onEscape;
  final VoidCallback? onTabNext;
  final VoidCallback? onTabPrevious;

  const ShortcutsActionWidget({
    super.key,
    required this.child,
    this.onNewTransaction,
    this.onSave,
    this.onEdit,
    this.onDelete,
    this.onSearch,
    this.onEscape,
    this.onTabNext,
    this.onTabPrevious,
  });

  void _handleShortcut(ShortcutAction action, BuildContext context) {
    switch (action) {
      case ShortcutAction.newTransaction:
        onNewTransaction?.call();
        break;
      case ShortcutAction.save:
        onSave?.call();
        break;
      case ShortcutAction.edit:
        onEdit?.call();
        break;
      case ShortcutAction.delete:
        onDelete?.call();
        break;
      case ShortcutAction.search:
        onSearch?.call();
        break;
      case ShortcutAction.escape:
        onEscape?.call();
        break;
      case ShortcutAction.tabNext:
        onTabNext?.call();
        break;
      case ShortcutAction.tabPrevious:
        onTabPrevious?.call();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardShortcuts(
      onShortcut: (action) => _handleShortcut(action, context),
      child: child,
    );
  }
}

/// Shortcut definition for display purposes
class ShortcutDefinition {
  final String label;
  final String description;
  final String windowsKey;
  final String macOSKey;
  final String linuxKey;

  const ShortcutDefinition({
    required this.label,
    required this.description,
    required this.windowsKey,
    required this.macOSKey,
    required this.linuxKey,
  });

  String getKeyForPlatform() {
    try {
      if (Platform.isMacOS) return macOSKey;
      if (Platform.isLinux) return linuxKey;
      return windowsKey;
    } catch (_) {
      return windowsKey;
    }
  }
}

/// All available keyboard shortcuts
class AppShortcuts {
  static const List<ShortcutDefinition> all = [
    ShortcutDefinition(
      label: 'New Transaction',
      description: 'Create a new transaction',
      windowsKey: 'Ctrl+N',
      macOSKey: '⌘N',
      linuxKey: 'Ctrl+N',
    ),
    ShortcutDefinition(
      label: 'Save',
      description: 'Save the current form',
      windowsKey: 'Ctrl+S',
      macOSKey: '⌘S',
      linuxKey: 'Ctrl+S',
    ),
    ShortcutDefinition(
      label: 'Edit',
      description: 'Edit the selected item',
      windowsKey: 'Ctrl+E',
      macOSKey: '⌘E',
      linuxKey: 'Ctrl+E',
    ),
    ShortcutDefinition(
      label: 'Delete',
      description: 'Delete the selected item',
      windowsKey: 'Ctrl+D',
      macOSKey: '⌘D',
      linuxKey: 'Ctrl+D',
    ),
    ShortcutDefinition(
      label: 'Search',
      description: 'Open search',
      windowsKey: 'Ctrl+F',
      macOSKey: '⌘F',
      linuxKey: 'Ctrl+F',
    ),
    ShortcutDefinition(
      label: 'Escape',
      description: 'Close dialog or go back',
      windowsKey: 'Esc',
      macOSKey: 'Esc',
      linuxKey: 'Esc',
    ),
    ShortcutDefinition(
      label: 'Tab Navigation',
      description: 'Navigate between fields',
      windowsKey: 'Tab / Shift+Tab',
      macOSKey: 'Tab / ⇧Tab',
      linuxKey: 'Tab / Shift+Tab',
    ),
  ];
}
