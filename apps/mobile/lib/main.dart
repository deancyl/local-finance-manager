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
import 'features/settings/data/accessibility_provider.dart';
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
    final accessibilitySettings = ref.watch(accessibilityProvider);
    final router = ref.watch(goRouterProvider);

    // Build themes with custom accent color and AMOLED black support
    ThemeData lightTheme;
    ThemeData darkTheme;

    // Apply high contrast theme if enabled
    if (accessibilitySettings.highContrastEnabled) {
      lightTheme = AppTheme.buildHighContrastLightTheme();
      darkTheme = AppTheme.buildHighContrastDarkTheme();
    } else {
      lightTheme = AppTheme.buildLightTheme(accentColor: themeSettings.accentColor);
      darkTheme = AppTheme.buildDarkTheme(
        accentColor: themeSettings.accentColor,
        isAmoledBlack: themeSettings.mode == AppThemeMode.amoledBlack,
      );
    }

    // Apply bold text if enabled
    if (accessibilitySettings.boldText) {
      lightTheme = _applyBoldText(lightTheme);
      darkTheme = _applyBoldText(darkTheme);
    }

    return MediaQuery(
      // Apply text scaling if not using system setting
      data: MediaQuery.of(context).copyWith(
        textScaler: accessibilitySettings.useSystemTextScale
            ? MediaQuery.of(context).textScaler
            : TextScaler.linear(accessibilitySettings.textScaleFactor),
      ),
      child: MaterialApp.router(
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
      ),
    );
  }

  /// Apply bold text to all text styles in theme
  ThemeData _applyBoldText(ThemeData theme) {
    return theme.copyWith(
      textTheme: theme.textTheme.apply(
        fontFamily: null,
      ).copyWith(
        bodyLarge: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        bodySmall: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        titleLarge: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      primaryTextTheme: theme.primaryTextTheme.apply(
        fontFamily: null,
      ).copyWith(
        bodyLarge: theme.primaryTextTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: theme.primaryTextTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        bodySmall: theme.primaryTextTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        titleLarge: theme.primaryTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: theme.primaryTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: theme.primaryTextTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
