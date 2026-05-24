import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';
import 'package:finance_app/features/templates/data/template_provider.dart';

// ============================================================
// QUICK ENTRY MODES
// ============================================================

enum QuickEntryMode {
  simple,     // Single account, simple amount
  transfer,   // Transfer between two accounts
  split,      // Multiple splits (full journal entry)
  template,   // Use template
}

// ============================================================
// QUICK ENTRY STATE
// ============================================================

/// State for quick entry
class QuickEntryState {
  final QuickEntryMode mode;
  final String? fromAccountId;
  final String? toAccountId;
  final double? amount;
  final String? categoryId;
  final String? description;
  final String? notes;
  final DateTime date;
  final String currencyId;
  final String? templateId;

  QuickEntryState({
    this.mode = QuickEntryMode.simple,
    this.fromAccountId,
    this.toAccountId,
    this.amount,
    this.categoryId,
    this.description,
    this.notes,
    DateTime? date,
    this.currencyId = 'CNY',
    this.templateId,
  }) : date = date ?? DateTime.now();

  QuickEntryState copyWith({
    QuickEntryMode? mode,
    String? fromAccountId,
    String? toAccountId,
    double? amount,
    String? categoryId,
    String? description,
    String? notes,
    DateTime? date,
    String? currencyId,
    String? templateId,
  }) {
    return QuickEntryState(
      mode: mode ?? this.mode,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      currencyId: currencyId ?? this.currencyId,
      templateId: templateId ?? this.templateId,
    );
  }

  bool get isValid {
    switch (mode) {
      case QuickEntryMode.simple:
        return fromAccountId != null && amount != null && amount! > 0;
      case QuickEntryMode.transfer:
        return fromAccountId != null &&
            toAccountId != null &&
            amount != null &&
            amount! > 0 &&
            fromAccountId != toAccountId;
      case QuickEntryMode.split:
        return amount != null && amount! > 0;
      case QuickEntryMode.template:
        return templateId != null;
    }
  }
}

// ============================================================
// QUICK ENTRY NOTIFIER
// ============================================================

class QuickEntryNotifier extends StateNotifier<QuickEntryState> {
  final LocalFinanceDatabase _db;
  final Ref _ref;

  QuickEntryNotifier(this._db, this._ref) : super(QuickEntryState());

  void setMode(QuickEntryMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setFromAccount(String? accountId) {
    state = state.copyWith(fromAccountId: accountId);
  }

  void setToAccount(String? accountId) {
    state = state.copyWith(toAccountId: accountId);
  }

  void setAmount(double? amount) {
    state = state.copyWith(amount: amount);
  }

  void setCategory(String? categoryId) {
    state = state.copyWith(categoryId: categoryId);
  }

  void setDescription(String? description) {
    state = state.copyWith(description: description);
  }

  void setNotes(String? notes) {
    state = state.copyWith(notes: notes);
  }

  void setDate(DateTime date) {
    state = state.copyWith(date: date);
  }

  void setTemplate(String? templateId) {
    state = state.copyWith(templateId: templateId);
  }

  void reset() {
    state = QuickEntryState();
  }

  /// Submit the quick entry
  Future<String?> submit() async {
    if (!state.isValid) return null;

    try {
      final transactionId = const Uuid().v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final postDate = state.date.millisecondsSinceEpoch;
      final amountNum = ((state.amount ?? 0) * 100).round();

      await _db.transaction(() async {
        // Create transaction
        await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            id: transactionId,
            postDate: postDate,
            enterDate: now,
            currencyId: state.currencyId,
            description: drift.Value(state.description),
            notes: drift.Value(state.notes),
            createdAt: now,
            updatedAt: now,
          ),
        );

        switch (state.mode) {
          case QuickEntryMode.simple:
            await _createSimpleSplit(transactionId, amountNum, now);
            break;
          case QuickEntryMode.transfer:
            await _createTransferSplits(transactionId, amountNum, now);
            break;
          case QuickEntryMode.split:
            // For split mode, UI should handle split creation
            break;
          case QuickEntryMode.template:
            await _createFromTemplate(transactionId, amountNum, now);
            break;
        }
      });

      // Reset state after successful submission
      reset();

      return transactionId;
    } catch (e) {
      return null;
    }
  }

  Future<void> _createSimpleSplit(
    String transactionId,
    int amountNum,
    int now,
  ) async {
    final splitId = const Uuid().v4();

    await _db.into(_db.splits).insert(
      SplitsCompanion.insert(
        id: splitId,
        transactionId: transactionId,
        accountId: state.fromAccountId!,
        categoryId: drift.Value(state.categoryId),
        valueNum: -amountNum, // Expense = debit
        quantityNum: -amountNum,
        createdAt: now,
      ),
    );
  }

  Future<void> _createTransferSplits(
    String transactionId,
    int amountNum,
    int now,
  ) async {
    final fromSplitId = const Uuid().v4();
    final toSplitId = const Uuid().v4();

    // From account (debit)
    await _db.into(_db.splits).insert(
      SplitsCompanion.insert(
        id: fromSplitId,
        transactionId: transactionId,
        accountId: state.fromAccountId!,
        valueNum: -amountNum,
        quantityNum: -amountNum,
        createdAt: now,
      ),
    );

    // To account (credit)
    await _db.into(_db.splits).insert(
      SplitsCompanion.insert(
        id: toSplitId,
        transactionId: transactionId,
        accountId: state.toAccountId!,
        valueNum: amountNum,
        quantityNum: amountNum,
        createdAt: now,
      ),
    );
  }

  Future<void> _createFromTemplate(
    String transactionId,
    int amountNum,
    int now,
  ) async {
    if (state.templateId == null) return;

    final template = await _db.transactionTemplatesDao.getById(state.templateId!);
    if (template == null) return;

    final splitsData = template.splitTemplates;
    // Parse and create splits from template
    // TODO: Implement split creation from template JSON

    // Record template usage
    await _db.transactionTemplatesDao.recordUsage(state.templateId!);
  }
}

// ============================================================
// PROVIDERS
// ============================================================

final quickEntryProvider =
    StateNotifierProvider<QuickEntryNotifier, QuickEntryState>((ref) {
  final db = ref.watch(databaseProvider);
  return QuickEntryNotifier(db, ref);
});

/// Provider for suggested accounts based on recent usage
final suggestedAccountsProvider = FutureProvider<List<String>>((ref) async {
  final db = ref.watch(databaseProvider);
  
  // Get accounts from recent splits
  final recentSplits = await db.select(db.splits)
      .orderBy([(s) => drift.OrderingTerm.desc(s.createdAt)])
      .limit(10)
      .get();

  return recentSplits.map((s) => s.accountId).toSet().toList();
});

/// Provider for suggested categories
final suggestedCategoriesProvider = FutureProvider<List<String>>((ref) async {
  final db = ref.watch(databaseProvider);
  
  final recentSplits = await db.select(db.splits)
      .where((s) => s.categoryId.isNotNull())
      .orderBy([(s) => drift.OrderingTerm.desc(s.createdAt)])
      .limit(10)
      .get();

  return recentSplits
      .where((s) => s.categoryId != null)
      .map((s) => s.categoryId!)
      .toSet()
      .toList();
});
