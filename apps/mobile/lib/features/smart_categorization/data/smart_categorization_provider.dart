import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';
import 'package:ai/ai.dart' as ai;

// ============================================================
// SMART CATEGORIZATION SERVICE
// ============================================================

/// Service for intelligent transaction categorization
class SmartCategorizationService {
  final LocalFinanceDatabase _db;
  final ai.AiService? _aiService;

  SmartCategorizationService(this._db, this._aiService);

  /// Get suggested category based on description and history
  Future<CategorySuggestion?> suggestCategory({
    required String description,
    String? accountId,
    double? amount,
  }) async {
    // First, try AI-based suggestion
    if (_aiService != null && _aiService!.isAvailable) {
      // AI suggestion would go here
      // For now, fall back to history-based
    }

    // History-based suggestion
    return _suggestFromHistory(description, accountId, amount);
  }

  /// Suggest category from transaction history
  Future<CategorySuggestion?> _suggestFromHistory(
    String description,
    String? accountId,
    double? amount,
  ) async {
    // Find similar descriptions in past transactions
    final allTxns = await (db.select(db.transactions)
      ..where((t) => t.description.isNotNull()))
      .get();

    // Simple text matching (could be enhanced with fuzzy matching)
    final similar = allTxns.where((t) {
      if (t.description == null) return false;
      return _calculateSimilarity(description, t.description!) > 0.5;
    }).toList();

    if (similar.isEmpty) return null;

    // Get the most recent similar transaction's splits
    final mostRecent = similar.first;
    final splits = await (db.select(db.splits)
      ..where((s) => s.transactionId.equals(mostRecent.id)))
      .get();

    if (splits.isEmpty) return null;

    // Count category frequency
    final categoryCounts = <String?, int>{};
    for (final split in splits) {
      categoryCounts[split.categoryId] = (categoryCounts[split.categoryId] ?? 0) + 1;
    }

    // Find most frequent category
    String? bestCategoryId;
    int bestCount = 0;
    for (final entry in categoryCounts.entries) {
      if (entry.key != null && entry.value > bestCount) {
        bestCategoryId = entry.key;
        bestCount = entry.value;
      }
    }

    if (bestCategoryId == null) return null;

    // Calculate confidence based on frequency and similarity
    final confidence = (bestCount / splits.length) * _calculateSimilarity(description, mostRecent.description!);

    return CategorySuggestion(
      categoryId: bestCategoryId!,
      confidence: confidence,
      reason: '基于历史记录',
    );
  }

  /// Get suggested account based on amount and history
  Future<AccountSuggestion?> suggestAccount({
    required String description,
    double? amount,
    String? categoryId,
  }) async {
    // Similar logic to category suggestion
    return null; // Placeholder
  }

  /// Calculate text similarity (simple Jaccard similarity)
  double _calculateSimilarity(String a, String b) {
    final wordsA = a.toLowerCase().split(' ').toSet();
    final wordsB = b.toLowerCase().split(' ').toSet();

    if (wordsA.isEmpty || wordsB.isEmpty) return 0;

    final intersection = wordsA.intersection(wordsB);
    final union = wordsA.union(wordsB);

    return intersection.length / union.length;
  }

  /// Learn from user corrections
  Future<void> learnFromCorrection({
    required String transactionId,
    required String oldCategoryId,
    required String newCategoryId,
  }) async {
    // Store correction for future improvement
    // This could update a learning model or adjust weights
  }
}

/// Category suggestion result
class CategorySuggestion {
  final String categoryId;
  final double confidence;
  final String reason;

  const CategorySuggestion({
    required this.categoryId,
    required this.confidence,
    required this.reason,
  });
}

/// Account suggestion result
class AccountSuggestion {
  final String accountId;
  final double confidence;
  final String reason;

  const AccountSuggestion({
    required this.accountId,
    required this.confidence,
    required this.reason,
  });
}

// ============================================================
// PROVIDERS
// ============================================================

final smartCategorizationServiceProvider = Provider<SmartCategorizationService>((ref) {
  final db = ref.watch(databaseProvider);
  // AI service is optional
  return SmartCategorizationService(db, null);
});

/// Provider for category suggestions based on description
final categorySuggestionForDescriptionProvider =
    FutureProvider.family<CategorySuggestion?, String>((ref, description) async {
  final service = ref.watch(smartCategorizationServiceProvider);
  return service.suggestCategory(description: description);
});
