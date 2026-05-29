import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/pages/accounts_page.dart';
import '../../features/accounts/presentation/pages/account_hierarchy_page.dart';
import '../../features/transactions/presentation/pages/transactions_page.dart';
import '../../features/transactions/presentation/pages/add_transaction_page.dart';
import '../../features/transactions/data/transaction_filter.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/reports/presentation/pages/trial_balance_page.dart';
import '../../features/reports/presentation/pages/balance_sheet_page.dart';
import '../../features/reports/presentation/pages/income_statement_page.dart';
import '../../features/reports/presentation/pages/cash_flow_page.dart';
import '../../features/reports/presentation/pages/general_ledger_page.dart';
import '../../features/budgets/presentation/pages/budgets_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/presentation/pages/theme_settings_page.dart';
import '../../features/settings/presentation/pages/language_settings_page.dart';
import '../../features/settings/presentation/pages/backup_settings_page.dart';
import '../../features/settings/presentation/pages/security_settings_page.dart';
import '../../features/settings/presentation/pages/about_page.dart';
import '../../features/security/presentation/pages/lock_screen_page.dart';
import '../../features/security/presentation/pages/biometric_settings_page.dart';
import '../../features/security/data/biometric_service.dart';
import '../../features/settings/data/security_provider.dart';
import '../../features/export/presentation/pages/export_page.dart';
import '../../features/export/presentation/pages/import_page.dart' as export_import;
import '../../features/import/presentation/pages/import_page.dart';
import '../../features/import/presentation/pages/import_history_page.dart';
import '../../features/tags/presentation/pages/tags_page.dart';
import '../../features/recurring/presentation/pages/recurring_page.dart';
import '../../features/attachments/presentation/pages/attachments_page.dart';
import '../../features/attachments/presentation/pages/attachment_viewer_page.dart';
import '../../features/reconciliation/presentation/pages/reconciliation_page.dart';
import '../../features/settings/presentation/pages/currency_settings_page.dart';
import '../../features/settings/presentation/pages/accessibility_settings_page.dart';
import '../../features/closing/presentation/pages/period_closing_page.dart';
import '../../features/currency/presentation/pages/exchange_rates_page.dart';
import '../../features/templates/presentation/pages/template_list_page.dart' hide TemplateListPage;
import '../../features/templates/presentation/template_page.dart';
import '../../features/templates/data/template_provider.dart' show TemplateModel;
import '../../features/dashboard/presentation/pages/analytics_dashboard_page.dart';
import '../../features/journal/presentation/pages/journal_entry_editor_page.dart';
// Sync with feature flag support
import '../../features/sync/presentation/pages/sync_settings_page.dart';
import '../../features/sync/presentation/pages/sync_login_page.dart';
import '../../features/sync/presentation/pages/device_pairing_page.dart';
import '../../features/sync/presentation/pages/offline_queue_page.dart';
import '../../features/sync/data/sync_feature_flag.dart';
import '../presentation/pages/home_page.dart';
import '../presentation/pages/main_shell.dart';

/// Global flag to track if app is unlocked
/// Set to true after successful authentication on lock screen
bool _isAppUnlocked = false;

/// Mark the app as unlocked after successful authentication
void markAppUnlocked() {
  _isAppUnlocked = true;
  notifyLockStateChanged();
}

/// Reset the unlocked state (for testing or explicit lock)
void resetAppLocked() {
  _isAppUnlocked = false;
  notifyLockStateChanged();
}

/// Check if security is enabled and app needs locking
bool _shouldShowLockScreen(SecuritySettings security) {
  if (_isAppUnlocked) return false;
  return security.isPasswordEnabled || security.isPinEnabled || security.isBiometricEnabled;
}

/// Provider for GoRouter with security-aware redirects
final goRouterProvider = Provider<GoRouter>((ref) {
  return _createRouter(ref);
});

/// Notifier to track lock state changes for GoRouter
final _lockStateNotifier = ValueNotifier<bool>(false);

/// Notify that lock state has changed
void notifyLockStateChanged() {
  _lockStateNotifier.value = !_lockStateNotifier.value;
}

GoRouter _createRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: _lockStateNotifier,
    redirect: (context, state) {
      final security = ref.read(securityProvider);
      
      // If security is enabled and app is not unlocked, show lock screen
      if (_shouldShowLockScreen(security)) {
        // Store the intended destination to redirect after unlock
        return '/lock?redirect=${Uri.encodeComponent(state.matchedLocation)}';
      }
      
      // If on lock screen but already unlocked, go to home
      if (state.matchedLocation == '/lock' && _isAppUnlocked) {
        return '/home';
      }
      
      return null;
    },
    routes: [
      // Lock screen route (outside shell for full-screen)
      GoRoute(
        path: '/lock',
        name: 'lock-screen',
        builder: (context, state) {
          final redirectUrl = state.uri.queryParameters['redirect'];
          return LockScreenPage(redirectUrl: redirectUrl);
        },
      ),
      // Biometric settings route (outside shell for full-screen)
      GoRoute(
        path: '/settings/biometric',
        name: 'biometric-settings',
        builder: (context, state) => const BiometricSettingsPage(),
      ),
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
            path: '/transactions/add',
            name: 'add-transaction',
            builder: (context, state) => const AddTransactionPage(),
          ),
          GoRoute(
            path: '/accounts',
            name: 'accounts',
            builder: (context, state) => const AccountsPage(),
          ),
          GoRoute(
            path: '/accounts/hierarchy',
            name: 'account-hierarchy',
            builder: (context, state) => const AccountHierarchyPage(),
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
            path: '/analytics',
            name: 'analytics',
            builder: (context, state) => const AnalyticsDashboardPage(),
          ),
          GoRoute(
            path: '/reports/trial-balance',
            name: 'trial-balance',
            builder: (context, state) => const TrialBalancePage(),
          ),
          GoRoute(
            path: '/reports/balance-sheet',
            name: 'balance-sheet',
            builder: (context, state) => const BalanceSheetPage(),
          ),
          GoRoute(
            path: '/reports/income-statement',
            name: 'income-statement',
            builder: (context, state) => const IncomeStatementPage(),
          ),
          GoRoute(
            path: '/reports/cash-flow',
            name: 'cash-flow',
            builder: (context, state) => const CashFlowPage(),
          ),
          GoRoute(
            path: '/reports/general-ledger',
            name: 'general-ledger',
            builder: (context, state) {
              final accountId = state.extra as String?;
              return GeneralLedgerPage(initialAccountId: accountId);
            },
          ),
          GoRoute(
            path: '/reconciliation',
            name: 'reconciliation',
            builder: (context, state) => const ReconciliationPage(),
          ),
          GoRoute(
            path: '/closing',
            name: 'closing',
            builder: (context, state) => const PeriodClosingPage(),
          ),
          GoRoute(
            path: '/journal-entry',
            name: 'journal-entry-editor',
            builder: (context, state) {
              final entryId = state.extra as String?;
              return JournalEntryEditorPage(entryId: entryId);
            },
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
        path: '/settings/templates',
        name: 'templates',
        builder: (context, state) => const TemplateListPage(),
      ),
      GoRoute(
        path: '/settings/templates/edit',
        name: 'template-edit',
        builder: (context, state) {
          final template = state.extra as TemplateModel?;
          return TemplateEditPage(template: template);
        },
      ),
      GoRoute(
        path: '/settings/currency',
        name: 'currency',
        builder: (context, state) => const CurrencySettingsPage(),
      ),
      GoRoute(
        path: '/settings/accessibility',
        name: 'accessibility-settings',
        builder: (context, state) => const AccessibilitySettingsPage(),
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
      GoRoute(
        path: '/attachments/viewer',
        name: 'attachment-viewer',
        builder: (context, state) {
          final args = state.extra as AttachmentViewerArgs;
          return AttachmentViewerPage(
            transactionId: args.transactionId,
            initialIndex: args.initialIndex,
            transactionDescription: args.transactionDescription,
          );
        },
      ),
      // Sync routes - protected by feature flag
      GoRoute(
        path: '/settings/sync',
        name: 'sync-settings',
        builder: (context, state) => const SyncSettingsPage(),
      ),
      GoRoute(
        path: '/settings/sync/login',
        name: 'sync-login',
        builder: (context, state) => const SyncLoginPage(),
      ),
      GoRoute(
        path: '/settings/sync/pairing',
        name: 'sync-pairing',
        builder: (context, state) => const DevicePairingPage(),
      ),
      GoRoute(
        path: '/settings/sync/queue',
        name: 'sync-queue',
        builder: (context, state) => const OfflineQueuePage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('页面未找到: ${state.error}'),
      ),
    ),
  );
}

/// AppRouter class for backward compatibility
class AppRouter {
  /// Static router instance (uses the provider internally)
  static GoRouter get router {
    // Create a provider container to access the router
    final container = ProviderContainer();
    return container.read(goRouterProvider);
  }
}
