import 'package:intl/intl.dart';

/// Parses dates from Chinese financial institution exports.
///
/// Supports various date formats:
/// - Standard: 2026-05-19, 2026/05/19
/// - Chinese: 2026年5月19日
/// - Compact: 20260519
/// - With time: 2026-05-19 10:30:00
/// - Relative: 今天, 昨天, 前天
class DateParser {
  /// Common date formats in Chinese financial exports.
  static final List<DateFormat> _formats = [
    // Standard formats
    DateFormat('yyyy-MM-dd'),
    DateFormat('yyyy/MM/dd'),
    DateFormat('yyyy.MM.dd'),
    DateFormat('yyyy年MM月dd日'),
    DateFormat('yyyy年M月d日'),

    // With time
    DateFormat('yyyy-MM-dd HH:mm:ss'),
    DateFormat('yyyy/MM/dd HH:mm:ss'),
    DateFormat('yyyy.MM.dd HH:mm:ss'),
    DateFormat('yyyy年MM月dd日 HH:mm:ss'),
    DateFormat('yyyy年M月d日 H:mm:ss'),

    // Compact
    DateFormat('yyyyMMdd'),
    DateFormat('yyyyMMddHHmmss'),

    // Short year
    DateFormat('yy-MM-dd'),
    DateFormat('yy/MM/dd'),

    // Time only (assumes today)
    DateFormat('HH:mm:ss'),
    DateFormat('HH:mm'),
  ];

  /// Parse a date string to DateTime.
  ///
  /// Returns null if parsing fails.
  static DateTime? parse(String? dateString) {
    if (dateString == null || dateString.trim().isEmpty) return null;

    final trimmed = dateString.trim();

    // Handle relative dates
    final relative = _parseRelativeDate(trimmed);
    if (relative != null) return relative;

    // Try each format
    for (final format in _formats) {
      try {
        return format.parse(trimmed);
      } catch (_) {
        continue;
      }
    }

    // Try custom parsing
    return _parseCustom(trimmed);
  }

  /// Parse a date string with a specific format.
  static DateTime? parseWithFormat(String? dateString, String format) {
    if (dateString == null || dateString.trim().isEmpty) return null;

    try {
      return DateFormat(format).parse(dateString.trim());
    } catch (_) {
      return null;
    }
  }

  /// Parse relative date strings.
  static DateTime? _parseRelativeDate(String dateString) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (dateString) {
      case '今天':
      case '今日':
        return today;
      case '昨天':
      case '昨日':
        return today.subtract(const Duration(days: 1));
      case '前天':
        return today.subtract(const Duration(days: 2));
      case '大前天':
        return today.subtract(const Duration(days: 3));
      default:
        // Check for "X天前" pattern
        final daysAgoMatch = RegExp(r'(\d+)天前').firstMatch(dateString);
        if (daysAgoMatch != null) {
          final days = int.tryParse(daysAgoMatch.group(1) ?? '');
          if (days != null) {
            return today.subtract(Duration(days: days));
          }
        }

        // Check for "X小时前" pattern
        final hoursAgoMatch = RegExp(r'(\d+)小时前').firstMatch(dateString);
        if (hoursAgoMatch != null) {
          final hours = int.tryParse(hoursAgoMatch.group(1) ?? '');
          if (hours != null) {
            return now.subtract(Duration(hours: hours));
          }
        }

        // Check for "X分钟前" pattern
        final minutesAgoMatch = RegExp(r'(\d+)分钟前').firstMatch(dateString);
        if (minutesAgoMatch != null) {
          final minutes = int.tryParse(minutesAgoMatch.group(1) ?? '');
          if (minutes != null) {
            return now.subtract(Duration(minutes: minutes));
          }
        }

        return null;
    }
  }

  /// Custom parsing for unusual formats.
  static DateTime? _parseCustom(String dateString) {
    // Try to extract date components
    final yearMatch = RegExp(r'(\d{4})').firstMatch(dateString);
    final monthMatch = RegExp(r'[年/-](\d{1,2})[月/-]').firstMatch(dateString);
    final dayMatch = RegExp(r'[月/-](\d{1,2})').firstMatch(dateString);

    if (yearMatch != null && monthMatch != null && dayMatch != null) {
      final year = int.tryParse(yearMatch.group(1) ?? '');
      final month = int.tryParse(monthMatch.group(1) ?? '');
      final day = int.tryParse(dayMatch.group(1) ?? '');

      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }

    // Try to parse time only (assume today)
    final timeMatch = RegExp(r'(\d{1,2}):(\d{2})(?::(\d{2}))?').firstMatch(dateString);
    if (timeMatch != null) {
      final hour = int.tryParse(timeMatch.group(1) ?? '');
      final minute = int.tryParse(timeMatch.group(2) ?? '');
      final second = int.tryParse(timeMatch.group(3) ?? '0');

      if (hour != null && minute != null) {
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, hour, minute, second ?? 0);
      }
    }

    return null;
  }

  /// Format a DateTime to a standard string.
  static String format(DateTime date, {String format = 'yyyy-MM-dd'}) {
    return DateFormat(format).format(date);
  }

  /// Format a DateTime to Chinese format.
  static String formatChinese(DateTime date) {
    return DateFormat('yyyy年MM月dd日').format(date);
  }

  /// Format a DateTime with time.
  static String formatWithTime(DateTime date) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
  }

  /// Check if a date string is a relative date.
  static bool isRelativeDate(String dateString) {
    const relativePatterns = [
      '今天', '今日', '昨天', '昨日', '前天', '大前天',
    ];

    if (relativePatterns.contains(dateString.trim())) {
      return true;
    }

    // Check for "X天前", "X小时前", "X分钟前" patterns
    return RegExp(r'\d+(天|小时|分钟)前').hasMatch(dateString);
  }
}