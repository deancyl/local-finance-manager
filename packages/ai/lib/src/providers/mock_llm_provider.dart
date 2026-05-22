import 'package:core/core.dart';
import 'llm_provider.dart';

/// Mock LLM provider for testing and development.
///
/// Always returns false for availability and null for suggestions,
/// simulating a scenario where no LLM service is available.
/// This allows testing graceful degradation behavior.
class MockLlmProvider implements LlmProvider {
  @override
  String get name => 'Mock LLM Provider';

  /// Whether to simulate availability.
  ///
  /// Defaults to false for testing graceful degradation.
  final bool simulateAvailable;

  /// Optional pre-configured suggestions for testing.
  ///
  /// Map of transaction description hash to category suggestion.
  final Map<String, CategorySuggestion> _presetSuggestions;

  MockLlmProvider({
    this.simulateAvailable = false,
    Map<String, CategorySuggestion>? presetSuggestions,
  }) : _presetSuggestions = presetSuggestions ?? {};

  @override
  Future<bool> checkAvailability() async {
    // Simulate async check
    await Future.delayed(const Duration(milliseconds: 10));
    return simulateAvailable;
  }

  @override
  Future<CategorySuggestion?> suggestCategory({
    required Transaction transaction,
    required List<Category> availableCategories,
  }) async {
    // Simulate async processing
    await Future.delayed(const Duration(milliseconds: 10));

    if (!simulateAvailable) {
      return null;
    }

    // Check for preset suggestions based on description
    final description = transaction.description?.toLowerCase() ?? '';
    if (_presetSuggestions.containsKey(description)) {
      return _presetSuggestions[description];
    }

    // Return null when no preset is configured
    return null;
  }

  @override
  Future<void> dispose() async {
    // No resources to dispose
  }
}
