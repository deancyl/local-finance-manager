import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Gesture action types
enum GestureAction {
  delete,
  edit,
  duplicate,
  archive,
  categorize,
  addNote,
  transfer,
  none,
}

/// Gesture configuration for user-customizable gestures
class GestureConfig {
  final GestureAction swipeLeft;
  final GestureAction swipeRight;
  final GestureAction longPress;
  final GestureAction doubleTap;
  final bool enableHapticFeedback;
  final double swipeThreshold;
  final Duration longPressDuration;

  const GestureConfig({
    this.swipeLeft = GestureAction.delete,
    this.swipeRight = GestureAction.edit,
    this.longPress = GestureAction.categorize,
    this.doubleTap = GestureAction.duplicate,
    this.enableHapticFeedback = true,
    this.swipeThreshold = 0.25,
    this.longPressDuration = const Duration(milliseconds: 500),
  });

  GestureConfig copyWith({
    GestureAction? swipeLeft,
    GestureAction? swipeRight,
    GestureAction? longPress,
    GestureAction? doubleTap,
    bool? enableHapticFeedback,
    double? swipeThreshold,
    Duration? longPressDuration,
  }) {
    return GestureConfig(
      swipeLeft: swipeLeft ?? this.swipeLeft,
      swipeRight: swipeRight ?? this.swipeRight,
      longPress: longPress ?? this.longPress,
      doubleTap: doubleTap ?? this.doubleTap,
      enableHapticFeedback: enableHapticFeedback ?? this.enableHapticFeedback,
      swipeThreshold: swipeThreshold ?? this.swipeThreshold,
      longPressDuration: longPressDuration ?? this.longPressDuration,
    );
  }
}

/// Swipeable widget with left/right actions
class SwipeableAction extends StatefulWidget {
  final Widget child;
  final GestureAction leftAction;
  final GestureAction rightAction;
  final VoidCallback? onLeftSwipe;
  final VoidCallback? onRightSwipe;
  final bool enableHapticFeedback;
  final double threshold;
  final Color? leftBackgroundColor;
  final Color? rightBackgroundColor;
  final IconData? leftIcon;
  final IconData? rightIcon;

  const SwipeableAction({
    super.key,
    required this.child,
    this.leftAction = GestureAction.delete,
    this.rightAction = GestureAction.edit,
    this.onLeftSwipe,
    this.onRightSwipe,
    this.enableHapticFeedback = true,
    this.threshold = 0.25,
    this.leftBackgroundColor,
    this.rightBackgroundColor,
    this.leftIcon,
    this.rightIcon,
  });

  @override
  State<SwipeableAction> createState() => _SwipeableActionState();
}

class _SwipeableActionState extends State<SwipeableAction>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragExtent = 0;
  bool _dragUnderway = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    _dragUnderway = true;
    _dragExtent = 0.0;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_dragUnderway) return;

    final delta = details.primaryDelta ?? 0;
    _dragExtent += delta;

    setState(() {
      _controller.value = (_dragExtent.abs() / 200).clamp(0.0, 1.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    _dragUnderway = false;
    final threshold = widget.threshold * 200;

    if (_dragExtent.abs() > threshold) {
      if (_dragExtent > 0 && widget.onRightSwipe != null) {
        _triggerAction(widget.rightAction, widget.onRightSwipe!);
      } else if (_dragExtent < 0 && widget.onLeftSwipe != null) {
        _triggerAction(widget.leftAction, widget.onLeftSwipe!);
      }
    }

    _controller.reverse();
    setState(() {
      _dragExtent = 0;
    });
  }

  void _triggerAction(GestureAction action, VoidCallback callback) {
    if (widget.enableHapticFeedback) {
      HapticFeedback.mediumImpact();
    }
    callback();
  }

  @override
  Widget build(BuildContext context) {
    final leftColor = widget.leftBackgroundColor ??
        _getActionColor(widget.leftAction);
    final rightColor = widget.rightBackgroundColor ??
        _getActionColor(widget.rightAction);
    final leftIcon = widget.leftIcon ?? _getActionIcon(widget.leftAction);
    final rightIcon = widget.rightIcon ?? _getActionIcon(widget.rightAction);

    return GestureDetector(
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Stack(
        children: [
          // Left action background
          Positioned.fill(
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: _dragExtent < 0 ? _dragExtent.abs() : 0,
                      color: leftColor,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(width: 20),
                          Icon(leftIcon, color: Colors.white),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Right action background
          Positioned.fill(
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: _dragExtent > 0 ? _dragExtent : 0,
                      color: rightColor,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(rightIcon, color: Colors.white),
                          const SizedBox(width: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Main content
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_dragExtent, 0),
                child: child,
              );
            },
            child: widget.child,
          ),
        ],
      ),
    );
  }

  Color _getActionColor(GestureAction action) {
    switch (action) {
      case GestureAction.delete:
        return Colors.red;
      case GestureAction.edit:
        return Colors.blue;
      case GestureAction.duplicate:
        return Colors.green;
      case GestureAction.archive:
        return Colors.orange;
      case GestureAction.categorize:
        return Colors.purple;
      case GestureAction.addNote:
        return Colors.teal;
      case GestureAction.transfer:
        return Colors.indigo;
      case GestureAction.none:
        return Colors.grey;
    }
  }

  IconData _getActionIcon(GestureAction action) {
    switch (action) {
      case GestureAction.delete:
        return Icons.delete;
      case GestureAction.edit:
        return Icons.edit;
      case GestureAction.duplicate:
        return Icons.copy;
      case GestureAction.archive:
        return Icons.archive;
      case GestureAction.categorize:
        return Icons.category;
      case GestureAction.addNote:
        return Icons.note_add;
      case GestureAction.transfer:
        return Icons.swap_horiz;
      case GestureAction.none:
        return Icons.block;
    }
  }
}

/// Pull-to-refresh wrapper with customizable refresh indicator
class PullToRefresh extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? indicatorColor;
  final Color? backgroundColor;

  const PullToRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.indicatorColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: indicatorColor ?? Theme.of(context).colorScheme.primary,
      backgroundColor: backgroundColor,
      child: child,
    );
  }
}

/// Pinch-to-zoom wrapper for charts and images
class PinchToZoom extends StatefulWidget {
  final Widget child;
  final double minScale;
  final double maxScale;
  final bool enableHapticFeedback;
  final void Function(double scale)? onScaleChanged;

  const PinchToZoom({
    super.key,
    required this.child,
    this.minScale = 0.5,
    this.maxScale = 3.0,
    this.enableHapticFeedback = true,
    this.onScaleChanged,
  });

  @override
  State<PinchToZoom> createState() => _PinchToZoomState();
}

class _PinchToZoomState extends State<PinchToZoom> {
  double _scale = 1.0;
  double _prevScale = 1.0;

  void _handleScaleStart(ScaleStartDetails details) {
    _prevScale = _scale;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final newScale = (_prevScale * details.scale).clamp(
      widget.minScale,
      widget.maxScale,
    );

    if (newScale != _scale) {
      setState(() {
        _scale = newScale;
      });

      if (widget.enableHapticFeedback && (newScale == widget.minScale || newScale == widget.maxScale)) {
        HapticFeedback.lightImpact();
      }

      widget.onScaleChanged?.call(_scale);
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (_scale < 1.0) {
      setState(() {
        _scale = 1.0;
      });
      widget.onScaleChanged?.call(1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: _handleScaleStart,
      onScaleUpdate: _handleScaleUpdate,
      onScaleEnd: _handleScaleEnd,
      child: Transform.scale(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}

/// Long-press context menu wrapper
class LongPressMenu extends StatelessWidget {
  final Widget child;
  final List<PopupMenuEntry<GestureAction>> Function(BuildContext) itemBuilder;
  final void Function(GestureAction)? onSelected;
  final bool enableHapticFeedback;
  final Duration longPressDuration;

  const LongPressMenu({
    super.key,
    required this.child,
    required this.itemBuilder,
    this.onSelected,
    this.enableHapticFeedback = true,
    this.longPressDuration = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        if (enableHapticFeedback) {
          HapticFeedback.heavyImpact();
        }
        _showMenu(context);
      },
      onLongPressStart: (details) {
        if (enableHapticFeedback) {
          HapticFeedback.selectionClick();
        }
      },
      child: child,
    );
  }

  void _showMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);

    showMenu<GestureAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(buttonPosition.dx, buttonPosition.dy, button.size.width, button.size.height),
        Offset.zero & overlay.size,
      ),
      items: itemBuilder(context),
    ).then((value) {
      if (value != null && onSelected != null) {
        onSelected!(value);
      }
    });
  }
}

/// Double-tap action wrapper
class DoubleTapAction extends StatelessWidget {
  final Widget child;
  final VoidCallback? onDoubleTap;
  final GestureAction action;
  final bool enableHapticFeedback;

  const DoubleTapAction({
    super.key,
    required this.child,
    this.onDoubleTap,
    this.action = GestureAction.duplicate,
    this.enableHapticFeedback = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: () {
        if (enableHapticFeedback) {
          HapticFeedback.lightImpact();
        }
        onDoubleTap?.call();
      },
      child: child,
    );
  }
}

/// Combined gesture detector with all gesture types
class GestureDetectorAll extends StatelessWidget {
  final Widget child;
  final GestureConfig config;
  final VoidCallback? onTap;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onPinchZoom;
  final List<PopupMenuEntry<GestureAction>> Function(BuildContext)? contextMenuBuilder;

  const GestureDetectorAll({
    super.key,
    required this.child,
    this.config = const GestureConfig(),
    this.onTap,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onLongPress,
    this.onDoubleTap,
    this.onPinchZoom,
    this.contextMenuBuilder,
  });

  @override
  Widget build(BuildContext context) {
    Widget result = child;

    // Wrap with swipe actions
    if (onSwipeLeft != null || onSwipeRight != null) {
      result = SwipeableAction(
        leftAction: config.swipeLeft,
        rightAction: config.swipeRight,
        onLeftSwipe: onSwipeLeft,
        onRightSwipe: onSwipeRight,
        enableHapticFeedback: config.enableHapticFeedback,
        threshold: config.swipeThreshold,
        child: result,
      );
    }

    // Wrap with long-press menu
    if (contextMenuBuilder != null && onLongPress != null) {
      result = LongPressMenu(
        itemBuilder: contextMenuBuilder!,
        onSelected: (action) {
          if (config.enableHapticFeedback) {
            HapticFeedback.mediumImpact();
          }
          onLongPress?.call();
        },
        enableHapticFeedback: config.enableHapticFeedback,
        longPressDuration: config.longPressDuration,
        child: result,
      );
    }

    // Wrap with double-tap
    if (onDoubleTap != null) {
      result = DoubleTapAction(
        action: config.doubleTap,
        onDoubleTap: onDoubleTap,
        enableHapticFeedback: config.enableHapticFeedback,
        child: result,
      );
    }

    // Wrap with tap handler
    if (onTap != null) {
      result = GestureDetector(
        onTap: () {
          if (config.enableHapticFeedback) {
            HapticFeedback.selectionClick();
          }
          onTap?.call();
        },
        child: result,
      );
    }

    return result;
  }
}

/// Helper to build standard context menu items
class GestureMenuItems {
  static List<PopupMenuEntry<GestureAction>> standardTransactionMenu() {
    return [
      const PopupMenuItem(
        value: GestureAction.edit,
        child: ListTile(
          leading: Icon(Icons.edit),
          title: Text('编辑'),
        ),
      ),
      const PopupMenuItem(
        value: GestureAction.duplicate,
        child: ListTile(
          leading: Icon(Icons.copy),
          title: Text('复制'),
        ),
      ),
      const PopupMenuItem(
        value: GestureAction.categorize,
        child: ListTile(
          leading: Icon(Icons.category),
          title: Text('分类'),
        ),
      ),
      const PopupMenuItem(
        value: GestureAction.addNote,
        child: ListTile(
          leading: Icon(Icons.note_add),
          title: Text('添加备注'),
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: GestureAction.archive,
        child: ListTile(
          leading: Icon(Icons.archive),
          title: Text('归档'),
        ),
      ),
      const PopupMenuItem(
        value: GestureAction.delete,
        child: ListTile(
          leading: Icon(Icons.delete, color: Colors.red),
          title: Text('删除', style: TextStyle(color: Colors.red)),
        ),
      ),
    ];
  }

  static List<PopupMenuEntry<GestureAction>> standardAccountMenu() {
    return [
      const PopupMenuItem(
        value: GestureAction.edit,
        child: ListTile(
          leading: Icon(Icons.edit),
          title: Text('编辑'),
        ),
      ),
      const PopupMenuItem(
        value: GestureAction.transfer,
        child: ListTile(
          leading: Icon(Icons.swap_horiz),
          title: Text('转账'),
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: GestureAction.archive,
        child: ListTile(
          leading: Icon(Icons.archive),
          title: Text('归档'),
        ),
      ),
      const PopupMenuItem(
        value: GestureAction.delete,
        child: ListTile(
          leading: Icon(Icons.delete, color: Colors.red),
          title: Text('删除', style: TextStyle(color: Colors.red)),
        ),
      ),
    ];
  }
}
