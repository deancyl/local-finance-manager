import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/pages/accounts_page.dart';
import '../../features/transactions/presentation/pages/transactions_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/budgets/presentation/pages/budgets_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/import/presentation/pages/import_page.dart';
// Sync temporarily disabled - PowerSync compatibility issues
// import '../../features/sync/presentation/pages/sync_settings_page.dart';
// import '../../features/sync/presentation/pages/sync_login_page.dart';
// import '../../features/sync/presentation/pages/device_pairing_page.dart';
// import '../../features/sync/presentation/pages/offline_queue_page.dart';
import '../presentation/pages/home_page.dart';
import '../presentation/pages/main_shell.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: '/transactions',
            name: 'transactions',
            builder: (context, state) => const TransactionsPage(),
          ),
          GoRoute(
            path: '/accounts',
            name: 'accounts',
            builder: (context, state) => const AccountsPage(),
          ),
          GoRoute(
            path: '/budgets',
            name: 'budgets',
            builder: (context, state) => const BudgetsPage(),
          ),
          GoRoute(
            path: '/reports',
            name: 'reports',
            builder: (context, state) => const ReportsPage(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsPage(),
            // Sync routes temporarily disabled
            // routes: [
            //   GoRoute(
            //     path: 'sync',
            //     name: 'sync-settings',
            //     builder: (context, state) => const SyncSettingsPage(),
            //   ),
            //   GoRoute(
            //     path: 'sync/pairing',
            //     name: 'sync-pairing',
            //     builder: (context, state) => const DevicePairingPage(),
            //   ),
            //   GoRoute(
            //     path: 'sync/queue',
            //     name: 'sync-queue',
            //     builder: (context, state) => const OfflineQueuePage(),
            //   ),
            // ],
          ),
        ],
      ),
      GoRoute(
        path: '/import',
        name: 'import',
        builder: (context, state) => const ImportPage(),
      ),
      // Sync login temporarily disabled
      // GoRoute(
      //   path: '/settings/sync/login',
      //   name: 'sync-login',
      //   builder: (context, state) => const SyncLoginPage(),
      // ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('页面未找到: ${state.error}'),
      ),
    ),
  );
}