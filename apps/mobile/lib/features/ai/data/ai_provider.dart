import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai/ai.dart';
import 'package:core/core.dart';
import 'package:database/database.dart';
import '../../categories/data/category_provider.dart';
import '../../transactions/data/transaction_provider.dart';

/// Provider for the AI service.
final aiServiceProvider = Provider<AiService>((ref) {
  // Create Ollama-based AI service with default settings
  // Users can configure the endpoint in settings
  return AiService.ollama(
    baseUrl: 'http://localhost:11434',
    model: 'qwen2.5:3b',
  );
});

/// Provider for AI availability status.
final aiAvailabilityProvider = StreamProvider<bool>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  
  // Initial check
  aiService.checkAvailability();
  
  return aiService.availabilityStream;
});

/// Provider for category suggestions for a transaction.
final categorySuggestionProvider = FutureProvider.family<CategorySuggestion?, String>((ref, transactionId) async {
  final aiService = ref.watch(aiServiceProvider);
  final isAvailable = ref.watch(aiAvailabilityProvider).valueOrNull ?? false;
  
  if (!isAvailable) {
    return null;
  }
  
  // Get transaction
  final db = ref.watch(databaseProvider);
  final transaction = await db.transactionsDao.getTransactionById(transactionId);
  
  if (transaction == null) {
    return null;
  }
  
  // Convert to core Transaction model
  final coreTransaction = Transaction(
    id: transaction.id,
    description: transaction.description,
    notes: transaction.notes,
    postDate: DateTime.fromMillisecondsSinceEpoch(transaction.postDate),
    createdAt: DateTime.fromMillisecondsSinceEpoch(transaction.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(transaction.updatedAt),
  );
  
  // Get available categories
  final categories = await ref.watch(allCategoriesProvider.future);
  
  // Get suggestion
  return await aiService.suggestCategory(
    transaction: coreTransaction,
    availableCategories: categories,
  );
});

/// Provider for batch category suggestions.
final batchCategorySuggestionsProvider = FutureProvider.family<Map<String, CategorySuggestion?>, List<String>>((ref, transactionIds) async {
  final aiService = ref.watch(aiServiceProvider);
  final isAvailable = ref.watch(aiAvailabilityProvider).valueOrNull ?? false;
  
  if (!isAvailable) {
    return {};
  }
  
  final results = <String, CategorySuggestion?>{};
  
  // Process in batches to avoid overwhelming the LLM
  for (final id in transactionIds) {
    final suggestion = await ref.watch(categorySuggestionProvider(id).future);
    results[id] = suggestion;
    
    // Small delay between requests
    await Future.delayed(const Duration(milliseconds: 100));
  }
  
  return results;
});

/// Notifier for applying category suggestions.
class CategorySuggestionApplier extends AsyncNotifier<void> {
  @override
  void build() {}
  
  /// Apply a category suggestion to a transaction.
  Future<void> applySuggestion(String transactionId, String categoryId) async {
    state = const AsyncValue.loading();
    
    try {
      final db = ref.read(databaseProvider);
      
      // Update transaction category
      await db.transactionsDao.updateTransactionCategory(
        transactionId: transactionId,
        categoryId: categoryId,
      );
      
      // Refresh transaction list
      ref.invalidate(transactionsProvider);
      
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  /// Apply multiple suggestions at once.
  Future<void> applyBatchSuggestions(Map<String, String> suggestions) async {
    state = const AsyncValue.loading();
    
    try {
      final db = ref.read(databaseProvider);
      
      for (final entry in suggestions.entries) {
        await db.transactionsDao.updateTransactionCategory(
          transactionId: entry.key,
          categoryId: entry.value,
        );
      }
      
      // Refresh transaction list
      ref.invalidate(transactionsProvider);
      
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final categorySuggestionApplierProvider = AsyncNotifierProvider<CategorySuggestionApplier, void>(
  () => CategorySuggestionApplier(),
);