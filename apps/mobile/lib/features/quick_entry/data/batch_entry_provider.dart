import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart' as uuid_pkg;

import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

// ============================================================
// BATCH ENTRY MODELS
// ============================================================

/// Single entry in batch mode
class BatchEntry {
  final String? accountId;
  final double? amount;
  final String? categoryId;
  final String? description;
  final String? notes;
  final DateTime date;
  final String currencyId;
  
  BatchEntry({
    this.accountId,
    this.amount,
    this.categoryId,
    this.description,
    this.notes,
    DateTime? date,
    this.currencyId = 'CNY',
  }) : date = date ?? DateTime.now();
  
  BatchEntry copyWith({
    String? accountId,
    double? amount,
    String? categoryId,
    String? description,
    String? notes,
    DateTime? date,
    String? currencyId,
  }) {
    return BatchEntry(
      accountId: accountId ?? this.accountId,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      currencyId: currencyId ?? this.currencyId,
    );
  }
  
  bool get isValid {
    return accountId != null && amount != null && amount! > 0;
  }
}

// ============================================================
// BATCH ENTRY STATE
// ============================================================

/// State for batch entry mode
class BatchEntryState {
  final BatchEntry currentEntry;
  final List<BatchEntry> pendingEntries;
  final bool isSubmitting;
  
  BatchEntryState({
    BatchEntry? currentEntry,
    this.pendingEntries = [],
    this.isSubmitting = false,
  }) : currentEntry = currentEntry ?? BatchEntry();
  
  BatchEntryState copyWith({
    BatchEntry? currentEntry,
    List<BatchEntry>? pendingEntries,
    bool? isSubmitting,
  }) {
    return BatchEntryState(
      currentEntry: currentEntry ?? this.currentEntry,
      pendingEntries: pendingEntries ?? this.pendingEntries,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

// ============================================================
// BATCH ENTRY NOTIFIER
// ============================================================

class BatchEntryNotifier extends StateNotifier<BatchEntryState> {
  final LocalFinanceDatabase _db;
  final Ref _ref;
  
  BatchEntryNotifier(this._db, this._ref) : super(BatchEntryState());
  
  /// Update amount for current entry
  void updateAmount(double? amount) {
    state = state.copyWith(currentEntry: state.currentEntry.copyWith(amount: amount));
  }
  
  /// Update account for current entry
  void updateAccount(String? accountId) {
    state = state.copyWith(currentEntry: state.currentEntry.copyWith(accountId: accountId));
  }
  
  /// Update category for current entry
  void updateCategory(String? categoryId) {
    state = state.copyWith(currentEntry: state.currentEntry.copyWith(categoryId: categoryId));
  }
  
  /// Update description for current entry
  void updateDescription(String? description) {
    state = state.copyWith(currentEntry: state.currentEntry.copyWith(description: description));
  }
  
  /// Update notes for current entry
  void updateNotes(String? notes) {
    state = state.copyWith(currentEntry: state.currentEntry.copyWith(notes: notes));
  }
  
  /// Update date for current entry
  void updateDate(DateTime date) {
    state = state.copyWith(currentEntry: state.currentEntry.copyWith(date: date));
  }
  
  /// Add current entry to pending list and reset current
  void addToPending() {
    if (!state.currentEntry.isValid) return;
    
    state = state.copyWith(
      pendingEntries: [...state.pendingEntries, state.currentEntry],
      currentEntry: BatchEntry(date: state.currentEntry.date),
    );
  }
  
  /// Remove entry from pending list
  void removeFromPending(int index) {
    if (index < 0 || index >= state.pendingEntries.length) return;
    
    final entries = List<BatchEntry>.from(state.pendingEntries);
    entries.removeAt(index);
    state = state.copyWith(pendingEntries: entries);
  }
  
  /// Clear all pending entries
  void clearAll() {
    state = state.copyWith(pendingEntries: []);
  }
  
  /// Submit all pending entries to database
  Future<int> submitAll() async {
    if (state.pendingEntries.isEmpty) return 0;
    
    state = state.copyWith(isSubmitting: true);
    
    try {
      int count = 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      await _db.transaction(() async {
        for (final entry in state.pendingEntries) {
          if (!entry.isValid) continue;
          
          final transactionId = const uuid_pkg.Uuid().v4();
          final postDate = entry.date.millisecondsSinceEpoch;
          final amountNum = ((entry.amount ?? 0) * 100).round();
          
          // Create transaction
          await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              id: transactionId,
              postDate: postDate,
              enterDate: now,
              currencyId: entry.currencyId,
              description: drift.Value(entry.description),
              notes: drift.Value(entry.notes),
              createdAt: now,
              updatedAt: now,
            ),
          );
          
          // Create split (expense = debit)
          final splitId = const uuid_pkg.Uuid().v4();
          await _db.into(_db.splits).insert(
            SplitsCompanion.insert(
              id: splitId,
              transactionId: transactionId,
              accountId: entry.accountId!,
              categoryId: drift.Value(entry.categoryId),
              valueNum: -amountNum,
              quantityNum: -amountNum,
              createdAt: now,
            ),
          );
          
          count++;
        }
      });
      
      // Clear pending and reset state
      state = BatchEntryState(
        currentEntry: BatchEntry(),
        pendingEntries: [],
        isSubmitting: false,
      );
      
      return count;
    } catch (e) {
      state = state.copyWith(isSubmitting: false);
      return 0;
    }
  }
  
  /// Load a draft into batch mode (for resuming)
  Future<void> loadDraft(String draftId) async {
    // Implementation would load from draft transactions table
    // and populate pending entries list
  }
}

// ============================================================
// PROVIDERS
// ============================================================

final batchEntryProvider =
    StateNotifierProvider<BatchEntryNotifier, BatchEntryState>((ref) {
  final db = ref.watch(databaseProvider);
  return BatchEntryNotifier(db, ref);
});