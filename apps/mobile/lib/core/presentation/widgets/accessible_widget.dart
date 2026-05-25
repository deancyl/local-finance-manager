import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/settings/data/accessibility_provider.dart';

/// A wrapper widget that provides accessibility enhancements based on settings.
/// 
/// Features:
/// - Enhanced focus indicators with customizable thickness
/// - Minimum touch target size enforcement
/// - Screen reader optimizations
class AccessibleWidget extends ConsumerWidget {
  final Widget child;
  final String? semanticLabel;
  final String? semanticHint;
  final bool? semanticButton;
  final double? minTouchTargetSize;
  final FocusNode? focusNode;
  final VoidCallback? onFocus;
  final VoidCallback? onUnfocus;

  const AccessibleWidget({
    super.key,
    required this.child,
    this.semanticLabel,
    this.semanticHint,
    this.semanticButton,
    this.minTouchTargetSize,
    this.focusNode,
    this.onFocus,
    this.onUnfocus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(accessibilityProvider);

    Widget result = child;

    // Apply semantic information for screen readers
    if (semanticLabel != null || semanticHint != null) {
      result = Semantics(
        label: semanticLabel,
        hint: semanticHint,
        button: semanticButton,
        child: result,
      );
    }

    // Apply enhanced focus indicators
    if (settings.enhancedFocusIndicators) {
      result = Focus(
        focusNode: focusNode,
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            onFocus?.call();
          } else {
            onUnfocus?.call();
          }
        },
        child: Builder(
          builder: (context) {
            final hasFocus = Focus.of(context).hasFocus;
            if (hasFocus) {
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: settings.focusIndicatorThickness,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: result,
              );
            }
            return result;
          },
        ),
      );
    }

    // Ensure minimum touch target size
    final touchSize = minTouchTargetSize ?? settings.minTouchTargetSize;
    result = _MinTouchTarget(
      minSize: touchSize,
      child: result,
    );

    return result;
  }
}

/// Widget that ensures a minimum touch target size for accessibility.
class _MinTouchTarget extends StatelessWidget {
  final double minSize;
  final Widget child;

  const _MinTouchTarget({
    required this.minSize,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minSize,
        minHeight: minSize,
      ),
      child: child,
    );
  }
}

/// Mixin for widgets that need accessibility support.
/// 
/// Provides helper methods for building accessible widgets.
mixin AccessibilityMixin {
  /// Build a tooltip that respects screen reader settings.
  Widget buildAccessibleTooltip({
    required String message,
    required Widget child,
    bool preferBelow = true,
  }) {
    return Tooltip(
      message: message,
      preferBelow: preferBelow,
      child: child,
    );
  }

  /// Build a button with proper accessibility support.
  Widget buildAccessibleButton({
    required String label,
    required String tooltip,
    required VoidCallback onPressed,
    required Widget child,
    bool enabled = true,
  }) {
    return Semantics(
      label: label,
      button: true,
      enabled: enabled,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: child,
        ),
      ),
    );
  }
}

/// Extension methods for making widgets more accessible.
extension AccessibilityExtensions on Widget {
  /// Add semantic label and hint for screen readers.
  Widget withSemantics({
    String? label,
    String? hint,
    bool? button,
    bool? enabled,
    bool? selected,
    bool? focused,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      button: button,
      enabled: enabled,
      selected: selected,
      focused: focused,
      child: this,
    );
  }

  /// Ensure minimum touch target size.
  Widget withMinTouchTarget(double minSize) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minSize,
        minHeight: minSize,
      ),
      child: this,
    );
  }

  /// Add accessible tooltip.
  Widget withTooltip(String message, {bool preferBelow = true}) {
    return Tooltip(
      message: message,
      preferBelow: preferBelow,
      child: this,
    );
  }
}
