import 'package:equatable/equatable.dart';
import 'package:core/core.dart';

/// Suggestion for categorizing a transaction.
class CategorySuggestion extends Equatable {
  /// The suggested category ID.
  final String categoryId;

  /// Confidence score between 0.0 and 1.0.
  final double confidence;

  /// Optional reasoning for the suggestion.
  final String? reasoning;

  const CategorySuggestion({
    required this.categoryId,
    required this.confidence,
    this.reasoning,
  });

  @override
  List<Object?> get props => [categoryId, confidence, reasoning];
}

/// Interface for LLM providers.
///
/// Implementations can connect to local LLM services like Ollama
/// or provide mock/stub implementations for testing.
abstract class LlmProvider {
  /// Display name of this provider.
  String get name;

  /// Check if the LLM service is available.
  ///
  /// Returns true if the service is running and ready to accept requests.
  Future<bool> checkAvailability();

  /// Suggest a category for a transaction.
  ///
  /// Returns null if the provider is unavailable or cannot determine
  /// a suitable category.
  Future<CategorySuggestion?> suggestCategory({
    required Transaction transaction,
    required List<Category> availableCategories,
  });

  /// Dispose of any resources held by this provider.
  Future<void> dispose() async {}
}
