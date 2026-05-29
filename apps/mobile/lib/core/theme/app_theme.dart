import 'package:flutter/material.dart';
import 'dart:io';

class AppTheme {
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color primaryColorDark = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF03DAC6);
  static const Color errorColor = Color(0xFFB00020);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);

  static const Color incomeColor = Color(0xFF4CAF50);
  static const Color expenseColor = Color(0xFFF44336);

  // Desktop-specific constants
  static const double desktopFontScale = 1.1;
  static const double desktopCardPadding = 24.0;
  static const double desktopSidebarWidth = 280.0;
  static const double desktopMinWindowWidth = 1200.0;
  static const double desktopMinWindowHeight = 800.0;

  // Windows-specific constants (v0.3.86)
  static const double windowsFontScale = 1.15;
  static const double windowsSidebarWidth = 300.0;
  static const double windowsCardElevation = 2.0;
  static const double windowsBorderRadius = 8.0;

  // Check if running on desktop platform
  static bool get isDesktop {
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  // Check if running on Windows (v0.3.86)
  static bool get isWindows {
    try {
      return Platform.isWindows;
    } catch (_) {
      return false;
    }
  }

  // Get platform-specific font scale
  static double get _platformFontScale {
    if (isWindows) return windowsFontScale;
    if (isDesktop) return desktopFontScale;
    return 1.0;
  }

  // Get platform-specific sidebar width
  static double get sidebarWidth {
    if (isWindows) return windowsSidebarWidth;
    if (isDesktop) return desktopSidebarWidth;
    return 0; // No sidebar on mobile
  }

  // Get scaled text theme for desktop
  static TextTheme _getScaledTextTheme(TextTheme base) {
    final scale = _platformFontScale;
    if (scale == 1.0) return base;
    
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontSize: (base.displayLarge?.fontSize ?? 57) * scale),
      displayMedium: base.displayMedium?.copyWith(fontSize: (base.displayMedium?.fontSize ?? 45) * scale),
      displaySmall: base.displaySmall?.copyWith(fontSize: (base.displaySmall?.fontSize ?? 36) * scale),
      headlineLarge: base.headlineLarge?.copyWith(fontSize: (base.headlineLarge?.fontSize ?? 32) * scale),
      headlineMedium: base.headlineMedium?.copyWith(fontSize: (base.headlineMedium?.fontSize ?? 28) * scale),
      headlineSmall: base.headlineSmall?.copyWith(fontSize: (base.headlineSmall?.fontSize ?? 24) * scale),
      titleLarge: base.titleLarge?.copyWith(fontSize: (base.titleLarge?.fontSize ?? 22) * scale),
      titleMedium: base.titleMedium?.copyWith(fontSize: (base.titleMedium?.fontSize ?? 16) * scale),
      titleSmall: base.titleSmall?.copyWith(fontSize: (base.titleSmall?.fontSize ?? 14) * scale),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: (base.bodyLarge?.fontSize ?? 16) * scale),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: (base.bodyMedium?.fontSize ?? 14) * scale),
      bodySmall: base.bodySmall?.copyWith(fontSize: (base.bodySmall?.fontSize ?? 12) * scale),
      labelLarge: base.labelLarge?.copyWith(fontSize: (base.labelLarge?.fontSize ?? 14) * scale),
      labelMedium: base.labelMedium?.copyWith(fontSize: (base.labelMedium?.fontSize ?? 12) * scale),
      labelSmall: base.labelSmall?.copyWith(fontSize: (base.labelSmall?.fontSize ?? 11) * scale),
    );
  }

  /// Build light theme with optional custom accent color
  static ThemeData buildLightTheme({Color? accentColor}) {
    final seedColor = accentColor ?? primaryColor;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        toolbarHeight: isDesktop ? 64 : 56,
      ),
      cardTheme: CardThemeData(
        elevation: isWindows ? windowsCardElevation : (isDesktop ? 1 : 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isWindows ? windowsBorderRadius : 12),
        ),
        margin: isDesktop 
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
            : null,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isWindows ? windowsBorderRadius : 8),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : 24,
            vertical: isDesktop ? 16 : 12,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isWindows ? windowsBorderRadius : 8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isWindows ? windowsBorderRadius : 8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isWindows ? windowsBorderRadius : 8),
          borderSide: BorderSide(color: seedColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isWindows ? windowsBorderRadius : 8),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 20 : 16,
          vertical: isDesktop ? 20 : 16,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        shape: isDesktop ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)) : const CircleBorder(),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: isDesktop ? TextStyle(fontSize: 14 * _platformFontScale) : null,
        unselectedLabelStyle: isDesktop ? TextStyle(fontSize: 12 * _platformFontScale) : null,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14 * _platformFontScale,
        ),
        dataTextStyle: TextStyle(
          fontSize: (isDesktop ? 15 : 14) * _platformFontScale,
        ),
        headingRowHeight: isDesktop ? 56 : 48,
        dataRowHeight: isDesktop ? 56 : 48,
        dividerThickness: 1,
      ),
      textTheme: _getScaledTextTheme(ThemeData.light().textTheme),
    );
  }

  /// Build dark theme with optional custom accent color
  static ThemeData buildDarkTheme({Color? accentColor, bool isAmoledBlack = false}) {
    final seedColor = accentColor ?? primaryColor;
    final backgroundColor = isAmoledBlack ? Colors.black : const Color(0xFF121212);
    final cardColor = isAmoledBlack ? const Color(0xFF1A1A1A) : const Color(0xFF1E1E1E);
    final inputFillColor = isAmoledBlack ? const Color(0xFF1A1A1A) : const Color(0xFF2C2C2C);
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        toolbarHeight: isDesktop ? 64 : 56,
      ),
      cardTheme: CardThemeData(
        elevation: isWindows ? windowsCardElevation : (isDesktop ? 1 : 2),
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isWindows ? windowsBorderRadius : 12),
        ),
        margin: isDesktop 
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
            : null,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isWindows ? windowsBorderRadius : 8),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : 24,
            vertical: isDesktop ? 16 : 12,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isWindows ? windowsBorderRadius : 8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isWindows ? windowsBorderRadius : 8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isWindows ? windowsBorderRadius : 8),
          borderSide: BorderSide(color: seedColor, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 20 : 16,
          vertical: isDesktop ? 20 : 16,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        backgroundColor: cardColor,
        selectedLabelStyle: isDesktop ? TextStyle(fontSize: 14 * _platformFontScale) : null,
        unselectedLabelStyle: isDesktop ? TextStyle(fontSize: 12 * _platformFontScale) : null,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(isAmoledBlack ? const Color(0xFF1A1A1A) : Colors.grey.shade900),
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14 * _platformFontScale,
        ),
        dataTextStyle: TextStyle(
          fontSize: (isDesktop ? 15 : 14) * _platformFontScale,
        ),
        headingRowHeight: isDesktop ? 56 : 48,
        dataRowHeight: isDesktop ? 56 : 48,
        dividerThickness: 1,
      ),
      textTheme: _getScaledTextTheme(ThemeData.dark().textTheme),
    );
  }

  // Legacy static themes for backward compatibility
  static ThemeData lightTheme = buildLightTheme();
  static ThemeData darkTheme = buildDarkTheme();

  // High contrast colors for accessibility
  static const Color highContrastPrimary = Color(0xFF000000);
  static const Color highContrastSecondary = Color(0xFFFFFFFF);
  static const Color highContrastAccent = Color(0xFF0055FF);
  static const Color highContrastError = Color(0xFFFF0000);
  static const Color highContrastSuccess = Color(0xFF008800);
  static const Color highContrastWarning = Color(0xFFFF8800);

  /// Build high contrast light theme for accessibility
  static ThemeData buildHighContrastLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.highContrastLight(
        primary: highContrastPrimary,
        secondary: highContrastAccent,
        error: highContrastError,
        surface: highContrastSecondary,
      ),
      scaffoldBackgroundColor: highContrastSecondary,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: highContrastPrimary,
        foregroundColor: highContrastSecondary,
        toolbarHeight: 56,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: highContrastSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: highContrastPrimary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: highContrastPrimary,
          foregroundColor: highContrastSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: highContrastPrimary, width: 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: highContrastPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: highContrastPrimary, width: 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: highContrastPrimary,
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: highContrastSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: highContrastPrimary, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: highContrastPrimary, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: highContrastAccent, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: highContrastError, width: 2),
        ),
        labelStyle: const TextStyle(
          color: highContrastPrimary,
          fontWeight: FontWeight.bold,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: highContrastPrimary,
        foregroundColor: highContrastSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        backgroundColor: highContrastSecondary,
        selectedItemColor: highContrastPrimary,
        unselectedItemColor: highContrastPrimary,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
      ),
      dividerTheme: const DividerThemeData(
        color: highContrastPrimary,
        thickness: 2,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: highContrastPrimary, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: highContrastPrimary, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: highContrastPrimary, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: highContrastPrimary, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: highContrastPrimary, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: highContrastPrimary, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: highContrastPrimary, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: highContrastPrimary, fontWeight: FontWeight.bold),
        titleSmall: TextStyle(color: highContrastPrimary, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: highContrastPrimary),
        bodyMedium: TextStyle(color: highContrastPrimary),
        bodySmall: TextStyle(color: highContrastPrimary),
        labelLarge: TextStyle(color: highContrastPrimary, fontWeight: FontWeight.bold),
        labelMedium: TextStyle(color: highContrastPrimary, fontWeight: FontWeight.bold),
        labelSmall: TextStyle(color: highContrastPrimary, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Build high contrast dark theme for accessibility
  static ThemeData buildHighContrastDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.highContrastDark(
        primary: highContrastSecondary,
        secondary: highContrastAccent,
        error: highContrastError,
        surface: highContrastPrimary,
      ),
      scaffoldBackgroundColor: highContrastPrimary,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: highContrastSecondary,
        foregroundColor: highContrastPrimary,
        toolbarHeight: 56,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: highContrastPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: highContrastSecondary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: highContrastSecondary,
          foregroundColor: highContrastPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: highContrastSecondary, width: 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: highContrastSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: highContrastSecondary, width: 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: highContrastSecondary,
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: highContrastPrimary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: highContrastSecondary, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: highContrastSecondary, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: highContrastAccent, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: highContrastError, width: 2),
        ),
        labelStyle: const TextStyle(
          color: highContrastSecondary,
          fontWeight: FontWeight.bold,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: highContrastSecondary,
        foregroundColor: highContrastPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        backgroundColor: highContrastPrimary,
        selectedItemColor: highContrastSecondary,
        unselectedItemColor: highContrastSecondary,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
      ),
      dividerTheme: const DividerThemeData(
        color: highContrastSecondary,
        thickness: 2,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: highContrastSecondary, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: highContrastSecondary, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: highContrastSecondary, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: highContrastSecondary, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: highContrastSecondary, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: highContrastSecondary, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: highContrastSecondary, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: highContrastSecondary, fontWeight: FontWeight.bold),
        titleSmall: TextStyle(color: highContrastSecondary, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: highContrastSecondary),
        bodyMedium: TextStyle(color: highContrastSecondary),
        bodySmall: TextStyle(color: highContrastSecondary),
        labelLarge: TextStyle(color: highContrastSecondary, fontWeight: FontWeight.bold),
        labelMedium: TextStyle(color: highContrastSecondary, fontWeight: FontWeight.bold),
        labelSmall: TextStyle(color: highContrastSecondary, fontWeight: FontWeight.bold),
      ),
    );
  }

  static ThemeData highContrastLightTheme = buildHighContrastLightTheme();
  static ThemeData highContrastDarkTheme = buildHighContrastDarkTheme();
}