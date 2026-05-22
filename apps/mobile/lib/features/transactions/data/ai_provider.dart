import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai/ai.dart';
import 'package:core/core.dart' hide Category;
import 'package:core/core.dart' as core;
import 'package:finance_app/features/categories/data/category_provider.dart';
import 'package:database/database.dart' as db;

/// Provider for the AI service instance.
///
/// Uses MockLlmProvider by default for graceful degradation.
/// In production, this would be replaced with Ollama or llama.cpp provider.
final aiServiceProvider = Provider<AiService>((ref) {
  final service = AiService(
    provider: MockLlmProvider(simulateAvailable: true),
  );
  
  // Check availability on initialization
  ref.onDispose(() {
    service.dispose();
  });
  
  // Async availability check
  Future.microtask(() => service.checkAvailability());
  
  return service;
});

/// Provider for AI category suggestions based on description.
///
/// Returns null when:
/// - AI service is unavailable
/// - Description is empty or too short
/// - AI cannot determine a suitable category
///
/// Features:
/// - Minimum 3 characters before requesting suggestion
/// - Graceful degradation when AI unavailable
final categorySuggestionProvider = FutureProvider.family<CategorySuggestion?, String>((ref, description) async {
  // Skip if description is too short
  if (description.trim().length < 3) {
    return null;
  }
  
  final ai = ref.watch(aiServiceProvider);
  
  // Check if AI is available
  if (!ai.isAvailable) {
    return null;
  }
  
  // Get all categories
  final categoriesAsync = ref.watch(categoriesProvider);
  
  return categoriesAsync.when(
    data: (categories) async {
      if (categories.isEmpty) {
        return null;
      }
      
      // Create a temporary transaction for the AI to analyze
      final tempTransaction = Transaction(
        description: description,
        postDate: DateTime.now(),
        commodityId: 'CNY',
      );
      
      // Convert database Category to core Category for AI service
      final coreCategories = categories.map((c) => core.Category(
        id: c.id,
        name: c.name,
        parentId: c.parentId,
        icon: c.icon,
        color: c.color,
        isIncome: c.isIncome,
        sortOrder: c.sortOrder,
        createdAt: DateTime.fromMillisecondsSinceEpoch(c.createdAt),
      )).toList();
      
      try {
        return await ai.suggestCategory(
          transaction: tempTransaction,
          availableCategories: coreCategories,
        );
      } catch (e) {
        // Graceful degradation - return null on any error
        return null;
      }
    },
    loading: () => null,
    error: (_, __) => null,
  );
});
