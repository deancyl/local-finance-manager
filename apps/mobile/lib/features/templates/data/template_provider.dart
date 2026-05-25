import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

// ============================================================
// MODELS
// ============================================================

/// Split template data
class SplitTemplateData {
  final String accountId;
  final String? categoryId;
  final double amount; // Can be negative for credit
  final String? memo;

  const SplitTemplateData({
    required this.accountId,
    this.categoryId,
    required this.amount,
    this.memo,
  });

  Map<String, dynamic> toJson() => {
    'accountId': accountId,
    'categoryId': categoryId,
    'amount': amount,
    'memo': memo,
  };

  factory SplitTemplateData.fromJson(Map<String, dynamic> json) {
    return SplitTemplateData(
      accountId: json['accountId'] as String,
      categoryId: json['categoryId'] as String?,
      amount: (json['amount'] as num).toDouble(),
      memo: json['memo'] as String?,
    );
  }
}

/// Template display model
class TemplateModel {
  final String id;
  final String name;
  final String? description;
  final String? category;
  final String currencyId;
  final String? defaultTxnDescription;
  final String? defaultNotes;
  final List<SplitTemplateData> splits;
  final int useCount;
  final DateTime? lastUsedAt;
  final bool isFavorite;
  final int sortOrder;
  final bool isActive;

  const TemplateModel({
    required this.id,
    required this.name,
    this.description,
    this.category,
    required this.currencyId,
    this.defaultTxnDescription,
    this.defaultNotes,
    required this.splits,
    this.useCount = 0,
    this.lastUsedAt,
    this.isFavorite = false,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory TemplateModel.fromDb(TransactionTemplate t) {
    final splitsData = jsonDecode(t.splitTemplates) as List;
    final splits = splitsData
        .map((s) => SplitTemplateData.fromJson(s as Map<String, dynamic>))
        .toList();

    return TemplateModel(
      id: t.id,
      name: t.name,
      description: t.description,
      category: t.category,
      currencyId: t.currencyId,
      defaultTxnDescription: t.defaultTxnDescription,
      defaultNotes: t.defaultNotes,
      splits: splits,
      useCount: t.useCount,
      lastUsedAt: t.lastUsedAt,
      isFavorite: t.isFavorite,
      sortOrder: t.sortOrder,
      isActive: t.isActive,
    );
  }
}

// ============================================================
// PROVIDERS
// ============================================================

/// Provider for all templates
final templatesProvider = FutureProvider<List<TemplateModel>>((ref) async {
  final db = ref.watch(databaseProvider);
  final templates = await db.transactionTemplatesDao.getAll();
  return templates.map(TemplateModel.fromDb).toList();
});

/// Provider for favorite templates
final favoriteTemplatesProvider = FutureProvider<List<TemplateModel>>((ref) async {
  final db = ref.watch(databaseProvider);
  final templates = await db.transactionTemplatesDao.getFavorites();
  return templates.map(TemplateModel.fromDb).toList();
});

/// Provider for recent templates
final recentTemplatesProvider = FutureProvider<List<TemplateModel>>((ref) async {
  final db = ref.watch(databaseProvider);
  final templates = await db.transactionTemplatesDao.getRecent();
  return templates.map(TemplateModel.fromDb).toList();
});

/// Provider for templates by category
final templatesByCategoryProvider = FutureProvider.family<List<TemplateModel>, String>((ref, category) async {
  final db = ref.watch(databaseProvider);
  final templates = await db.transactionTemplatesDao.getByCategory(category);
  return templates.map(TemplateModel.fromDb).toList();
});

/// Provider for template categories
final templateCategoriesProvider = FutureProvider<List<String>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.transactionTemplatesDao.getCategories();
});

/// Notifier for template operations
class TemplateNotifier extends StateNotifier<AsyncValue<void>> {
  final LocalFinanceDatabase _db;
  final Ref _ref;

  TemplateNotifier(this._db, this._ref) : super(const AsyncValue.data(null));

  /// Create a new template
  Future<String?> createTemplate({
    required String name,
    String? description,
    String? category,
    required String currencyId,
    String? defaultTxnDescription,
    String? defaultNotes,
    required List<SplitTemplateData> splits,
    bool isFavorite = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      final id = const Uuid().v4();
      final now = DateTime.now();

      await _db.transactionTemplatesDao.insert(
        TransactionTemplatesCompanion.insert(
          id: id,
          name: name,
          description: drift.Value(description),
          category: drift.Value(category),
          currencyId: currencyId,
          defaultTxnDescription: drift.Value(defaultTxnDescription),
          defaultNotes: drift.Value(defaultNotes),
          splitTemplates: jsonEncode(splits.map((s) => s.toJson()).toList()),
          isFavorite: drift.Value(isFavorite),
          createdAt: now,
          updatedAt: now,
        ),
      );

      _ref.invalidate(templatesProvider);
      _ref.invalidate(favoriteTemplatesProvider);

      state = const AsyncValue.data(null);
      return id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Update a template
  Future<void> updateTemplate(TemplateModel template) async {
    state = const AsyncValue.loading();
    try {
      await _db.transactionTemplatesDao.updateTemplate(
        TransactionTemplatesCompanion(
          id: drift.Value(template.id),
          name: drift.Value(template.name),
          description: drift.Value(template.description),
          category: drift.Value(template.category),
          currencyId: drift.Value(template.currencyId),
          defaultTxnDescription: drift.Value(template.defaultTxnDescription),
          defaultNotes: drift.Value(template.defaultNotes),
          splitTemplates: drift.Value(
            jsonEncode(template.splits.map((s) => s.toJson()).toList()),
          ),
          isFavorite: drift.Value(template.isFavorite),
          sortOrder: drift.Value(template.sortOrder),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );

      _ref.invalidate(templatesProvider);
      _ref.invalidate(favoriteTemplatesProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String id) async {
    await _db.transactionTemplatesDao.toggleFavorite(id);
    _ref.invalidate(templatesProvider);
    _ref.invalidate(favoriteTemplatesProvider);
  }

  /// Record template usage
  Future<void> recordUsage(String id) async {
    await _db.transactionTemplatesDao.recordUsage(id);
    _ref.invalidate(templatesProvider);
    _ref.invalidate(recentTemplatesProvider);
  }

  /// Delete a template
  Future<void> deleteTemplate(String id) async {
    await _db.transactionTemplatesDao.deleteTemplate(id);
    _ref.invalidate(templatesProvider);
    _ref.invalidate(favoriteTemplatesProvider);
  }

  /// Deactivate a template
  Future<void> deactivateTemplate(String id) async {
    await _db.transactionTemplatesDao.deactivate(id);
    _ref.invalidate(templatesProvider);
  }
}

final templateNotifierProvider =
    StateNotifierProvider<TemplateNotifier, AsyncValue<void>>((ref) {
  final db = ref.watch(databaseProvider);
  return TemplateNotifier(db, ref);
});
