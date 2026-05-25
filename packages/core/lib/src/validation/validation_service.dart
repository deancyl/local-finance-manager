/// Validation service providing common validators for form inputs.
library validation_service;

/// Result of a validation operation.
class ValidationResult {
  /// Whether the validation passed.
  final bool isValid;

  /// Error message if validation failed, null if valid.
  final String? errorMessage;

  const ValidationResult._(this.isValid, this.errorMessage);

  /// Creates a valid result.
  const ValidationResult.valid() : this._(true, null);

  /// Creates an invalid result with an error message.
  const ValidationResult.invalid(String message) : this._(false, message);

  /// Returns true if validation passed.
  bool get isInvalid => !isValid;
}

/// Type definition for validator functions.
typedef Validator = ValidationResult Function(String? value);

/// Service providing common validation logic for form inputs.
class ValidationService {
  const ValidationService._();

  /// Validates that a field is not empty.
  static Validator required({String? message}) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return ValidationResult.invalid(message ?? 'This field is required');
      }
      return const ValidationResult.valid();
    };
  }

  /// Validates an amount field (monetary value).
  static Validator amount({
    String? requiredMessage,
    String? invalidFormatMessage,
    String? negativeMessage,
    String? zeroMessage,
    bool allowNegative = false,
    bool allowZero = true,
    double? minValue,
    double? maxValue,
  }) {
    return (String? value) {
      // Check required
      if (value == null || value.trim().isEmpty) {
        return ValidationResult.invalid(
          requiredMessage ?? 'Amount is required',
        );
      }

      // Parse amount - handle various formats
      final cleanValue = value.trim().replaceAll(',', '').replaceAll(' ', '');
      final parsed = double.tryParse(cleanValue);

      if (parsed == null) {
        return ValidationResult.invalid(
          invalidFormatMessage ?? 'Please enter a valid amount',
        );
      }

      // Check negative
      if (!allowNegative && parsed < 0) {
        return ValidationResult.invalid(
          negativeMessage ?? 'Amount cannot be negative',
        );
      }

      // Check zero
      if (!allowZero && parsed == 0) {
        return ValidationResult.invalid(
          zeroMessage ?? 'Amount cannot be zero',
        );
      }

      // Check min value
      if (minValue != null && parsed < minValue) {
        return ValidationResult.invalid(
          'Amount must be at least $minValue',
        );
      }

      // Check max value
      if (maxValue != null && parsed > maxValue) {
        return ValidationResult.invalid(
          'Amount cannot exceed $maxValue',
        );
      }

      return const ValidationResult.valid();
    };
  }

  /// Validates a date string.
  static Validator date({
    String? requiredMessage,
    String? invalidFormatMessage,
    String? pastMessage,
    String? futureMessage,
    bool allowPast = true,
    bool allowFuture = true,
    DateTime? minDate,
    DateTime? maxDate,
  }) {
    return (String? value) {
      // Check required
      if (value == null || value.trim().isEmpty) {
        return ValidationResult.invalid(
          requiredMessage ?? 'Date is required',
        );
      }

      // Try parsing common date formats
      DateTime? parsedDate;
      final formats = [
        RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$'), // YYYY-MM-DD
        RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$'), // MM/DD/YYYY
        RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{4})$'), // DD-MM-YYYY
      ];

      for (final format in formats) {
        final match = format.firstMatch(value.trim());
        if (match != null) {
          try {
            if (format == formats[0]) {
              // YYYY-MM-DD
              parsedDate = DateTime(
                int.parse(match.group(1)!),
                int.parse(match.group(2)!),
                int.parse(match.group(3)!),
              );
            } else if (format == formats[1]) {
              // MM/DD/YYYY
              parsedDate = DateTime(
                int.parse(match.group(3)!),
                int.parse(match.group(1)!),
                int.parse(match.group(2)!),
              );
            } else {
              // DD-MM-YYYY
              parsedDate = DateTime(
                int.parse(match.group(3)!),
                int.parse(match.group(2)!),
                int.parse(match.group(1)!),
              );
            }
            break;
          } catch (_) {
            // Continue to next format
          }
        }
      }

      // Try ISO 8601 format
      if (parsedDate == null) {
        parsedDate = DateTime.tryParse(value.trim());
      }

      if (parsedDate == null) {
        return ValidationResult.invalid(
          invalidFormatMessage ?? 'Please enter a valid date (YYYY-MM-DD)',
        );
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final checkDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

      // Check past
      if (!allowPast && checkDate.isBefore(today)) {
        return ValidationResult.invalid(
          pastMessage ?? 'Date cannot be in the past',
        );
      }

      // Check future
      if (!allowFuture && checkDate.isAfter(today)) {
        return ValidationResult.invalid(
          futureMessage ?? 'Date cannot be in the future',
        );
      }

      // Check min date
      if (minDate != null && parsedDate.isBefore(minDate)) {
        return ValidationResult.invalid(
          'Date must be on or after ${_formatDate(minDate)}',
        );
      }

      // Check max date
      if (maxDate != null && parsedDate.isAfter(maxDate)) {
        return ValidationResult.invalid(
          'Date must be on or before ${_formatDate(maxDate)}',
        );
      }

      return const ValidationResult.valid();
    };
  }

  /// Validates a description field.
  static Validator description({
    String? requiredMessage,
    String? minLengthMessage,
    String? maxLengthMessage,
    int minLength = 0,
    int maxLength = 500,
    bool required = false,
  }) {
    return (String? value) {
      final trimmed = value?.trim() ?? '';

      // Check required
      if (required && trimmed.isEmpty) {
        return ValidationResult.invalid(
          requiredMessage ?? 'Description is required',
        );
      }

      // Check min length
      if (trimmed.isNotEmpty && trimmed.length < minLength) {
        return ValidationResult.invalid(
          minLengthMessage ?? 'Description must be at least $minLength characters',
        );
      }

      // Check max length
      if (trimmed.length > maxLength) {
        return ValidationResult.invalid(
          maxLengthMessage ?? 'Description cannot exceed $maxLength characters',
        );
      }

      return const ValidationResult.valid();
    };
  }

  /// Validates an account name.
  static Validator accountName({
    String? requiredMessage,
    String? minLengthMessage,
    String? maxLengthMessage,
    String? invalidCharsMessage,
    int minLength = 1,
    int maxLength = 100,
  }) {
    return (String? value) {
      // Check required
      if (value == null || value.trim().isEmpty) {
        return ValidationResult.invalid(
          requiredMessage ?? 'Account name is required',
        );
      }

      final trimmed = value.trim();

      // Check min length
      if (trimmed.length < minLength) {
        return ValidationResult.invalid(
          minLengthMessage ?? 'Account name must be at least $minLength characters',
        );
      }

      // Check max length
      if (trimmed.length > maxLength) {
        return ValidationResult.invalid(
          maxLengthMessage ?? 'Account name cannot exceed $maxLength characters',
        );
      }

      // Check for invalid characters (allow letters, numbers, spaces, hyphens, underscores)
      final validPattern = RegExp(r'^[\p{L}\p{N}\s\-_]+$', unicode: true);
      if (!validPattern.hasMatch(trimmed)) {
        return ValidationResult.invalid(
          invalidCharsMessage ?? 'Account name contains invalid characters',
        );
      }

      return const ValidationResult.valid();
    };
  }

  /// Validates a category name.
  static Validator categoryName({
    String? requiredMessage,
    String? maxLengthMessage,
    int maxLength = 50,
  }) {
    return (String? value) {
      // Check required
      if (value == null || value.trim().isEmpty) {
        return ValidationResult.invalid(
          requiredMessage ?? 'Category name is required',
        );
      }

      // Check max length
      if (value.trim().length > maxLength) {
        return ValidationResult.invalid(
          maxLengthMessage ?? 'Category name cannot exceed $maxLength characters',
        );
      }

      return const ValidationResult.valid();
    };
  }

  /// Validates a tag name.
  static Validator tagName({
    String? requiredMessage,
    String? maxLengthMessage,
    int maxLength = 30,
  }) {
    return (String? value) {
      // Check required
      if (value == null || value.trim().isEmpty) {
        return ValidationResult.invalid(
          requiredMessage ?? 'Tag name is required',
        );
      }

      // Check max length
      if (value.trim().length > maxLength) {
        return ValidationResult.invalid(
          maxLengthMessage ?? 'Tag name cannot exceed $maxLength characters',
        );
      }

      return const ValidationResult.valid();
    };
  }

  /// Validates a password field.
  static Validator password({
    String? requiredMessage,
    String? minLengthMessage,
    String? complexityMessage,
    int minLength = 8,
    bool requireUppercase = true,
    bool requireLowercase = true,
    bool requireDigit = true,
    bool requireSpecialChar = false,
  }) {
    return (String? value) {
      // Check required
      if (value == null || value.isEmpty) {
        return ValidationResult.invalid(
          requiredMessage ?? 'Password is required',
        );
      }

      // Check min length
      if (value.length < minLength) {
        return ValidationResult.invalid(
          minLengthMessage ?? 'Password must be at least $minLength characters',
        );
      }

      // Check complexity
      final hasUppercase = RegExp(r'[A-Z]').hasMatch(value);
      final hasLowercase = RegExp(r'[a-z]').hasMatch(value);
      final hasDigit = RegExp(r'[0-9]').hasMatch(value);
      final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value);

      if (requireUppercase && !hasUppercase) {
        return ValidationResult.invalid(
          complexityMessage ?? 'Password must contain at least one uppercase letter',
        );
      }

      if (requireLowercase && !hasLowercase) {
        return ValidationResult.invalid(
          complexityMessage ?? 'Password must contain at least one lowercase letter',
        );
      }

      if (requireDigit && !hasDigit) {
        return ValidationResult.invalid(
          complexityMessage ?? 'Password must contain at least one digit',
        );
      }

      if (requireSpecialChar && !hasSpecial) {
        return ValidationResult.invalid(
          complexityMessage ?? 'Password must contain at least one special character',
        );
      }

      return const ValidationResult.valid();
    };
  }

  /// Validates an email address.
  static Validator email({
    String? requiredMessage,
    String? invalidFormatMessage,
    bool required = false,
  }) {
    return (String? value) {
      final trimmed = value?.trim() ?? '';

      // Check required
      if (required && trimmed.isEmpty) {
        return ValidationResult.invalid(
          requiredMessage ?? 'Email is required',
        );
      }

      // Allow empty if not required
      if (trimmed.isEmpty && !required) {
        return const ValidationResult.valid();
      }

      // Validate email format
      final emailPattern = RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      );

      if (!emailPattern.hasMatch(trimmed)) {
        return ValidationResult.invalid(
          invalidFormatMessage ?? 'Please enter a valid email address',
        );
      }

      return const ValidationResult.valid();
    };
  }

  /// Validates a numeric field.
  static Validator numeric({
    String? requiredMessage,
    String? invalidFormatMessage,
    String? minValueMessage,
    String? maxValueMessage,
    bool required = false,
    bool allowDecimal = true,
    num? minValue,
    num? maxValue,
  }) {
    return (String? value) {
      final trimmed = value?.trim() ?? '';

      // Check required
      if (required && trimmed.isEmpty) {
        return ValidationResult.invalid(
          requiredMessage ?? 'This field is required',
        );
      }

      // Allow empty if not required
      if (trimmed.isEmpty && !required) {
        return const ValidationResult.valid();
      }

      // Parse number
      num? parsed;
      if (allowDecimal) {
        parsed = num.tryParse(trimmed.replaceAll(',', ''));
      } else {
        parsed = int.tryParse(trimmed.replaceAll(',', ''));
      }

      if (parsed == null) {
        return ValidationResult.invalid(
          invalidFormatMessage ?? 'Please enter a valid number',
        );
      }

      // Check min value
      if (minValue != null && parsed < minValue) {
        return ValidationResult.invalid(
          minValueMessage ?? 'Value must be at least $minValue',
        );
      }

      // Check max value
      if (maxValue != null && parsed > maxValue) {
        return ValidationResult.invalid(
          maxValueMessage ?? 'Value cannot exceed $maxValue',
        );
      }

      return const ValidationResult.valid();
    };
  }

  /// Validates a percentage field (0-100).
  static Validator percentage({
    String? requiredMessage,
    String? invalidFormatMessage,
    String? rangeMessage,
    bool required = false,
  }) {
    return numeric(
      required: required,
      requiredMessage: requiredMessage ?? 'Percentage is required',
      invalidFormatMessage: invalidFormatMessage ?? 'Please enter a valid percentage',
      allowDecimal: true,
      minValue: 0,
      maxValue: 100,
      minValueMessage: rangeMessage ?? 'Percentage must be between 0 and 100',
      maxValueMessage: rangeMessage ?? 'Percentage must be between 0 and 100',
    );
  }

  /// Validates a phone number.
  static Validator phone({
    String? requiredMessage,
    String? invalidFormatMessage,
    bool required = false,
  }) {
    return (String? value) {
      final trimmed = value?.trim() ?? '';

      // Check required
      if (required && trimmed.isEmpty) {
        return ValidationResult.invalid(
          requiredMessage ?? 'Phone number is required',
        );
      }

      // Allow empty if not required
      if (trimmed.isEmpty && !required) {
        return const ValidationResult.valid();
      }

      // Remove common formatting characters
      final cleanNumber = trimmed.replaceAll(RegExp(r'[\s\-\(\)\+\.]'), '');

      // Check if it's a valid phone number (at least 7 digits)
      if (cleanNumber.length < 7 || !RegExp(r'^\d+$').hasMatch(cleanNumber)) {
        return ValidationResult.invalid(
          invalidFormatMessage ?? 'Please enter a valid phone number',
        );
      }

      return const ValidationResult.valid();
    };
  }

  /// Validates a URL.
  static Validator url({
    String? requiredMessage,
    String? invalidFormatMessage,
    bool required = false,
    List<String>? allowedSchemes,
  }) {
    return (String? value) {
      final trimmed = value?.trim() ?? '';

      // Check required
      if (required && trimmed.isEmpty) {
        return ValidationResult.invalid(
          requiredMessage ?? 'URL is required',
        );
      }

      // Allow empty if not required
      if (trimmed.isEmpty && !required) {
        return const ValidationResult.valid();
      }

      // Validate URL format
      final uri = Uri.tryParse(trimmed);
      if (uri == null || !uri.hasScheme) {
        return ValidationResult.invalid(
          invalidFormatMessage ?? 'Please enter a valid URL',
        );
      }

      // Check allowed schemes
      if (allowedSchemes != null && !allowedSchemes.contains(uri.scheme)) {
        return ValidationResult.invalid(
          'URL must use one of: ${allowedSchemes.join(", ")}',
        );
      }

      return const ValidationResult.valid();
    };
  }

  /// Combines multiple validators into one.
  /// Returns the first failed validation result, or valid if all pass.
  static Validator combine(List<Validator> validators) {
    return (String? value) {
      for (final validator in validators) {
        final result = validator(value);
        if (result.isInvalid) {
          return result;
        }
      }
      return const ValidationResult.valid();
    };
  }

  /// Creates a custom validator from a validation function.
  static Validator custom(
    bool Function(String? value) isValid, {
    String message = 'Invalid value',
  }) {
    return (String? value) {
      if (isValid(value)) {
        return const ValidationResult.valid();
      }
      return ValidationResult.invalid(message);
    };
  }

  // Helper method to format date for error messages
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Business rule validators that require additional context.
class BusinessValidators {
  const BusinessValidators._();

  /// Validates that a transaction amount doesn't exceed account balance.
  static Validator balanceCheck({
    required double currentBalance,
    String? insufficientFundsMessage,
    bool allowOverdraft = false,
    double overdraftLimit = 0,
  }) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return const ValidationResult.valid();
      }

      final cleanValue = value.trim().replaceAll(',', '');
      final amount = double.tryParse(cleanValue);

      if (amount == null) {
        return const ValidationResult.valid(); // Let amount validator handle format errors
      }

      // For withdrawals (negative amounts), check if sufficient balance
      if (amount < 0 && !allowOverdraft) {
        final withdrawalAmount = amount.abs();
        if (withdrawalAmount > currentBalance) {
          return ValidationResult.invalid(
            insufficientFundsMessage ?? 'Insufficient funds. Available: $currentBalance',
          );
        }
      }

      // Check overdraft limit
      if (allowOverdraft && amount < 0) {
        final newBalance = currentBalance + amount;
        if (newBalance < -overdraftLimit) {
          return ValidationResult.invalid(
            insufficientFundsMessage ?? 'Amount exceeds overdraft limit of $overdraftLimit',
          );
        }
      }

      return const ValidationResult.valid();
    };
  }

  /// Validates that a date is within an accounting period.
  static Validator accountingPeriod({
    required DateTime periodStart,
    required DateTime periodEnd,
    String? outsidePeriodMessage,
  }) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return const ValidationResult.valid();
      }

      final parsedDate = DateTime.tryParse(value.trim());
      if (parsedDate == null) {
        return const ValidationResult.valid(); // Let date validator handle format errors
      }

      final checkDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
      final start = DateTime(periodStart.year, periodStart.month, periodStart.day);
      final end = DateTime(periodEnd.year, periodEnd.month, periodEnd.day);

      if (checkDate.isBefore(start) || checkDate.isAfter(end)) {
        return ValidationResult.invalid(
          outsidePeriodMessage ??
              'Date must be within the accounting period (${ValidationService._formatDate(start)} to ${ValidationService._formatDate(end)})',
        );
      }

      return const ValidationResult.valid();
    };
  }

  /// Validates that a split transaction totals match the parent amount.
  static Validator splitTotal({
    required double parentAmount,
    required List<double> splitAmounts,
    String? mismatchMessage,
  }) {
    return (String? value) {
      final splitsTotal = splitAmounts.fold<double>(0, (sum, amount) => sum + amount);
      final difference = (splitsTotal - parentAmount).abs();

      // Allow small floating point differences
      if (difference > 0.01) {
        return ValidationResult.invalid(
          mismatchMessage ?? 'Split total ($splitsTotal) must equal transaction amount ($parentAmount)',
        );
      }

      return const ValidationResult.valid();
    };
  }

  /// Validates that a budget amount is within limits.
  static Validator budgetLimit({
    required double currentSpent,
    String? exceededMessage,
  }) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return const ValidationResult.valid();
      }

      final budgetAmount = double.tryParse(value.trim().replaceAll(',', ''));
      if (budgetAmount == null) {
        return const ValidationResult.valid();
      }

      if (currentSpent > budgetAmount) {
        return ValidationResult.invalid(
          exceededMessage ?? 'Budget amount ($budgetAmount) is less than current spending ($currentSpent)',
        );
      }

      return const ValidationResult.valid();
    };
  }

  /// Validates that a recurring transaction has valid recurrence settings.
  static Validator recurrence({
    String? invalidIntervalMessage,
    String? invalidEndDateMessage,
  }) {
    return (String? value) {
      // This validator is meant to be used with recurrence configuration
      // The value here would be a JSON string or similar representation
      // For now, we'll return valid as the actual validation would need
      // more context about the recurrence type
      return const ValidationResult.valid();
    };
  }
}
