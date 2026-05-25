import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/quick_actions_provider.dart';

/// Floating Action Button with quick action menu
/// 
/// Provides quick access to common actions:
/// - Add expense
/// - Add income  
/// - Transfer between accounts
/// - Use template
class QuickAddFAB extends ConsumerStatefulWidget {
  final bool isExpanded;
  
  const QuickAddFAB({
    super.key,
    this.isExpanded = false,
  });

  @override
  ConsumerState<QuickAddFAB> createState() => _QuickAddFABState();
}

class _QuickAddFABState extends ConsumerState<QuickAddFAB>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
      parent: _controller,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = ref.watch(quickActionShortcutsProvider);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Quick action buttons (shown when expanded)
        if (_isExpanded) ...[
          ...shortcuts.reversed.map((action) => _buildQuickActionButton(action)),
          const SizedBox(height: 8),
        ],
        
        // Main FAB
        FloatingActionButton(
          onPressed: _toggle,
          child: AnimatedRotation(
            turns: _isExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(_isExpanded ? Icons.close : Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(QuickActionItem action) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              action.label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 12),
          
          // Action button
          ScaleTransition(
            scale: _expandAnimation,
            child: FloatingActionButton(
              heroTag: 'quick_action_${action.type.index}',
              mini: true,
              backgroundColor: _getActionColor(action.type),
              onPressed: () => _handleAction(action),
              child: Icon(
                _getActionIcon(action.type),
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getActionColor(QuickActionType type) {
    switch (type) {
      case QuickActionType.expense:
        return Colors.red;
      case QuickActionType.income:
        return Colors.green;
      case QuickActionType.transfer:
        return Colors.blue;
      case QuickActionType.template:
        return Colors.purple;
      case QuickActionType.recentPayee:
        return Colors.orange;
    }
  }

  IconData _getActionIcon(QuickActionType type) {
    switch (type) {
      case QuickActionType.expense:
        return Icons.remove_shopping_cart;
      case QuickActionType.income:
        return Icons.attach_money;
      case QuickActionType.transfer:
        return Icons.swap_horiz;
      case QuickActionType.template:
        return Icons.receipt_long;
      case QuickActionType.recentPayee:
        return Icons.history;
    }
  }

  void _handleAction(QuickActionItem action) {
    _toggle();
    
    switch (action.type) {
      case QuickActionType.expense:
        context.push('/transactions/add?mode=expense');
        break;
      case QuickActionType.income:
        context.push('/transactions/add?mode=income');
        break;
      case QuickActionType.transfer:
        context.push('/transactions/add?mode=transfer');
        break;
      case QuickActionType.template:
        context.push('/transactions/add?mode=template');
        break;
      case QuickActionType.recentPayee:
        context.push('/transactions/add?mode=recent');
        break;
    }
  }
}
