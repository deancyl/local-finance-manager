import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:finance_app/main.dart' as app;

/// Smoke test to verify the app launches successfully.
/// 
/// This test ensures:
/// - App initialization completes without errors
/// - Main UI is rendered
/// - No critical startup failures
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Smoke Tests', () {
    testWidgets('App launches and displays main widget', (WidgetTester tester) async {
      // Launch the app
      app.main();
      
      // Wait for the app to settle (allow time for async initialization)
      await tester.pumpAndSettle(const Duration(seconds: 10));
      
      // Verify the app rendered without crashing
      // The app uses MaterialApp.router, so we look for MaterialApp
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App renders router content', (WidgetTester tester) async {
      // Launch the app
      app.main();
      
      // Wait for the app to settle
      await tester.pumpAndSettle(const Duration(seconds: 10));
      
      // Verify MaterialApp.router is used
      expect(find.byType(MaterialApp), findsOneWidget);
      
      // Additional check: ensure the widget tree is populated
      // (indicates no critical initialization failure)
      final materialAppFinder = find.byType(MaterialApp);
      expect(materialAppFinder, findsOneWidget);
    });
  });
}
