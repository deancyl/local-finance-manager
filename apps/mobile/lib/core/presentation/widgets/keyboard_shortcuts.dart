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
  saveDraft,
  edit,
  delete,
  search,
  escape,
  tabNext,
  tabPrevious,
  submit,
  addNew,
  toggleMode,
  quickAmount10,
  quickAmount50,
  quickAmount100,
  quickAmount500,
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
    final isAltPressed = HardwareKeyboard.instance.isAltPressed;

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

    // Ctrl+Shift+S: Save draft
    if (isCtrlPressed && isShiftPressed && event.logicalKey == LogicalKeyboardKey.keyS) {
      widget.onShortcut?.call(ShortcutAction.saveDraft);
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

    // Enter: Submit form
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      widget.onShortcut?.call(ShortcutAction.submit);
      return KeyEventResult.handled;
    }

    // Ctrl+A: Add new entry (batch mode)
    if (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyA) {
      widget.onShortcut?.call(ShortcutAction.addNew);
      return KeyEventResult.handled;
    }

    // Ctrl+M: Toggle entry mode
    if (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyM) {
      widget.onShortcut?.call(ShortcutAction.toggleMode);
      return KeyEventResult.handled;
    }

    // Alt+1: Quick amount 10
    if (isAltPressed && event.logicalKey == LogicalKeyboardKey.key1) {
      widget.onShortcut?.call(ShortcutAction.quickAmount10);
      return KeyEventResult.handled;
    }

    // Alt+2: Quick amount 50
    if (isAltPressed && event.logicalKey == LogicalKeyboardKey.key2) {
      widget.onShortcut?.call(ShortcutAction.quickAmount50);
      return KeyEventResult.handled;
    }

    // Alt+3: Quick amount 100
    if (isAltPressed && event.logicalKey == LogicalKeyboardKey.key3) {
      widget.onShortcut?.call(ShortcutAction.quickAmount100);
      return KeyEventResult.handled;
    }

    // Alt+4: Quick amount 500
    if (isAltPressed && event.logicalKey == LogicalKeyboardKey.key4) {
      widget.onShortcut?.call(ShortcutAction.quickAmount500);
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
  final VoidCallback? onSaveDraft;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSearch;
  final VoidCallback? onEscape;
  final VoidCallback? onTabNext;
  final VoidCallback? onTabPrevious;
  final VoidCallback? onSubmit;
  final VoidCallback? onAddNew;
  final VoidCallback? onToggleMode;
  final VoidCallback? onQuickAmount10;
  final VoidCallback? onQuickAmount50;
  final VoidCallback? onQuickAmount100;
  final VoidCallback? onQuickAmount500;

  const ShortcutsActionWidget({
    super.key,
    required this.child,
    this.onNewTransaction,
    this.onSave,
    this.onSaveDraft,
    this.onEdit,
    this.onDelete,
    this.onSearch,
    this.onEscape,
    this.onTabNext,
    this.onTabPrevious,
    this.onSubmit,
    this.onAddNew,
    this.onToggleMode,
    this.onQuickAmount10,
    this.onQuickAmount50,
    this.onQuickAmount100,
    this.onQuickAmount500,
  });

  void _handleShortcut(ShortcutAction action, BuildContext context) {
    switch (action) {
      case ShortcutAction.newTransaction:
        onNewTransaction?.call();
        break;
      case ShortcutAction.save:
        onSave?.call();
        break;
      case ShortcutAction.saveDraft:
        onSaveDraft?.call();
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
      case ShortcutAction.submit:
        onSubmit?.call();
        break;
      case ShortcutAction.addNew:
        onAddNew?.call();
        break;
      case ShortcutAction.toggleMode:
        onToggleMode?.call();
        break;
      case ShortcutAction.quickAmount10:
        onQuickAmount10?.call();
        break;
      case ShortcutAction.quickAmount50:
        onQuickAmount50?.call();
        break;
      case ShortcutAction.quickAmount100:
        onQuickAmount100?.call();
        break;
      case ShortcutAction.quickAmount500:
        onQuickAmount500?.call();
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
      label: 'Save Draft',
      description: 'Save current entry as draft',
      windowsKey: 'Ctrl+Shift+S',
      macOSKey: '⌘⇧S',
      linuxKey: 'Ctrl+Shift+S',
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
    ShortcutDefinition(
      label: 'Submit',
      description: 'Submit the current entry',
      windowsKey: 'Enter',
      macOSKey: 'Enter',
      linuxKey: 'Enter',
    ),
    ShortcutDefinition(
      label: 'Add New (Batch)',
      description: 'Add new entry in batch mode',
      windowsKey: 'Ctrl+A',
      macOSKey: '⌘A',
      linuxKey: 'Ctrl+A',
    ),
    ShortcutDefinition(
      label: 'Toggle Mode',
      description: 'Toggle entry mode',
      windowsKey: 'Ctrl+M',
      macOSKey: '⌘M',
      linuxKey: 'Ctrl+M',
    ),
    ShortcutDefinition(
      label: 'Quick Amount 10',
      description: 'Set amount to ¥10',
      windowsKey: 'Alt+1',
      macOSKey: '⌥1',
      linuxKey: 'Alt+1',
    ),
    ShortcutDefinition(
      label: 'Quick Amount 50',
      description: 'Set amount to ¥50',
      windowsKey: 'Alt+2',
      macOSKey: '⌥2',
      linuxKey: 'Alt+2',
    ),
    ShortcutDefinition(
      label: 'Quick Amount 100',
      description: 'Set amount to ¥100',
      windowsKey: 'Alt+3',
      macOSKey: '⌥3',
      linuxKey: 'Alt+3',
    ),
    ShortcutDefinition(
      label: 'Quick Amount 500',
      description: 'Set amount to ¥500',
      windowsKey: 'Alt+4',
      macOSKey: '⌥4',
      linuxKey: 'Alt+4',
    ),
  ];
}
