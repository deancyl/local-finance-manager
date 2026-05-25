import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

// ============================================================
// AUTO-SAVE DRAFT PROVIDER
// ============================================================

/// Provider for managing auto-saved draft transactions
final draftAutoSaveProvider = StateNotifierProvider<DraftAutoSaveNotifier, DraftAutoSaveState>((ref) {
  final db = ref.watch(databaseProvider);
  return DraftAutoSaveNotifier(db, ref);
});

/// State for draft auto-save
class DraftAutoSaveState {
  final String? currentDraftId;
  final bool isSaving;
  final bool hasUnsavedChanges;
  final String? lastSavedAt;
  
  DraftAutoSaveState({
    this.currentDraftId,
    this.isSaving = false,
    this.hasUnsavedChanges = false,
    this.lastSavedAt,
  });
  
  DraftAutoSaveState copyWith({
    String? currentDraftId,
    bool? isSaving,
    bool? hasUnsavedChanges,
    String? lastSavedAt,
  }) {
    return DraftAutoSaveState(
      currentDraftId: currentDraftId ?? this.currentDraftId,
      isSaving: isSaving ?? this.isSaving,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
    );
  }
}

/// Notifier for auto-saving drafts with debouncing
class DraftAutoSaveNotifier extends StateNotifier<DraftAutoSaveState> {
  final LocalFinanceDatabase _db;
  final Ref _ref;
  Timer? _debounceTimer;
  static const _debounceDelay = Duration(seconds: 2);
  
  DraftAutoSaveNotifier(this._db, this._ref) : super(DraftAutoSaveState());
  
  /// Create a new draft and start auto-saving
  Future<String> startNewDraft({
    required String mode,
    String? fromAccountId,
    String? toAccountId,
    String? amount,
    String? categoryId,
    String? description,
    String? notes,
    DateTime? date,
    String currencyId = 'CNY',
    String? templateId,
    String? splitData,
    String? name,
  }) async {
    final draft = await _db.draftTransactionsDao.createDraft(
      mode: mode,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amount: amount,
      categoryId: categoryId,
      description: description,
      notes: notes,
      date: date ?? DateTime.now(),
      currencyId: currencyId,
      templateId: templateId,
      splitData: splitData,
      name: name,
    );
    
    state = state.copyWith(currentDraftId: draft.id);
    return draft.id;
  }
  
  /// Update current draft with debouncing
  void updateCurrentDraft({
    String? mode,
    String? fromAccountId,
    String? toAccountId,
    String? amount,
    String? categoryId,
    String? description,
    String? notes,
    DateTime? date,
    String? currencyId,
    String? templateId,
    String? splitData,
    String? name,
  }) {
    if (state.currentDraftId == null) return;
    
    // Mark as having unsaved changes
    state = state.copyWith(hasUnsavedChanges: true);
    
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // Start new timer
    _debounceTimer = Timer(_debounceDelay, () async {
      await _performSave(
        mode: mode,
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amount: amount,
        categoryId: categoryId,
        description: description,
        notes: notes,
        date: date,
        currencyId: currencyId,
        templateId: templateId,
        splitData: splitData,
        name: name,
      );
    });
  }
  
  /// Immediately save without debouncing
  Future<void> saveNow() async {
    _debounceTimer?.cancel();
    if (state.currentDraftId != null) {
      state = state.copyWith(isSaving: true);
      // Note: actual save is done via updateCurrentDraft calls
      state = state.copyWith(
        isSaving: false,
        hasUnsavedChanges: false,
        lastSavedAt: DateTime.now().toIso8601String(),
      );
    }
  }
  
  /// Perform the actual save
  Future<void> _performSave({
    String? mode,
    String? fromAccountId,
    String? toAccountId,
    String? amount,
    String? categoryId,
    String? description,
    String? notes,
    DateTime? date,
    String? currencyId,
    String? templateId,
    String? splitData,
    String? name,
  }) async {
    if (state.currentDraftId == null) return;
    
    state = state.copyWith(isSaving: true);
    
    try {
      await _db.draftTransactionsDao.updateDraft(
        state.currentDraftId!,
        mode: mode,
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amount: amount,
        categoryId: categoryId,
        description: description,
        notes: notes,
        date: date,
        currencyId: currencyId,
        templateId: templateId,
        splitData: splitData,
        name: name,
      );
      
      state = state.copyWith(
        isSaving: false,
        hasUnsavedChanges: false,
        lastSavedAt: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      state = state.copyWith(isSaving: false);
    }
  }
  
  /// Clear current draft after successful submission
  Future<void> clearDraft() async {
    if (state.currentDraftId != null) {
      await _db.draftTransactionsDao.deleteDraft(state.currentDraftId!);
    }
    _debounceTimer?.cancel();
    state = DraftAutoSaveState();
  }
  
  /// Load an existing draft
  Future<void> loadDraft(String draftId) async {
    final draft = await _db.draftTransactionsDao.getDraftById(draftId);
    if (draft != null) {
      state = state.copyWith(currentDraftId: draftId);
      // The quick entry provider should handle restoring the values
    }
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Provider for listing all available drafts
final availableDraftsProvider = StreamProvider<List<DraftTransaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.draftTransactionsDao.watchAllDrafts();
});

// ============================================================
// SMART DEFAULTS PROVIDER
// ============================================================

/// Smart defaults based on learning from past entries
class SmartDefaults {
  final String? suggestedAccountId;
  final String? suggestedCategoryId;
  final double? suggestedAmount;
  final List<String> frequentAccounts;
  final List<String> frequentCategories;
  final Map<String, double> averageAmountByCategory;
  final Map<String, String> commonCategoryForDescription;
  
  SmartDefaults({
    this.suggestedAccountId,
    this.suggestedCategoryId,
    this.suggestedAmount,
    List<String>? frequentAccounts,
    List<String>? frequentCategories,
    Map<String, double>? averageAmountByCategory,
    Map<String, String>? commonCategoryForDescription,
  }) : frequentAccounts = frequentAccounts ?? [],
       frequentCategories = frequentCategories ?? [],
       averageAmountByCategory = averageAmountByCategory ?? {},
       commonCategoryForDescription = commonCategoryForDescription ?? {};
}

/// Provider for smart defaults based on past transaction patterns
final smartDefaultsProvider = FutureProvider<SmartDefaults>((ref) async {
  final db = ref.watch(databaseProvider);
  
  // Get recent splits (last 30 days)
  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
  
  final recentSplits = await (db.select(db.splits)
      ..where((s) => s.createdAt.isBiggerOrEqualValue(thirtyDaysAgo))
      ..orderBy([(s) => drift.OrderingTerm.desc(s.createdAt)])
      ..limit(50))
      .get();
  
  // Analyze account frequency
  final accountCounts = <String, int>{};
  for (final split in recentSplits) {
    accountCounts[split.accountId] = (accountCounts[split.accountId] ?? 0) + 1;
  }
  
  final frequentAccounts = accountCounts.entries
      .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  final frequentAccountIds = frequentAccounts.map((e) => e.key).toList();
  
  // Analyze category frequency
  final categoryCounts = <String, int>{};
  for (final split in recentSplits) {
    if (split.categoryId != null) {
      categoryCounts[split.categoryId!] = (categoryCounts[split.categoryId!] ?? 0) + 1;
    }
  }
  
  final frequentCategories = categoryCounts.entries
      .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  final frequentCategoryIds = frequentCategories.map((e) => e.key).toList();
  
  // Calculate average amounts by category
  final amountsByCategory = <String, List<int>>{};
  for (final split in recentSplits) {
    if (split.categoryId != null) {
      amountsByCategory[split.categoryId!] = (amountsByCategory[split.categoryId!] ?? [])
        ..add(split.valueNum.abs());
    }
  }
  
  final averageAmountByCategory = <String, double>{};
  for (final entry in amountsByCategory.entries) {
    if (entry.value.isNotEmpty) {
      final avg = entry.value.reduce((a, b) => a + b) / entry.value.length / 100.0;
      averageAmountByCategory[entry.key] = avg;
    }
  }
  
  // Analyze description-to-category mappings
  final transactions = await (db.select(db.transactions)
      ..where((t) => t.postDate.isBiggerOrEqualValue(thirtyDaysAgo))
      ..orderBy([(t) => drift.OrderingTerm.desc(t.postDate)]))
      .get();
  
  final descriptionToCategory = <String, String>{};
  final transactionCategoryMap = <String, String>{};
  
  // Map transaction IDs to categories via splits
  for (final split in recentSplits) {
    if (split.categoryId != null) {
      transactionCategoryMap[split.transactionId] = split.categoryId!;
    }
  }
  
  // Map descriptions to categories
  for (final txn in transactions) {
    if (txn.description != null && txn.description!.isNotEmpty) {
      final category = transactionCategoryMap[txn.id];
      if (category != null) {
        // Use the most recent category for this description
        descriptionToCategory[txn.description!] = category;
      }
    }
  }
  
  return SmartDefaults(
    suggestedAccountId: frequentAccountIds.isNotEmpty ? frequentAccountIds.first : null,
    suggestedCategoryId: frequentCategoryIds.isNotEmpty ? frequentCategoryIds.first : null,
    suggestedAmount: averageAmountByCategory[frequentCategoryIds.firstOrNull] ?? 100.0,
    frequentAccounts: frequentAccountIds.take(5).toList(),
    frequentCategories: frequentCategoryIds.take(5).toList(),
    averageAmountByCategory: averageAmountByCategory,
    commonCategoryForDescription: descriptionToCategory,
  );
});

/// Helper extension for sorting
extension SortedExtension<T> on List<T> {
  List<T> sorted(int compare(T a, T b)) {
    final list = List<T>.from(this);
    list.sort(compare);
    return list;
  }
}

/// Extension for nullable first element
extension FirstOrNullExtension<T> on List<T> {
  T? firstOrNull() {
    return isEmpty ? null : first;
  }
}