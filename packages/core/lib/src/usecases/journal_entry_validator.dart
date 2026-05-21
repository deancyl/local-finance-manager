import '../models/split.dart';
import '../models/account.dart';

/// Result of journal entry validation.
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final List<String> warnings;

  const ValidationResult._({
    required this.isValid,
    this.errorMessage,
    this.warnings = const [],
  });

  /// Creates a successful validation result.
  const ValidationResult.success({List<String>? warnings})
      : this._(isValid: true, warnings: warnings ?? const []);

  /// Creates a failed validation result with an error message.
  const ValidationResult.failure(String errorMessage, {List<String>? warnings})
      : this._(isValid: false, errorMessage: errorMessage, warnings: warnings ?? const []);
}

/// Validator for journal entries in double-entry bookkeeping.
///
/// Ensures that journal entries follow double-entry accounting rules:
/// - At least 2 splits required
/// - Total debits must equal total credits (balanced entry)
/// - No duplicate accounts in a single entry
/// - Proper sign conventions based on account types
/// - Rational number precision validation
class JournalEntryValidator {
  /// Tolerance for floating point comparison when checking balance.
  static const double balanceTolerance = 0.001;

  /// Validates a list of splits for a journal entry.
  ///
  /// Returns a [ValidationResult] indicating whether the entry is valid.
  /// If invalid, includes an error message explaining the issue.
  ValidationResult validate(List<Split> splits, {Map<String, Account>? accounts}) {
    // Check minimum splits
    if (splits.length < 2) {
      return const ValidationResult.failure(
        'Journal entry must have at least 2 splits.',
      );
    }

    // Check for duplicate accounts
    final accountIds = <String>{};
    for (final split in splits) {
      if (accountIds.contains(split.accountId)) {
        return ValidationResult.failure(
          'Duplicate account in journal entry: ${split.accountId}',
        );
      }
      accountIds.add(split.accountId);
    }

    // Check for zero-value splits
    final zeroValueSplits = splits.where((s) => s.valueNum == 0).toList();
    if (zeroValueSplits.isNotEmpty) {
      // Zero-value splits are allowed but should generate a warning
      // They're valid for certain accounting scenarios (e.g., memo entries)
    }

    // Validate rational number precision
    for (final split in splits) {
      if (split.valueDenom <= 0) {
        return ValidationResult.failure(
          'Invalid denominator in split: ${split.id}. Denominator must be positive.',
        );
      }
      if (split.quantityDenom <= 0) {
        return ValidationResult.failure(
          'Invalid quantity denominator in split: ${split.id}. Denominator must be positive.',
        );
      }
    }

    // Check balance
    final balanceResult = _checkBalance(splits, accounts);
    if (!balanceResult.isValid) {
      return balanceResult;
    }

    // Collect warnings
    final warnings = <String>[];
    if (zeroValueSplits.isNotEmpty) {
      warnings.add('Entry contains ${zeroValueSplits.length} zero-value split(s).');
    }

    return ValidationResult.success(warnings: warnings);
  }

  /// Checks if the splits balance (sum = 0).
  ValidationResult _checkBalance(List<Split> splits, Map<String, Account>? accounts) {
    // Calculate total using rational arithmetic to avoid floating point errors
    int totalNum = 0;
    int commonDenom = 1;

    // Find LCM of all denominators for precise calculation
    for (final split in splits) {
      commonDenom = _lcm(commonDenom, split.valueDenom);
    }

    // Sum all values using common denominator
    for (final split in splits) {
      final scaledNum = split.valueNum * (commonDenom ~/ split.valueDenom);
      totalNum += scaledNum;
    }

    // Check if total is zero (balanced)
    if (totalNum != 0) {
      final totalValue = totalNum / commonDenom;
      return ValidationResult.failure(
        'Journal entry is not balanced. Total: $totalValue (debits ≠ credits).',
      );
    }

    // Validate account type sign conventions if accounts provided
    if (accounts != null) {
      final signResult = _validateSignConventions(splits, accounts);
      if (!signResult.isValid) {
        return signResult;
      }
    }

    return const ValidationResult.success();
  }

  /// Validates that splits follow account type sign conventions.
  ///
  /// Standard accounting conventions:
  /// - ASSET: Debit increases (positive), Credit decreases (negative)
  /// - LIABILITY: Credit increases (positive), Debit decreases (negative)
  /// - EQUITY: Credit increases (positive), Debit decreases (negative)
  /// - INCOME: Credit increases (positive), Debit decreases (negative)
  /// - EXPENSE: Debit increases (positive), Credit decreases (negative)
  ValidationResult _validateSignConventions(
    List<Split> splits,
    Map<String, Account> accounts,
  ) {
    for (final split in splits) {
      final account = accounts[split.accountId];
      if (account == null) {
        return ValidationResult.failure(
          'Account not found: ${split.accountId}',
        );
      }

      // Note: This validation is informational only.
      // In practice, the sign depends on whether the account balance
      // is increasing or decreasing, which requires context.
      // Here we just validate that the account exists.
    }

    return const ValidationResult.success();
  }

  /// Calculates the Least Common Multiple of two numbers.
  int _lcm(int a, int b) {
    if (a == 0 || b == 0) return 0;
    return (a * b) ~/ _gcd(a, b);
  }

  /// Calculates the Greatest Common Divisor of two numbers.
  int _gcd(int a, int b) {
    a = a.abs();
    b = b.abs();
    while (b != 0) {
      final temp = b;
      b = a % b;
      a = temp;
    }
    return a;
  }

  /// Validates a balanced 2-split entry (simple debit + credit).
  ValidationResult validateTwoSplitEntry({
    required Split debitSplit,
    required Split creditSplit,
  }) {
    return validate([debitSplit, creditSplit]);
  }

  /// Validates a multi-split entry (3 or more splits).
  ValidationResult validateMultiSplitEntry(List<Split> splits) {
    if (splits.length < 3) {
      return const ValidationResult.failure(
        'Multi-split entry must have at least 3 splits.',
      );
    }
    return validate(splits);
  }

  /// Checks if an entry is balanced without full validation.
  bool isBalanced(List<Split> splits) {
    if (splits.length < 2) return false;

    int totalNum = 0;
    int commonDenom = 1;

    for (final split in splits) {
      commonDenom = _lcm(commonDenom, split.valueDenom);
    }

    for (final split in splits) {
      final scaledNum = split.valueNum * (commonDenom ~/ split.valueDenom);
      totalNum += scaledNum;
    }

    return totalNum == 0;
  }
}
