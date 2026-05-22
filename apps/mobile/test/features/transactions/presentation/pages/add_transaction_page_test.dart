import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:go_router/go_router.dart';

import 'package:finance_app/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:finance_app/features/transactions/presentation/widgets/add_transaction_dialog.dart';
import 'package:database/database.dart';

// Mock classes
class MockDatabase extends Mock implements AppDatabase {}

class MockGoRouter extends Mock implements GoRouter {}

void main() {
  group('AddTransactionPage', () {
    testWidgets('renders without errors', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [],
          child: const MaterialApp(
            home: AddTransactionPage(),
          ),
        ),
      );

      // Act & Assert - should render without throwing
      expect(find.byType(AddTransactionPage), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('AppBar has correct title "记一笔"', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [],
          child: const MaterialApp(
            home: AddTransactionPage(),
          ),
        ),
      );

      // Act & Assert
      expect(find.text('记一笔'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('back button exists in AppBar', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [],
          child: const MaterialApp(
            home: AddTransactionPage(),
          ),
        ),
      );

      // Act & Assert
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('AddTransactionDialog is displayed in body', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [],
          child: const MaterialApp(
            home: AddTransactionPage(),
          ),
        ),
      );

      // Act & Assert
      expect(find.byType(AddTransactionDialog), findsOneWidget);
      expect(find.byType(SafeArea), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('page accepts optional transactionId parameter', (WidgetTester tester) async {
      // Arrange
      const transactionId = 'test-transaction-id';
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [],
          child: const MaterialApp(
            home: AddTransactionPage(transactionId: transactionId),
          ),
        ),
      );

      // Act & Assert - should render without throwing
      expect(find.byType(AddTransactionPage), findsOneWidget);
    });
  });
}
