import 'package:test/test.dart';
import 'package:core/src/usecases/journal_entry_validator.dart';
import 'package:core/src/models/split.dart';
import 'package:core/src/models/account.dart';

void main() {
  late JournalEntryValidator validator;

  setUp(() {
    validator = JournalEntryValidator();
  });

  group('JournalEntryValidator', () {
    group('validates balanced 2-split entry (debit + credit)', () {
      test('accepts valid debit and credit pair with equal amounts', () {
        final debitSplit = Split.fromValue(
          transactionId: 'tx-1',
          accountId: 'acc-asset',
          value: -100.0, // Debit (negative for asset increase in this context)
        );

        final creditSplit = Split.fromValue(
          transactionId: 'tx-1',
          accountId: 'acc-liability',
          value: 100.0, // Credit
        );

        final result = validator.validate([debitSplit, creditSplit]);

        expect(result.isValid, isTrue);
        expect(result.errorMessage, isNull);
      });

      test('accepts balanced entry with different denominators', () {
        final split1 = Split(
          transactionId: 'tx-1',
          accountId: 'acc-1',
          valueNum: -1000,
          valueDenom: 10, // -100.0
          quantityNum: 0,
          quantityDenom: 1,
        );

        final split2 = Split(
          transactionId: 'tx-1',
          accountId: 'acc-2',
          valueNum: 10000,
          valueDenom: 100, // 100.0
          quantityNum: 0,
          quantityDenom: 1,
        );

        final result = validator.validate([split1, split2]);

        expect(result.isValid, isTrue);
      });
    });

    group('validates balanced multi-split entry (3+ splits)', () {
      test('accepts valid 3-split entry that balances', () {
        final split1 = Split.fromValue(
          transactionId: 'tx-1',
          accountId: 'acc-1',
          value: -100.0,
        );

        final split2 = Split.fromValue(
          transactionId: 'tx-1',
          accountId: 'acc-2',
          value: 60.0,
        );

        final split3 = Split.fromValue(
          transactionId: 'tx-1',
          accountId: 'acc-3',
          value: 40.0,
        );

        final result = validator.validate([split1, split2, split3]);

        expect(result.isValid, isTrue);
        expect(result.errorMessage, isNull);
      });

      test('accepts valid 4-split entry with complex amounts', () {
        final splits = [
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-1', value: -250.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-2', value: 100.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-3', value: 75.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-4', value: 75.0),
        ];

        final result = validator.validate(splits);

        expect(result.isValid, isTrue);
      });

      test('accepts entry with multiple debits and single credit', () {
        final splits = [
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-1', value: -50.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-2', value: -50.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-3', value: 100.0),
        ];

        final result = validator.validate(splits);

        expect(result.isValid, isTrue);
      });
    });

    group('rejects unbalanced entry (debits ≠ credits)', () {
      test('rejects when total is positive', () {
        final split1 = Split.fromValue(
          transactionId: 'tx-1',
          accountId: 'acc-1',
          value: -100.0,
        );

        final split2 = Split.fromValue(
          transactionId: 'tx-1',
          accountId: 'acc-2',
          value: 150.0, // More than debit
        );

        final result = validator.validate([split1, split2]);

        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('not balanced'));
        expect(result.errorMessage, contains('50'));
      });

      test('rejects when total is negative', () {
        final split1 = Split.fromValue(
          transactionId: 'tx-1',
          accountId: 'acc-1',
          value: -200.0,
        );

        final split2 = Split.fromValue(
          transactionId: 'tx-1',
          accountId: 'acc-2',
          value: 100.0,
        );

        final result = validator.validate([split1, split2]);

        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('not balanced'));
      });

      test('rejects unbalanced multi-split entry', () {
        final splits = [
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-1', value: -100.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-2', value: 30.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-3', value: 40.0),
          // Missing 30.0 to balance
        ];

        final result = validator.validate(splits);

        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('not balanced'));
      });
    });

    group('handles zero-value splits correctly', () {
      test('accepts entry with zero-value split but generates warning', () {
        final splits = [
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-1', value: -100.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-2', value: 100.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-3', value: 0.0), // Zero value
        ];

        final result = validator.validate(splits);

        expect(result.isValid, isTrue);
        expect(result.warnings, isNotEmpty);
        expect(result.warnings.any((w) => w.contains('zero-value')), isTrue);
      });

      test('accepts entry where all splits are zero (balanced)', () {
        final splits = [
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-1', value: 0.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-2', value: 0.0),
        ];

        final result = validator.validate(splits);

        expect(result.isValid, isTrue);
      });
    });

    group('applies account type sign conventions', () {
      test('validates accounts exist when account map provided', () {
        final account = Account(
          id: 'acc-1',
          name: 'Cash',
          accountType: AccountType.asset,
          commodityId: 'USD',
        );

        final splits = [
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-1', value: -100.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-2', value: 100.0),
        ];

        final accounts = {'acc-1': account};
        final result = validator.validate(splits, accounts: accounts);

        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('Account not found'));
        expect(result.errorMessage, contains('acc-2'));
      });

      test('accepts when all accounts in map exist', () {
        final assetAccount = Account(
          id: 'acc-asset',
          name: 'Cash',
          accountType: AccountType.asset,
          commodityId: 'USD',
        );

        final expenseAccount = Account(
          id: 'acc-expense',
          name: 'Office Supplies',
          accountType: AccountType.expense,
          commodityId: 'USD',
        );

        final splits = [
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-asset', value: -100.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-expense', value: 100.0),
        ];

        final accounts = {
          'acc-asset': assetAccount,
          'acc-expense': expenseAccount,
        };

        final result = validator.validate(splits, accounts: accounts);

        expect(result.isValid, isTrue);
      });

      test('validates different account types correctly', () {
        final accounts = {
          'acc-asset': Account(
            id: 'acc-asset',
            name: 'Bank',
            accountType: AccountType.asset,
            commodityId: 'USD',
          ),
          'acc-liability': Account(
            id: 'acc-liability',
            name: 'Credit Card',
            accountType: AccountType.liability,
            commodityId: 'USD',
          ),
          'acc-equity': Account(
            id: 'acc-equity',
            name: 'Owner Equity',
            accountType: AccountType.equity,
            commodityId: 'USD',
          ),
          'acc-income': Account(
            id: 'acc-income',
            name: 'Sales',
            accountType: AccountType.income,
            commodityId: 'USD',
          ),
          'acc-expense': Account(
            id: 'acc-expense',
            name: 'Rent',
            accountType: AccountType.expense,
            commodityId: 'USD',
          ),
        };

        // Balanced entry across different account types
        final splits = [
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-asset', value: -100.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-liability', value: 50.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-equity', value: 30.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-income', value: 15.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-expense', value: 5.0),
        ];

        final result = validator.validate(splits, accounts: accounts);

        expect(result.isValid, isTrue);
      });
    });

    group('validates rational number precision (valueNum/valueDenom)', () {
      test('accepts valid rational numbers', () {
        final split1 = Split(
          transactionId: 'tx-1',
          accountId: 'acc-1',
          valueNum: -3333,
          valueDenom: 100, // -33.33
          quantityNum: 0,
          quantityDenom: 1,
        );

        final split2 = Split(
          transactionId: 'tx-1',
          accountId: 'acc-2',
          valueNum: 3333,
          valueDenom: 100, // 33.33
          quantityNum: 0,
          quantityDenom: 1,
        );

        final result = validator.validate([split1, split2]);

        expect(result.isValid, isTrue);
      });

      test('rejects zero denominator', () {
        final split1 = Split(
          transactionId: 'tx-1',
          accountId: 'acc-1',
          valueNum: -100,
          valueDenom: 0, // Invalid!
          quantityNum: 0,
          quantityDenom: 1,
        );

        final split2 = Split(
          transactionId: 'tx-1',
          accountId: 'acc-2',
          valueNum: 100,
          valueDenom: 1,
          quantityNum: 0,
          quantityDenom: 1,
        );

        final result = validator.validate([split1, split2]);

        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('Invalid denominator'));
      });

      test('rejects negative denominator', () {
        final split1 = Split(
          transactionId: 'tx-1',
          accountId: 'acc-1',
          valueNum: -100,
          valueDenom: -1, // Invalid!
          quantityNum: 0,
          quantityDenom: 1,
        );

        final split2 = Split(
          transactionId: 'tx-1',
          accountId: 'acc-2',
          valueNum: 100,
          valueDenom: 1,
          quantityNum: 0,
          quantityDenom: 1,
        );

        final result = validator.validate([split1, split2]);

        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('Denominator must be positive'));
      });

      test('handles high precision fractions correctly', () {
        // Test with 1/3 + 1/3 + 1/3 = 1
        final splits = [
          Split(
            transactionId: 'tx-1',
            accountId: 'acc-1',
            valueNum: -1,
            valueDenom: 1,
            quantityNum: 0,
            quantityDenom: 1,
          ),
          Split(
            transactionId: 'tx-1',
            accountId: 'acc-2',
            valueNum: 1,
            valueDenom: 3,
            quantityNum: 0,
            quantityDenom: 1,
          ),
          Split(
            transactionId: 'tx-1',
            accountId: 'acc-3',
            valueNum: 1,
            valueDenom: 3,
            quantityNum: 0,
            quantityDenom: 1,
          ),
          Split(
            transactionId: 'tx-1',
            accountId: 'acc-4',
            valueNum: 1,
            valueDenom: 3,
            quantityNum: 0,
            quantityDenom: 1,
          ),
        ];

        final result = validator.validate(splits);

        expect(result.isValid, isTrue);
      });

      test('validates quantity denominator as well', () {
        final split1 = Split(
          transactionId: 'tx-1',
          accountId: 'acc-1',
          valueNum: -100,
          valueDenom: 1,
          quantityNum: 0,
          quantityDenom: 0, // Invalid!
        );

        final split2 = Split(
          transactionId: 'tx-1',
          accountId: 'acc-2',
          valueNum: 100,
          valueDenom: 1,
          quantityNum: 0,
          quantityDenom: 1,
        );

        final result = validator.validate([split1, split2]);

        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('quantity denominator'));
      });
    });

    group('prevents duplicate account in single entry', () {
      test('rejects when same account appears twice', () {
        final splits = [
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-1', value: -100.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-1', value: 100.0), // Duplicate!
        ];

        final result = validator.validate(splits);

        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('Duplicate account'));
        expect(result.errorMessage, contains('acc-1'));
      });

      test('rejects duplicate in multi-split entry', () {
        final splits = [
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-1', value: -100.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-2', value: 50.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-1', value: 50.0), // Duplicate!
        ];

        final result = validator.validate(splits);

        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('Duplicate account'));
      });

      test('accepts different accounts with same parent', () {
        // Different accounts (even if they share a parent) are allowed
        final splits = [
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-checking', value: -100.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-savings', value: 100.0),
        ];

        final result = validator.validate(splits);

        expect(result.isValid, isTrue);
      });
    });

    group('validates minimum 2 splits required', () {
      test('rejects entry with no splits', () {
        final result = validator.validate([]);

        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('at least 2 splits'));
      });

      test('rejects entry with single split', () {
        final split = Split.fromValue(
          transactionId: 'tx-1',
          accountId: 'acc-1',
          value: 100.0,
        );

        final result = validator.validate([split]);

        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('at least 2 splits'));
      });

      test('accepts entry with exactly 2 splits', () {
        final splits = [
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-1', value: -100.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-2', value: 100.0),
        ];

        final result = validator.validate(splits);

        expect(result.isValid, isTrue);
      });
    });

    // Additional helper method tests
    group('validateTwoSplitEntry', () {
      test('validates simple two-split entry', () {
        final debit = Split.fromValue(
          transactionId: 'tx-1',
          accountId: 'acc-1',
          value: -100.0,
        );

        final credit = Split.fromValue(
          transactionId: 'tx-1',
          accountId: 'acc-2',
          value: 100.0,
        );

        final result = validator.validateTwoSplitEntry(
          debitSplit: debit,
          creditSplit: credit,
        );

        expect(result.isValid, isTrue);
      });
    });

    group('validateMultiSplitEntry', () {
      test('requires at least 3 splits', () {
        final splits = [
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-1', value: -100.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-2', value: 100.0),
        ];

        final result = validator.validateMultiSplitEntry(splits);

        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('at least 3 splits'));
      });

      test('accepts valid multi-split entry', () {
        final splits = [
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-1', value: -100.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-2', value: 60.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-3', value: 40.0),
        ];

        final result = validator.validateMultiSplitEntry(splits);

        expect(result.isValid, isTrue);
      });
    });

    group('isBalanced', () {
      test('returns true for balanced entry', () {
        final splits = [
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-1', value: -100.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-2', value: 100.0),
        ];

        expect(validator.isBalanced(splits), isTrue);
      });

      test('returns false for unbalanced entry', () {
        final splits = [
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-1', value: -100.0),
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-2', value: 50.0),
        ];

        expect(validator.isBalanced(splits), isFalse);
      });

      test('returns false for less than 2 splits', () {
        final splits = [
          Split.fromValue(transactionId: 'tx-1', accountId: 'acc-1', value: 100.0),
        ];

        expect(validator.isBalanced(splits), isFalse);
      });
    });
  });
}
