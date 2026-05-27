import 'dart:async';
import 'package:logging/logging.dart';
import 'package:core/core.dart';
import 'categorization/categorizer.dart';
import 'providers/llm_provider.dart';
import 'providers/ollama_provider.dart';
import 'models/spending_insights.dart';

/// Main AI service for the finance application.
///
/// Provides AI-powered features with graceful degradation:
/// - If LLM is unavailable, features return null/false gracefully
/// - No crashes or blocking errors when AI is not accessible
/// - Designed for local-first operation with optional AI enhancement
class AiService {
  final Logger _log = Logger('AiService');

  /// The LLM provider to use for AI operations.
  final LlmProvider _provider;

  /// Transaction categorization utilities.
  final Categorizer categorizer;

  /// Whether the LLM service is currently available.
  ///
  /// This is cached from the last [checkAvailability] call.
  /// Initially false until first check completes.
  bool _isAvailable = false;

  /// Whether an availability check is in progress.
  bool _isChecking = false;

  /// Stream controller for availability changes.
  final _availabilityController = StreamController<bool>.broadcast();

  AiService({
    required LlmProvider provider,
    Categorizer? categorizer,
  })  : _provider = provider,
        categorizer = categorizer ?? Categorizer();

  /// Factory constructor for creating an Ollama-based AI service.
  factory AiService.ollama({
    String baseUrl = 'http://localhost:11434',
    String model = 'qwen2.5:3b',
  }) {
    return AiService(
      provider: OllamaProvider(
        baseUrl: baseUrl,
        model: model,
      ),
    );
  }

  /// Whether the LLM service is available.
  bool get isAvailable => _isAvailable;

  /// Stream of availability status changes.
  Stream<bool> get availabilityStream => _availabilityController.stream;

  /// The underlying LLM provider.
  LlmProvider get provider => _provider;

  /// Check if the LLM service is available.
  ///
  /// Updates [isAvailable] and notifies listeners via [availabilityStream].
  /// Returns the current availability status.
  Future<bool> checkAvailability() async {
    if (_isChecking) {
      // Wait for existing check to complete
      await Future.delayed(const Duration(milliseconds: 100));
      return _isAvailable;
    }

    _isChecking = true;
    try {
      _log.info('Checking LLM availability for ${_provider.name}...');

      final available = await _provider.checkAvailability();

      if (_isAvailable != available) {
        _isAvailable = available;
        _availabilityController.add(available);
        _log.info('LLM availability changed: $available');
      }

      return _isAvailable;
    } catch (e, st) {
      _log.warning('Error checking LLM availability', e, st);

      if (_isAvailable) {
        _isAvailable = false;
        _availabilityController.add(false);
      }

      return false;
    } finally {
      _isChecking = false;
    }
  }

  /// Suggest a category for a transaction.
  ///
  /// Returns null if:
  /// - LLM is not available
  /// - Transaction has no description
  /// - LLM cannot determine a suitable category
  ///
  /// This method implements graceful degradation - it will never
  /// throw an exception, always returning null on failure.
  Future<CategorySuggestion?> suggestCategory({
    required Transaction transaction,
    required List<Category> availableCategories,
  }) async {
    if (!_isAvailable) {
      _log.fine('LLM not available, returning null for category suggestion');
      return null;
    }

    if (transaction.description == null || transaction.description!.isEmpty) {
      _log.fine('Transaction has no description, cannot suggest category');
      return null;
    }

    if (availableCategories.isEmpty) {
      _log.fine('No categories available for suggestion');
      return null;
    }

    try {
      _log.fine(
          'Requesting category suggestion for: ${categorizer.cleanDescription(transaction.description)}');

      final suggestion = await _provider.suggestCategory(
        transaction: transaction,
        availableCategories: availableCategories,
      );

      if (suggestion != null) {
        _log.fine(
            'Got category suggestion: ${suggestion.categoryId} (confidence: ${suggestion.confidence})');
      }

      return suggestion;
    } catch (e, st) {
      _log.warning('Error getting category suggestion', e, st);
      return null;
    }
  }

  /// Analyze spending patterns and provide insights.
  ///
  /// Returns null if LLM is not available or analysis fails.
  Future<SpendingInsights?> analyzeSpendingPatterns({
    required List<Transaction> transactions,
    required List<Category> categories,
  }) async {
    if (!_isAvailable) {
      _log.fine('LLM not available for spending analysis');
      return null;
    }

    if (transactions.isEmpty) {
      _log.fine('No transactions to analyze');
      return null;
    }

    try {
      // Try to use Ollama provider's extended methods
      if (_provider is OllamaProvider) {
        return await (_provider as OllamaProvider).analyzeSpendingPatterns(
          transactions: transactions,
          categories: categories,
        );
      }

      // Fallback: return basic insights without LLM
      return _generateBasicInsights(transactions, categories);
    } catch (e, st) {
      _log.warning('Error analyzing spending patterns', e, st);
      return null;
    }
  }

  /// Generate basic insights without LLM.
  SpendingInsights _generateBasicInsights(
    List<Transaction> transactions,
    List<Category> categories,
  ) {
    final byCategory = <String, double>{};
    for (final t in transactions) {
      if (t.categoryId != null) {
        // Parse amount from notes if available
        final amount = double.tryParse(t.notes ?? '0') ?? 0;
        byCategory[t.categoryId!] = (byCategory[t.categoryId!] ?? 0) + amount.abs();
      }
    }

    final sortedCategories = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topCategories = sortedCategories.take(5).map((e) {
      final cat = categories.firstWhere((c) => c.id == e.key, orElse: () => Category(id: e.key, name: '未知', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      return '${cat.name}: ${e.value.toStringAsFixed(2)}';
    }).toList();

    return SpendingInsights(
      topSpendingCategories: topCategories,
      summary: '分析了 ${transactions.length} 笔交易',
      confidence: 0.7,
    );
  }

  /// Dispose of resources.
  Future<void> dispose() async {
    await _availabilityController.close();
    await _provider.dispose();
  }
}
