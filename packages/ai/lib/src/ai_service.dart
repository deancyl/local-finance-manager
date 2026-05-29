import 'dart:async';
import 'dart:math';
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
    // Note: Transaction model doesn't have categoryId directly.
    // Categories are determined through Split entries linked to Accounts.
    // For basic insights, we analyze transaction amounts without category breakdown.
    double totalAmount = 0;
    for (final t in transactions) {
      final amount = double.tryParse(t.notes ?? '0') ?? 0;
      totalAmount += amount.abs();
    }

    return SpendingInsights(
      topSpendingCategories: ['总计: ${totalAmount.toStringAsFixed(2)}'],
      summary: '分析了 ${transactions.length} 笔交易',
      confidence: 0.7,
    );
  }

  /// Generate budget recommendations based on spending history.
  Future<List<BudgetRecommendation>> generateBudgetRecommendations({
    required List<Transaction> transactions,
    required List<Category> categories,
    required Map<String, double> currentBudgets,
  }) async {
    if (transactions.isEmpty) return [];
    try {
      if (_provider is OllamaProvider) {
        return await (_provider as OllamaProvider).generateBudgetRecommendations(
          transactions: transactions,
          categories: categories,
          currentBudgets: currentBudgets,
        );
      }
      return _generateBasicBudgetRecommendations(transactions, categories, currentBudgets);
    } catch (e, st) {
      _log.warning('Error generating budget recommendations', e, st);
      return _generateBasicBudgetRecommendations(transactions, categories, currentBudgets);
    }
  }

  /// Detect anomalies in transactions.
  Future<List<TransactionAnomaly>> detectAnomalies({
    required List<Transaction> transactions,
    required List<Category> categories,
  }) async {
    if (transactions.isEmpty) return [];
    try {
      if (_provider is OllamaProvider) {
        return await (_provider as OllamaProvider).detectAnomalies(
          transactions: transactions,
          categories: categories,
        );
      }
      return _detectBasicAnomalies(transactions);
    } catch (e, st) {
      _log.warning('Error detecting anomalies', e, st);
      return _detectBasicAnomalies(transactions);
    }
  }

  /// Generate basic budget recommendations without LLM.
  List<BudgetRecommendation> _generateBasicBudgetRecommendations(
    List<Transaction> transactions,
    List<Category> categories,
    Map<String, double> currentBudgets,
  ) {
    // Note: Transaction model doesn't have categoryId directly.
    // Categories are determined through Split entries linked to Accounts.
    // For basic recommendations, we return a simple overall budget suggestion.
    double totalSpending = 0;
    for (final t in transactions) {
      final amount = double.tryParse(t.notes ?? '0') ?? 0;
      totalSpending += amount.abs();
    }

    return [
      BudgetRecommendation(
        categoryId: 'overall',
        categoryName: '总体预算',
        recommendedAmount: totalSpending * 1.2,
        currentSpending: totalSpending,
        reasoning: '基于历史消费数据分析',
        priority: 3,
      ),
    ];
  }

  /// Detect basic anomalies without LLM.
  List<TransactionAnomaly> _detectBasicAnomalies(List<Transaction> transactions) {
    final anomalies = <TransactionAnomaly>[];
    final amounts = transactions.map((t) => double.tryParse(t.notes ?? '0') ?? 0).where((a) => a > 0).toList();
    if (amounts.isEmpty) return [];
    
    final mean = amounts.reduce((a, b) => a + b) / amounts.length;
    final variance = amounts.map((a) => (a - mean) * (a - mean)).reduce((a, b) => a + b) / amounts.length;
    final stdDev = variance > 0 ? sqrt(variance) : 0;

    for (final t in transactions) {
      final amount = double.tryParse(t.notes ?? '0') ?? 0;
      if (amount > 0 && stdDev > 0) {
        final zScore = (amount - mean).abs() / stdDev;
        if (zScore > 2) {
          anomalies.add(TransactionAnomaly(
            transactionId: t.id,
            type: AnomalyType.unusualAmount,
            severity: zScore > 3 ? 5 : 3,
            description: '交易金额偏离平均值',
            suggestedAction: '请核实此交易',
          ));
        }
      }
    }
    return anomalies;
  }

  /// Dispose of resources.
  Future<void> dispose() async {
    await _availabilityController.close();
    await _provider.dispose();
  }
}
