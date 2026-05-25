import 'package:test/test.dart';
import 'package:core/src/validation/validation_service.dart';

void main() {
  group('ValidationResult', () {
    test('valid() creates a valid result', () {
      final result = const ValidationResult.valid();
      expect(result.isValid, true);
      expect(result.errorMessage, null);
      expect(result.isInvalid, false);
    });

    test('invalid() creates an invalid result with message', () {
      final result = const ValidationResult.invalid('Error message');
      expect(result.isValid, false);
      expect(result.errorMessage, 'Error message');
      expect(result.isInvalid, true);
    });
  });

  group('ValidationService', () {
    group('required', () {
      test('returns invalid for null value', () {
        final validator = ValidationService.required();
        final result = validator(null);
        expect(result.isInvalid, true);
        expect(result.errorMessage, 'This field is required');
      });

      test('returns invalid for empty string', () {
        final validator = ValidationService.required();
        final result = validator('');
        expect(result.isInvalid, true);
      });

      test('returns invalid for whitespace only', () {
        final validator = ValidationService.required();
        final result = validator('   ');
        expect(result.isInvalid, true);
      });

      test('returns valid for non-empty value', () {
        final validator = ValidationService.required();
        final result = validator('test');
        expect(result.isValid, true);
      });

      test('uses custom error message', () {
        final validator = ValidationService.required(message: 'Custom required message');
        final result = validator(null);
        expect(result.errorMessage, 'Custom required message');
      });
    });

    group('amount', () {
      test('returns invalid for null value', () {
        final validator = ValidationService.amount();
        final result = validator(null);
        expect(result.isInvalid, true);
        expect(result.errorMessage, 'Amount is required');
      });

      test('returns invalid for empty string', () {
        final validator = ValidationService.amount();
        final result = validator('');
        expect(result.isInvalid, true);
      });

      test('returns invalid for non-numeric value', () {
        final validator = ValidationService.amount();
        final result = validator('abc');
        expect(result.isInvalid, true);
        expect(result.errorMessage, 'Please enter a valid amount');
      });

      test('returns valid for valid amount', () {
        final validator = ValidationService.amount();
        expect(validator('100').isValid, true);
        expect(validator('100.50').isValid, true);
        expect(validator('1,000.00').isValid, true);
      });

      test('returns invalid for negative when not allowed', () {
        final validator = ValidationService.amount(allowNegative: false);
        final result = validator('-50');
        expect(result.isInvalid, true);
        expect(result.errorMessage, 'Amount cannot be negative');
      });

      test('returns valid for negative when allowed', () {
        final validator = ValidationService.amount(allowNegative: true);
        expect(validator('-50').isValid, true);
      });

      test('returns invalid for zero when not allowed', () {
        final validator = ValidationService.amount(allowZero: false);
        final result = validator('0');
        expect(result.isInvalid, true);
        expect(result.errorMessage, 'Amount cannot be zero');
      });

      test('returns valid for zero when allowed', () {
        final validator = ValidationService.amount(allowZero: true);
        expect(validator('0').isValid, true);
      });

      test('validates min value', () {
        final validator = ValidationService.amount(minValue: 10);
        expect(validator('5').isInvalid, true);
        expect(validator('10').isValid, true);
        expect(validator('15').isValid, true);
      });

      test('validates max value', () {
        final validator = ValidationService.amount(maxValue: 100);
        expect(validator('50').isValid, true);
        expect(validator('100').isValid, true);
        expect(validator('150').isInvalid, true);
      });
    });

    group('date', () {
      test('returns invalid for null value', () {
        final validator = ValidationService.date();
        final result = validator(null);
        expect(result.isInvalid, true);
        expect(result.errorMessage, 'Date is required');
      });

      test('returns invalid for empty string', () {
        final validator = ValidationService.date();
        final result = validator('');
        expect(result.isInvalid, true);
      });

      test('returns invalid for invalid date format', () {
        final validator = ValidationService.date();
        final result = validator('not-a-date');
        expect(result.isInvalid, true);
        expect(result.errorMessage, 'Please enter a valid date (YYYY-MM-DD)');
      });

      test('returns valid for valid date formats', () {
        final validator = ValidationService.date();
        expect(validator('2024-01-15').isValid, true);
        expect(validator('2024-1-5').isValid, true);
      });

      test('returns invalid for past date when not allowed', () {
        final validator = ValidationService.date(allowPast: false);
        final pastDate = DateTime.now().subtract(const Duration(days: 1));
        final dateStr = '${pastDate.year}-${pastDate.month}-${pastDate.day}';
        final result = validator(dateStr);
        expect(result.isInvalid, true);
        expect(result.errorMessage, 'Date cannot be in the past');
      });

      test('returns invalid for future date when not allowed', () {
        final validator = ValidationService.date(allowFuture: false);
        final futureDate = DateTime.now().add(const Duration(days: 1));
        final dateStr = '${futureDate.year}-${futureDate.month}-${futureDate.day}';
        final result = validator(dateStr);
        expect(result.isInvalid, true);
        expect(result.errorMessage, 'Date cannot be in the future');
      });

      test('validates min date', () {
        final minDate = DateTime(2024, 1, 1);
        final validator = ValidationService.date(minDate: minDate);
        expect(validator('2023-12-31').isInvalid, true);
        expect(validator('2024-01-01').isValid, true);
      });

      test('validates max date', () {
        final maxDate = DateTime(2024, 12, 31);
        final validator = ValidationService.date(maxDate: maxDate);
        expect(validator('2024-12-31').isValid, true);
        expect(validator('2025-01-01').isInvalid, true);
      });
    });

    group('description', () {
      test('returns invalid for empty when required', () {
        final validator = ValidationService.description(required: true);
        final result = validator('');
        expect(result.isInvalid, true);
        expect(result.errorMessage, 'Description is required');
      });

      test('returns valid for empty when not required', () {
        final validator = ValidationService.description(required: false);
        expect(validator('').isValid, true);
        expect(validator(null).isValid, true);
      });

      test('validates min length', () {
        final validator = ValidationService.description(minLength: 5);
        expect(validator('abc').isInvalid, true);
        expect(validator('abcde').isValid, true);
      });

      test('validates max length', () {
        final validator = ValidationService.description(maxLength: 10);
        expect(validator('1234567890').isValid, true);
        expect(validator('12345678901').isInvalid, true);
      });
    });

    group('accountName', () {
      test('returns invalid for empty value', () {
        final validator = ValidationService.accountName();
        expect(validator('').isInvalid, true);
        expect(validator(null).isInvalid, true);
      });

      test('returns valid for valid account name', () {
        final validator = ValidationService.accountName();
        expect(validator('Checking Account').isValid, true);
        expect(validator('Savings-2024').isValid, true);
        expect(validator('My_Account').isValid, true);
      });

      test('validates max length', () {
        final validator = ValidationService.accountName(maxLength: 10);
        expect(validator('1234567890').isValid, true);
        expect(validator('12345678901').isInvalid, true);
      });

      test('returns invalid for special characters', () {
        final validator = ValidationService.accountName();
        expect(validator('Account@Name').isInvalid, true);
        expect(validator('Account!Name').isInvalid, true);
      });
    });

    group('categoryName', () {
      test('returns invalid for empty value', () {
        final validator = ValidationService.categoryName();
        expect(validator('').isInvalid, true);
      });

      test('returns valid for valid category name', () {
        final validator = ValidationService.categoryName();
        expect(validator('Food').isValid, true);
        expect(validator('Transportation').isValid, true);
      });

      test('validates max length', () {
        final validator = ValidationService.categoryName(maxLength: 10);
        expect(validator('1234567890').isValid, true);
        expect(validator('12345678901').isInvalid, true);
      });
    });

    group('tagName', () {
      test('returns invalid for empty value', () {
        final validator = ValidationService.tagName();
        expect(validator('').isInvalid, true);
      });

      test('returns valid for valid tag name', () {
        final validator = ValidationService.tagName();
        expect(validator('urgent').isValid, true);
        expect(validator('work').isValid, true);
      });

      test('validates max length', () {
        final validator = ValidationService.tagName(maxLength: 10);
        expect(validator('1234567890').isValid, true);
        expect(validator('12345678901').isInvalid, true);
      });
    });

    group('password', () {
      test('returns invalid for empty value', () {
        final validator = ValidationService.password();
        expect(validator('').isInvalid, true);
        expect(validator(null).isInvalid, true);
      });

      test('validates min length', () {
        final validator = ValidationService.password(minLength: 8);
        expect(validator('Abc123').isInvalid, true);
        expect(validator('Abc12345').isValid, true);
      });

      test('validates uppercase requirement', () {
        final validator = ValidationService.password(requireUppercase: true);
        expect(validator('abc12345').isInvalid, true);
        expect(validator('Abc12345').isValid, true);
      });

      test('validates lowercase requirement', () {
        final validator = ValidationService.password(requireLowercase: true);
        expect(validator('ABC12345').isInvalid, true);
        expect(validator('Abc12345').isValid, true);
      });

      test('validates digit requirement', () {
        final validator = ValidationService.password(requireDigit: true);
        expect(validator('Abcdefgh').isInvalid, true);
        expect(validator('Abc12345').isValid, true);
      });

      test('validates special character requirement', () {
        final validator = ValidationService.password(requireSpecialChar: true);
        expect(validator('Abc12345').isInvalid, true);
        expect(validator('Abc12345!').isValid, true);
      });
    });

    group('email', () {
      test('returns valid for empty when not required', () {
        final validator = ValidationService.email(required: false);
        expect(validator('').isValid, true);
        expect(validator(null).isValid, true);
      });

      test('returns invalid for empty when required', () {
        final validator = ValidationService.email(required: true);
        expect(validator('').isInvalid, true);
      });

      test('validates email format', () {
        final validator = ValidationService.email(required: true);
        expect(validator('invalid').isInvalid, true);
        expect(validator('invalid@').isInvalid, true);
        expect(validator('invalid@domain').isInvalid, true);
        expect(validator('valid@example.com').isValid, true);
        expect(validator('user.name@example.co.uk').isValid, true);
      });
    });

    group('numeric', () {
      test('returns valid for empty when not required', () {
        final validator = ValidationService.numeric(required: false);
        expect(validator('').isValid, true);
      });

      test('returns invalid for empty when required', () {
        final validator = ValidationService.numeric(required: true);
        expect(validator('').isInvalid, true);
      });

      test('validates numeric format', () {
        final validator = ValidationService.numeric(required: true);
        expect(validator('abc').isInvalid, true);
        expect(validator('123').isValid, true);
        expect(validator('123.45').isValid, true);
        expect(validator('1,000').isValid, true);
      });

      test('validates integer only', () {
        final validator = ValidationService.numeric(allowDecimal: false);
        expect(validator('123').isValid, true);
        expect(validator('123.45').isInvalid, true);
      });

      test('validates min value', () {
        final validator = ValidationService.numeric(minValue: 10);
        expect(validator('5').isInvalid, true);
        expect(validator('10').isValid, true);
      });

      test('validates max value', () {
        final validator = ValidationService.numeric(maxValue: 100);
        expect(validator('50').isValid, true);
        expect(validator('150').isInvalid, true);
      });
    });

    group('percentage', () {
      test('validates percentage range', () {
        final validator = ValidationService.percentage();
        expect(validator('0').isValid, true);
        expect(validator('50').isValid, true);
        expect(validator('100').isValid, true);
        expect(validator('-1').isInvalid, true);
        expect(validator('101').isInvalid, true);
      });

      test('allows decimal percentages', () {
        final validator = ValidationService.percentage();
        expect(validator('50.5').isValid, true);
        expect(validator('99.99').isValid, true);
      });
    });

    group('phone', () {
      test('returns valid for empty when not required', () {
        final validator = ValidationService.phone(required: false);
        expect(validator('').isValid, true);
      });

      test('validates phone format', () {
        final validator = ValidationService.phone(required: true);
        expect(validator('123').isInvalid, true);
        expect(validator('1234567').isValid, true);
        expect(validator('+1 (555) 123-4567').isValid, true);
        expect(validator('555-123-4567').isValid, true);
      });
    });

    group('url', () {
      test('returns valid for empty when not required', () {
        final validator = ValidationService.url(required: false);
        expect(validator('').isValid, true);
      });

      test('validates URL format', () {
        final validator = ValidationService.url(required: true);
        expect(validator('invalid').isInvalid, true);
        expect(validator('http://example.com').isValid, true);
        expect(validator('https://example.com').isValid, true);
      });

      test('validates allowed schemes', () {
        final validator = ValidationService.url(
          allowedSchemes: ['https'],
        );
        expect(validator('http://example.com').isInvalid, true);
        expect(validator('https://example.com').isValid, true);
      });
    });

    group('combine', () {
      test('returns valid when all validators pass', () {
        final validator = ValidationService.combine([
          ValidationService.required(),
          ValidationService.numeric(),
        ]);
        expect(validator('123').isValid, true);
      });

      test('returns first failed validation', () {
        final validator = ValidationService.combine([
          ValidationService.required(message: 'Required'),
          ValidationService.numeric(invalidFormatMessage: 'Must be numeric'),
        ]);
        final result = validator('');
        expect(result.errorMessage, 'Required');
      });

      test('returns second failed validation when first passes', () {
        final validator = ValidationService.combine([
          ValidationService.required(message: 'Required'),
          ValidationService.numeric(invalidFormatMessage: 'Must be numeric'),
        ]);
        final result = validator('abc');
        expect(result.errorMessage, 'Must be numeric');
      });
    });

    group('custom', () {
      test('returns valid when custom validation passes', () {
        final validator = ValidationService.custom(
          (value) => value == 'valid',
          message: 'Must be "valid"',
        );
        expect(validator('valid').isValid, true);
      });

      test('returns invalid with custom message when validation fails', () {
        final validator = ValidationService.custom(
          (value) => value == 'valid',
          message: 'Must be "valid"',
        );
        final result = validator('invalid');
        expect(result.isInvalid, true);
        expect(result.errorMessage, 'Must be "valid"');
      });
    });
  });

  group('BusinessValidators', () {
    group('balanceCheck', () {
      test('returns valid when sufficient balance', () {
        final validator = BusinessValidators.balanceCheck(
          currentBalance: 100,
        );
        expect(validator('-50').isValid, true);
      });

      test('returns invalid when insufficient balance', () {
        final validator = BusinessValidators.balanceCheck(
          currentBalance: 100,
        );
        final result = validator('-150');
        expect(result.isInvalid, true);
        expect(result.errorMessage, contains('Insufficient funds'));
      });

      test('allows overdraft when enabled', () {
        final validator = BusinessValidators.balanceCheck(
          currentBalance: 100,
          allowOverdraft: true,
          overdraftLimit: 50,
        );
        expect(validator('-120').isValid, true);
        expect(validator('-160').isInvalid, true);
      });

      test('ignores positive amounts', () {
        final validator = BusinessValidators.balanceCheck(
          currentBalance: 100,
        );
        expect(validator('50').isValid, true);
      });
    });

    group('accountingPeriod', () {
      test('returns valid for date within period', () {
        final validator = BusinessValidators.accountingPeriod(
          periodStart: DateTime(2024, 1, 1),
          periodEnd: DateTime(2024, 12, 31),
        );
        expect(validator('2024-06-15').isValid, true);
      });

      test('returns invalid for date outside period', () {
        final validator = BusinessValidators.accountingPeriod(
          periodStart: DateTime(2024, 1, 1),
          periodEnd: DateTime(2024, 12, 31),
        );
        expect(validator('2023-12-31').isInvalid, true);
        expect(validator('2025-01-01').isInvalid, true);
      });
    });

    group('splitTotal', () {
      test('returns valid when splits match parent amount', () {
        final validator = BusinessValidators.splitTotal(
          parentAmount: 100,
          splitAmounts: [30, 30, 40],
        );
        expect(validator(null).isValid, true);
      });

      test('returns invalid when splits do not match', () {
        final validator = BusinessValidators.splitTotal(
          parentAmount: 100,
          splitAmounts: [30, 30, 30],
        );
        final result = validator(null);
        expect(result.isInvalid, true);
        expect(result.errorMessage, contains('must equal'));
      });

      test('allows small floating point differences', () {
        final validator = BusinessValidators.splitTotal(
          parentAmount: 100,
          splitAmounts: [33.33, 33.33, 33.33],
        );
        expect(validator(null).isValid, true);
      });
    });

    group('budgetLimit', () {
      test('returns valid when budget exceeds spending', () {
        final validator = BusinessValidators.budgetLimit(
          currentSpent: 50,
        );
        expect(validator('100').isValid, true);
      });

      test('returns invalid when budget is less than spending', () {
        final validator = BusinessValidators.budgetLimit(
          currentSpent: 100,
        );
        final result = validator('50');
        expect(result.isInvalid, true);
        expect(result.errorMessage, contains('less than current spending'));
      });
    });
  });
}
