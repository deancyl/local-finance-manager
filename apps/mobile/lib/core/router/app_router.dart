import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/pages/accounts_page.dart';
import '../../features/transactions/presentation/pages/transactions_page.dart';
import '../../features/transactions/data/transaction_filter.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/reports/presentation/pages/trial_balance_page.dart';
import '../../features/budgets/presentation/pages/budgets_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/presentation/pages/theme_settings_page.dart';
import '../../features/settings/presentation/pages/language_settings_page.dart';
import '../../features/settings/presentation/pages/backup_settings_page.dart';
import '../../features/settings/presentation/pages/security_settings_page.dart';
import '../../features/settings/presentation/pages/about_page.dart';
import '../../features/export/presentation/pages/export_page.dart';
import '../../features/export/presentation/pages/import_page.dart' as export_import;
import '../../features/import/presentation/pages/import_page.dart';
import '../../features/import/presentation/pages/import_history_page.dart';
import '../../features/tags/presentation/pages/tags_page.dart';
import '../../features/recurring/presentation/pages/recurring_page.dart';
import '../../features/attachments/presentation/pages/attachments_page.dart';
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
            builder: (context, state) {
              final filter = state.extra as TransactionFilter?;
              return TransactionsPage(initialFilter: filter);
            },
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
            path: '/reports/trial-balance',
            name: 'trial-balance',
            builder: (context, state) => const TrialBalancePage(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
      // Settings sub-routes (outside shell for full-screen pages)
      GoRoute(
        path: '/settings/theme',
        name: 'theme-settings',
        builder: (context, state) => const ThemeSettingsPage(),
      ),
      GoRoute(
        path: '/settings/language',
        name: 'language-settings',
        builder: (context, state) => const LanguageSettingsPage(),
      ),
      GoRoute(
        path: '/settings/backup',
        name: 'backup-settings',
        builder: (context, state) => const BackupSettingsPage(),
      ),
      GoRoute(
        path: '/settings/security',
        name: 'security-settings',
        builder: (context, state) => const SecuritySettingsPage(),
      ),
      GoRoute(
        path: '/settings/about',
        name: 'about',
        builder: (context, state) => const AboutPage(),
      ),
      GoRoute(
        path: '/settings/export',
        name: 'export',
        builder: (context, state) => const ExportPage(),
      ),
      GoRoute(
        path: '/settings/import',
        name: 'import-data',
        builder: (context, state) => const export_import.ImportPage(),
      ),
      GoRoute(
        path: '/settings/tags',
        name: 'tags',
        builder: (context, state) => const TagsPage(),
      ),
      GoRoute(
        path: '/settings/recurring',
        name: 'recurring',
        builder: (context, state) => const RecurringPage(),
      ),
      GoRoute(
        path: '/import',
        name: 'import',
        builder: (context, state) => const ImportPage(),
      ),
      GoRoute(
        path: '/import/history',
        name: 'import-history',
        builder: (context, state) => const ImportHistoryPage(),
      ),
      GoRoute(
        path: '/transactions/attachments/:transactionId',
        name: 'attachments',
        builder: (context, state) {
          final transactionId = state.pathParameters['transactionId']!;
          final description = state.extra as String?;
          return AttachmentsPage(
            transactionId: transactionId,
            transactionDescription: description,
          );
        },
      ),
      // Sync routes temporarily disabled
      // GoRoute(
      //   path: '/settings/sync',
      //   name: 'sync-settings',
      //   builder: (context, state) => const SyncSettingsPage(),
      // ),
      // GoRoute(
      //   path: '/settings/sync/login',
      //   name: 'sync-login',
      //   builder: (context, state) => const SyncLoginPage(),
      // ),
      // GoRoute(
      //   path: '/settings/sync/pairing',
      //   name: 'sync-pairing',
      //   builder: (context, state) => const DevicePairingPage(),
      // ),
      // GoRoute(
      //   path: '/settings/sync/queue',
      //   name: 'sync-queue',
      //   builder: (context, state) => const OfflineQueuePage(),
      // ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('页面未找到: ${state.error}'),
      ),
    ),
  );
}
