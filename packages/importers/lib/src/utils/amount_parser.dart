import 'package:intl/intl.dart';

/// Parses amounts from Chinese financial institution exports.
///
/// Supports various amount formats:
/// - Standard: 1234.56, -1234.56
/// - Chinese: ¥1234.56, +¥1234.56, -¥1234.56
/// - With comma: 1,234.56
/// - Chinese large: 1.23万
/// - Parentheses negative: (1234.56)
class AmountParser {
  /// Chinese currency symbols.
  static const _currencySymbols = ['¥', '￥', 'RMB', 'CNY', '元'];

  /// Chinese large number units.
  static const _largeUnits = {
    '万': 10000.0,
    '萬': 10000.0,
    '亿': 100000000.0,
    '億': 100000000.0,
  };

  /// Parse an amount string to double.
  ///
  /// Returns null if parsing fails.
  static double? parse(String? amountString) {
    if (amountString == null || amountString.trim().isEmpty) return null;

    var trimmed = amountString.trim();

    // Handle empty or dash (no amount)
    if (trimmed.isEmpty || trimmed == '-' || trimmed == '--') {
      return null;
    }

    // Remove currency symbols
    for (final symbol in _currencySymbols) {
      trimmed = trimmed.replaceAll(symbol, '');
    }

    // Remove spaces
    trimmed = trimmed.replaceAll(' ', '');

    // Handle parentheses negative: (1234.56) -> -1234.56
    if (trimmed.startsWith('(') && trimmed.endsWith(')')) {
      trimmed = '-${trimmed.substring(1, trimmed.length - 1)}';
    }

    // Handle +/- prefix
    final isNegative = trimmed.startsWith('-') || trimmed.startsWith('－');
    if (trimmed.startsWith('+') || trimmed.startsWith('－') || trimmed.startsWith('-')) {
      trimmed = trimmed.substring(1);
    }

    // Remove commas
    trimmed = trimmed.replaceAll(',', '');

    // Handle Chinese large units (万, 亿)
    double? multiplier;
    for (final entry in _largeUnits.entries) {
      if (trimmed.contains(entry.key)) {
        multiplier = entry.value;
        trimmed = trimmed.replaceAll(entry.key, '');
        break;
      }
    }

    // Parse the number
    double? amount;
    try {
      // Try parsing as double
      amount = double.tryParse(trimmed);

      // If that fails, try parsing with NumberFormat
      if (amount == null) {
        try {
          amount = NumberFormat.decimalPattern().parse(trimmed).toDouble();
        } catch (_) {
          // Try parsing with Chinese format
          try {
            amount = NumberFormat.decimalPattern('zh_CN').parse(trimmed).toDouble();
          } catch (_) {
            return null;
          }
        }
      }
    } catch (_) {
      return null;
    }

    // Apply multiplier for large units
    if (multiplier != null) {
      amount = amount * multiplier;
    }

    // Apply sign
    if (isNegative && amount != null) {
      amount = -amount;
    }

    return amount;
  }

  /// Parse an amount and determine if it's income or expense.
  ///
  /// Returns a tuple of (amount, isIncome).
  /// - Positive amounts with '+' prefix are income
  /// - Negative amounts with '-' prefix are expense
  /// - Amounts without sign are determined by context
  static ({double amount, bool isIncome})? parseWithType(String? amountString) {
    if (amountString == null || amountString.trim().isEmpty) return null;

    final trimmed = amountString.trim();

    // Check for explicit income/expense markers
    final hasIncomePrefix = trimmed.startsWith('+') ||
        trimmed.contains('收入') ||
        trimmed.contains('退款') ||
        trimmed.contains('转账-收到');

    final hasExpensePrefix = trimmed.startsWith('-') ||
        trimmed.contains('支出') ||
        trimmed.contains('转账-转出');

    final amount = parse(trimmed);
    if (amount == null) return null;

    // Determine income/expense
    final isIncome = hasIncomePrefix || (!hasExpensePrefix && amount > 0);

    return (amount: amount.abs(), isIncome: isIncome);
  }

  /// Format an amount to a standard string.
  static String format(double amount, {bool showSign = false, bool showCurrency = true}) {
    final buffer = StringBuffer();

    if (showCurrency) {
      buffer.write('¥');
    }

    if (showSign) {
      if (amount > 0) {
        buffer.write('+');
      } else if (amount < 0) {
        buffer.write('-');
      }
    }

    buffer.write(NumberFormat('#,##0.00').format(amount.abs()));

    return buffer.toString();
  }

  /// Format an amount with Chinese large unit (万).
  static String formatChinese(double amount, {bool showCurrency = true}) {
    final buffer = StringBuffer();

    if (showCurrency) {
      buffer.write('¥');
    }

    if (amount.abs() >= 10000) {
      final wan = amount / 10000;
      buffer.write('${wan.toStringAsFixed(2)}万');
    } else {
      buffer.write(NumberFormat('#,##0.00').format(amount));
    }

    return buffer.toString();
  }

  /// Check if an amount string represents income.
  static bool isIncome(String amountString) {
    final trimmed = amountString.trim();
    return trimmed.startsWith('+') ||
        trimmed.contains('收入') ||
        trimmed.contains('退款') ||
        trimmed.contains('转账-收到');
  }

  /// Check if an amount string represents expense.
  static bool isExpense(String amountString) {
    final trimmed = amountString.trim();
    return trimmed.startsWith('-') ||
        trimmed.contains('支出') ||
        trimmed.contains('转账-转出');
  }
}