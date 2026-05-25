import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quick_actions_panel.dart';

/// Quick actions dashboard widget
/// 
/// This widget can be added to the customizable dashboard
/// to provide quick action shortcuts on the home screen.
class QuickActionsDashboardWidget extends ConsumerWidget {
  final Map<String, dynamic>? config;

  const QuickActionsDashboardWidget({
    super.key,
    this.config,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showCategories = config?['showCategories'] as bool? ?? true;
    final showPayees = config?['showPayees'] as bool? ?? true;
    final showOneTap = config?['showOneTap'] as bool? ?? true;

    return QuickActionsPanel(
      showCategories: showCategories,
      showPayees: showPayees,
      showOneTap: showOneTap,
    );
  }

  /// Widget configuration schema for dashboard editor
  static Map<String, dynamic> getConfigSchema() {
    return {
      'showCategories': {
        'type': 'boolean',
        'label': '显示常用分类',
        'default': true,
      },
      'showPayees': {
        'type': 'boolean',
        'label': '显示最近收款方',
        'default': true,
      },
      'showOneTap': {
        'type': 'boolean',
        'label': '显示一键记账',
        'default': true,
      },
    };
  }

  /// Default widget configuration
  static Map<String, dynamic> getDefaultConfig() {
    return {
      'showCategories': true,
      'showPayees': true,
      'showOneTap': true,
    };
  }
}
