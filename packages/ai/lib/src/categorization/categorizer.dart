import 'package:core/core.dart';
import '../providers/llm_provider.dart';

/// Transaction categorization service.
///
/// Provides utilities for cleaning transaction descriptions
/// and preparing data for LLM-based categorization.
class Categorizer {
  /// Common patterns to remove from transaction descriptions.
  static final List<RegExp> _noisePatterns = [
    // Transaction IDs and reference numbers
    RegExp(r'[A-Z]{2,4}\d{10,}', caseSensitive: false),
    RegExp(r'交易号[：:]\s*\d+', caseSensitive: false),
    RegExp(r'订单号[：:]\s*\d+', caseSensitive: false),
    // Date/time stamps
    RegExp(r'\d{4}[-/]\d{1,2}[-/]\d{1,2}\s*\d{1,2}:\d{1,2}(:\d{1,2})?'),
    // Card number masks
    RegExp(r'尾号\d{4}'),
    RegExp(r'\*{4,}\d{4}'),
    // Common prefixes
    RegExp(r'^(支付宝|微信支付|财付通|银联)[：:-]?\s*', caseSensitive: false),
    // Store location info
    RegExp(r'\([^)]*店[^)]*\)'),
    RegExp(r'\([^)]*分店[^)]*\)'),
    // Extra whitespace
    RegExp(r'\s+'),
  ];

  /// Clean a transaction description for better categorization.
  ///
  /// Removes noise like transaction IDs, timestamps, and common prefixes
  /// that don't help with categorization.
  String cleanDescription(String? description) {
    if (description == null || description.isEmpty) {
      return '';
    }

    var cleaned = description.trim();

    for (final pattern in _noisePatterns) {
      cleaned = cleaned.replaceAll(pattern, ' ');
    }

    // Collapse multiple spaces and trim
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned;
  }

  /// Extract keywords from a transaction description.
  ///
  /// Returns a list of meaningful words that could help with categorization.
  List<String> extractKeywords(String? description) {
    final cleaned = cleanDescription(description);
    if (cleaned.isEmpty) {
      return [];
    }

    // Split by spaces and filter short words
    final words = cleaned
        .split(' ')
        .where((w) => w.length >= 2)
        .where((w) => !RegExp(r'^[\d\-\*]+$').hasMatch(w))
        .toList();

    return words;
  }

  /// Build a categorization prompt for the LLM.
  ///
  /// Creates a formatted prompt with transaction details and
  /// available categories for the LLM to choose from.
  String buildCategorizationPrompt({
    required Transaction transaction,
    required List<Category> availableCategories,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('请根据以下交易信息，从给定的分类中选择最合适的分类。');
    buffer.writeln();
    buffer.writeln('交易描述: ${cleanDescription(transaction.description)}');
    buffer.writeln('交易金额: ${transaction.notes ?? "未知"}');
    buffer.writeln('交易日期: ${transaction.postDate}');
    buffer.writeln();

    buffer.writeln('可选分类:');
    for (final category in availableCategories) {
      final incomeLabel = category.isIncome ? '[收入]' : '[支出]';
      buffer.writeln('- ${category.id}: ${category.name} $incomeLabel');
    }

    buffer.writeln();
    buffer.writeln('请返回分类ID和置信度(0-1)，格式: {"categoryId": "xxx", "confidence": 0.8}');

    return buffer.toString();
  }
}
