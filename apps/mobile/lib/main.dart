import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/data/theme_provider.dart';
import 'features/settings/data/locale_provider.dart';
import 'features/budgets/data/budget_notification_service.dart';
import 'features/recurring/data/recurring_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize budget notification service
  final notificationService = BudgetNotificationService();
  await notificationService.initialize();
  await notificationService.requestPermissions();
  
  runApp(const ProviderScope(child: FinanceApp()));
}

class FinanceApp extends ConsumerStatefulWidget {
  const FinanceApp({super.key});

  @override
  ConsumerState<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends ConsumerState<FinanceApp> {
  @override
  void initState() {
    super.initState();
    _setupNotificationHandler();
    _processRecurringTransactions();
  }

  void _setupNotificationHandler() {
    // Handle notification taps
    final notificationService = BudgetNotificationService();
    // The notification handler is set up in the service
    // Here we would handle navigation when a notification is tapped
  }
  
  void _processRecurringTransactions() {
    // Process due recurring transactions on app startup
    Future.microtask(() async {
      final processorNotifier = ref.read(recurringProcessorNotifierProvider.notifier);
      final ids = await processorNotifier.processAllDue();
      if (ids.isNotEmpty) {
        print('Generated ${ids.length} recurring transactions on startup');
      }
    });
  }
  } catch (e) {
    print('Failed to process recurring transactions on startup: $e');
  }
  
  runApp(ProviderScope(child: FinanceApp()));
}

class FinanceApp extends ConsumerStatefulWidget {
  const FinanceApp({super.key});

  @override
  ConsumerState<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends ConsumerState<FinanceApp> {
  @override
  void initState() {
    super.initState();
    _setupNotificationHandler();
  }

  void _setupNotificationHandler() {
    // Handle notification taps
    final notificationService = BudgetNotificationService();
    // The notification handler is set up in the service
    // Here we would handle navigation when a notification is tapped
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final appLocale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: '本地金融管家',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.read(themeProvider.notifier).materialThemeMode,
      locale: appLocale.locale,
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: AppRouter.router,
    );
  }
}
