import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/presentation/widgets/keyboard_shortcuts.dart';
import 'core/presentation/widgets/gesture_config_provider.dart';
import 'features/settings/data/theme_provider.dart';
import 'features/settings/data/locale_provider.dart';
import 'features/settings/data/security_provider.dart';
import 'features/budgets/data/budget_notification_service.dart';
import 'features/recurring/data/recurring_provider.dart';
import 'features/platform/data/platform_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  
  // Initialize budget notification service
  final notificationService = BudgetNotificationService();
  await notificationService.initialize();
  await notificationService.requestPermissions();
  
  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      gestureConfigProvider.overrideWith((ref) {
        return GestureConfigNotifier(sharedPreferences);
      }),
    ],
    child: const FinanceApp(),
  ));
}

class FinanceApp extends ConsumerStatefulWidget {
  const FinanceApp({super.key});

  @override
  ConsumerState<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends ConsumerState<FinanceApp> {
  bool _securityChecked = false;
  
  @override
  void initState() {
    super.initState();
    _setupNotificationHandler();
    _processRecurringTransactions();
    _logPlatformInfo();
    _checkSecurityOnStartup();
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
      try {
        final generationNotifier = ref.read(recurringGenerationNotifierProvider.notifier);
        final ids = await generationNotifier.processAll();
        if (ids.isNotEmpty) {
          print('Generated ${ids.length} recurring transactions on startup');
        }
      } catch (e) {
        print('Failed to process recurring transactions on startup: $e');
      }
    });
  }
  
  void _logPlatformInfo() {
    // Log platform information for debugging (v0.3.86 Windows optimization)
    Future.microtask(() {
      final platformService = ref.read(platformServiceProvider);
      final platform = platformService.platform;
      print('=== Platform Info (v0.3.86) ===');
      print('Platform: $platform');
      print('isDesktop: ${platformService.isDesktop}');
      print('isWindows: ${platformService.isWindows}');
      print('Font scale: ${platformService.getFontScale()}');
      print('Sidebar width: ${platformService.getSidebarWidth()}');
      print('===============================');
    });
  }

  void _checkSecurityOnStartup() {
    // Security check is now handled by GoRouter redirect
    // This method is kept for future extensions if needed
    _securityChecked = true;
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = ref.watch(themeProvider);
    final appLocale = ref.watch(localeProvider);
    final router = ref.watch(goRouterProvider);

    // Build themes with custom accent color and AMOLED black support
    final lightTheme = AppTheme.buildLightTheme(accentColor: themeSettings.accentColor);
    final darkTheme = AppTheme.buildDarkTheme(
      accentColor: themeSettings.accentColor,
      isAmoledBlack: themeSettings.mode == AppThemeMode.amoledBlack,
    );

    return MaterialApp.router(
      title: '本地金融管家',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ref.read(themeProvider.notifier).materialThemeMode,
      locale: appLocale.locale,
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
