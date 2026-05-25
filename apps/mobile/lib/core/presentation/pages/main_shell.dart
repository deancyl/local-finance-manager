import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/keyboard_shortcuts.dart';
import '../../../features/platform/data/platform_provider.dart';

// Sync temporarily disabled - PowerSync compatibility issues
// import '../../features/sync/presentation/widgets/sync_status_indicator.dart';

class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return switch (location) {
      '/home' => 0,
      '/transactions' => 1,
      '/accounts' => 2,
      '/budgets' => 3,
      '/reports' => 4,
      _ => 0,
    };
  }

  void _handleShortcut(ShortcutAction action, BuildContext context, WidgetRef ref) {
    final platformService = ref.read(platformServiceProvider);
    
    // Only handle shortcuts on desktop platforms
    if (!platformService.isDesktop) return;

    switch (action) {
      case ShortcutAction.newTransaction:
        context.push('/transactions/add');
        break;
      case ShortcutAction.search:
        context.push('/transactions');
        // Could open search dialog in the future
        break;
      case ShortcutAction.escape:
        // Close dialog or go back
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        break;
      default:
        // Other shortcuts handled by specific pages
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _getSelectedIndex(context);
    final platformService = ref.watch(platformServiceProvider);

    Widget scaffold = Scaffold(
      appBar: AppBar(
        actions: const [
          // SyncStatusIndicator(),  // Temporarily disabled
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          final path = switch (index) {
            0 => '/home',
            1 => '/transactions',
            2 => '/accounts',
            3 => '/budgets',
            4 => '/reports',
            _ => '/home',
          };
          context.go(path);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '交易',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: '账户',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: '预算',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '报表',
          ),
        ],
      ),
    );

    // Wrap with keyboard shortcuts on desktop platforms
    if (platformService.isDesktop) {
      return ShortcutsActionWidget(
        onNewTransaction: () => context.push('/transactions/add'),
        onSearch: () => context.push('/transactions'),
        onEscape: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
        child: scaffold,
      );
    }

    return scaffold;
  }
}