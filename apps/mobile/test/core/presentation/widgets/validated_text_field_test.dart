import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_app/core/presentation/widgets/validated_text_field.dart';

void main() {
  group('ValidatedTextField', () {
    testWidgets('renders with basic properties', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValidatedTextField(
              labelText: 'Test Field',
              hintText: 'Enter value',
            ),
          ),
        ),
      );

      expect(find.text('Test Field'), findsOneWidget);
      expect(find.text('Enter value'), findsOneWidget);
    });

    testWidgets('shows error when validation fails', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValidatedTextField(
              labelText: 'Required Field',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'This field is required';
                }
                return null;
              },
            ),
          ),
        ),
      );

      // Initially no error
      expect(find.text('This field is required'), findsNothing);

      // Enter empty text and unfocus
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.byType(TextField));
      await tester.pump();

      // Focus on another widget to trigger unfocus
      await tester.tap(find.byType(Scaffold));
      await tester.pumpAndSettle();

      // Error should now be visible
      expect(find.text('This field is required'), findsOneWidget);
    });

    testWidgets('clears error when valid input is entered', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValidatedTextField(
              labelText: 'Required Field',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'This field is required';
                }
                return null;
              },
            ),
          ),
        ),
      );

      // Enter empty text
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.byType(Scaffold));
      await tester.pumpAndSettle();

      // Error should be visible
      expect(find.text('This field is required'), findsOneWidget);

      // Enter valid text
      await tester.enterText(find.byType(TextField), 'valid value');
      await tester.pump();

      // Error should be cleared
      expect(find.text('This field is required'), findsNothing);
    });

    testWidgets('shows prefix icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValidatedTextField(
              prefixIcon: Icons.person,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('shows suffix icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValidatedTextField(
              suffixIcon: Icons.clear,
              onSuffixIconPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('calls onChanged callback', (tester) async {
      String? changedValue;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValidatedTextField(
              onChanged: (value) {
                changedValue = value;
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'test value');
      await tester.pump();

      expect(changedValue, 'test value');
    });

    testWidgets('validates on change when enabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValidatedTextField(
              validateOnChange: true,
              validator: (value) {
                if (value != null && value.length < 3) {
                  return 'Minimum 3 characters';
                }
                return null;
              },
            ),
          ),
        ),
      );

      // Enter short text
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump();

      // Error should appear immediately
      expect(find.text('Minimum 3 characters'), findsOneWidget);

      // Enter valid text
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();

      // Error should be cleared
      expect(find.text('Minimum 3 characters'), findsNothing);
    });

    testWidgets('can be disabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValidatedTextField(
              enabled: false,
              labelText: 'Disabled Field',
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, false);
    });

    testWidgets('respects maxLines property', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValidatedTextField(
              maxLines: 5,
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLines, 5);
    });
  });

  group('AmountTextField', () {
    testWidgets('renders with default properties', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmountTextField(),
          ),
        ),
      );

      expect(find.text('Amount'), findsOneWidget);
    });

    testWidgets('shows money icon by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmountTextField(),
          ),
        ),
      );

      expect(find.byIcon(Icons.attach_money), findsOneWidget);
    });

    testWidgets('accepts numeric input', (tester) async {
      final controller = TextEditingController();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmountTextField(
              controller: controller,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '123.45');
      await tester.pump();

      expect(controller.text, '123.45');
    });
  });

  group('DateTextField', () {
    testWidgets('renders with default properties', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateTextField(),
          ),
        ),
      );

      expect(find.text('Date'), findsOneWidget);
    });

    testWidgets('shows calendar icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateTextField(),
          ),
        ),
      );

      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });
  });

  group('DescriptionTextField', () {
    testWidgets('renders with default properties', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DescriptionTextField(),
          ),
        ),
      );

      expect(find.text('Description'), findsOneWidget);
    });

    testWidgets('shows description icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DescriptionTextField(),
          ),
        ),
      );

      expect(find.byIcon(Icons.description), findsOneWidget);
    });

    testWidgets('respects maxLines', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DescriptionTextField(
              maxLines: 5,
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLines, 5);
    });
  });

  group('PasswordTextField', () {
    testWidgets('renders with default properties', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PasswordTextField(),
          ),
        ),
      );

      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('shows lock icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PasswordTextField(),
          ),
        ),
      );

      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('toggles password visibility', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PasswordTextField(),
          ),
        ),
      );

      // Initially obscured
      var textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, true);

      // Tap visibility toggle
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();

      // Now visible
      textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, false);

      // Tap again to hide
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();

      textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, true);
    });
  });
}
