import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';
import 'package:core/core.dart';

/// Provider for the RecurringProcessor service.
final recurringProcessorProvider = Provider<RecurringProcessor>((ref) {
  final db = ref.watch(databaseProvider);
  return RecurringProcessor(db);
});

/// Provider that watches all non-deleted recurring transactions.
final recurringTransactionsProvider = StreamProvider<List<RecurringTransaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.recurringTransactionsDao.watchAll();
});

/// Provider that watches active recurring transactions.
final activeRecurringTransactionsProvider = StreamProvider<List<RecurringTransaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.recurringTransactionsDao.watchActive();
});

/// Provider that finds due transactions (need to be generated).
final dueTransactionsProvider = FutureProvider<List<RecurringTransaction>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.recurringTransactionsDao.getDueTransactions();
});

/// Provider for a single recurring transaction by ID.
final recurringByIdProvider = FutureProvider.family<RecurringTransaction?, String>((ref, id) async {
  final db = ref.watch(databaseProvider);
  return db.recurringTransactionsDao.getById(id);
});

/// Provider that watches upcoming scheduled transactions (next 7 days).
final upcomingScheduledTransactionsProvider = StreamProvider<List<RecurringTransaction>>((ref) {
  final processor = ref.watch(recurringProcessorProvider);
  return processor.watchUpcomingTransactions(days: 7);
});

/// Provider for overdue transactions (past due date but not yet generated).
final overdueTransactionsProvider = FutureProvider<List<RecurringTransaction>>((ref) async {
  final processor = ref.watch(recurringProcessorProvider);
  return processor.getOverdueTransactions();
});

/// Notifier for recurring transaction CRUD operations.
class RecurringNotifier extends StateNotifier<AsyncValue<void>> {
  final LocalFinanceDatabase _db;

  RecurringNotifier(this._db) : super(const AsyncValue.data(null));

  Future<void> createRecurring({
    required String name,
    required int valueNum,
    int valueDenom = 100,
    String? description,
    String? memo,
    String? accountId,
    String? categoryId,
    required String frequency,
    int interval = 1,
    int? dayOfWeek,
    int? dayOfMonth,
    int? monthOfYear,
    required DateTime startDate,
    required DateTime nextDate,
    DateTime? endDate,
    int? maxOccurrences,
    int? reminderDays,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      await _db.recurringTransactionsDao.create(
        RecurringTransactionsCompanion.insert(
          id: id,
          name: name,
          valueNum: valueNum,
          valueDenom: drift.Value(valueDenom),
          description: drift.Value(description),
          memo: drift.Value(memo),
          accountId: drift.Value(accountId),
          categoryId: drift.Value(categoryId),
          frequency: drift.Value(frequency),
          interval: drift.Value(interval),
          dayOfWeek: drift.Value(dayOfWeek),
          dayOfMonth: drift.Value(dayOfMonth),
          monthOfYear: drift.Value(monthOfYear),
          startDate: startDate.millisecondsSinceEpoch,
          nextDate: nextDate.millisecondsSinceEpoch,
          endDate: drift.Value(endDate?.millisecondsSinceEpoch),
          maxOccurrences: drift.Value(maxOccurrences),
          reminderDays: drift.Value(reminderDays),
          notes: drift.Value(notes),
          createdAt: now,
          updatedAt: now,
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateRecurring({
    required String id,
    String? name,
    int? valueNum,
    int? valueDenom,
    String? description,
    String? memo,
    String? accountId,
    String? categoryId,
    String? frequency,
    int? interval,
    int? dayOfWeek,
    int? dayOfMonth,
    int? monthOfYear,
    DateTime? nextDate,
    DateTime? endDate,
    int? maxOccurrences,
    int? reminderDays,
    String? notes,
    bool? isActive,
  }) async {
    state = const AsyncValue.loading();
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      await _db.recurringTransactionsDao.updateRecurring(
        RecurringTransactionsCompanion(
          id: drift.Value(id),
          updatedAt: drift.Value(now),
          name: name != null ? drift.Value(name) : const drift.Value.absent(),
          valueNum: valueNum != null ? drift.Value(valueNum) : const drift.Value.absent(),
          valueDenom: valueDenom != null ? drift.Value(valueDenom) : const drift.Value.absent(),
          description: description != null ? drift.Value(description) : const drift.Value.absent(),
          memo: memo != null ? drift.Value(memo) : const drift.Value.absent(),
          accountId: accountId != null ? drift.Value(accountId) : const drift.Value.absent(),
          categoryId: categoryId != null ? drift.Value(categoryId) : const drift.Value.absent(),
          frequency: frequency != null ? drift.Value(frequency) : const drift.Value.absent(),
          interval: interval != null ? drift.Value(interval) : const drift.Value.absent(),
          dayOfWeek: dayOfWeek != null ? drift.Value(dayOfWeek) : const drift.Value.absent(),
          dayOfMonth: dayOfMonth != null ? drift.Value(dayOfMonth) : const drift.Value.absent(),
          monthOfYear: monthOfYear != null ? drift.Value(monthOfYear) : const drift.Value.absent(),
          nextDate: nextDate != null ? drift.Value(nextDate.millisecondsSinceEpoch) : const drift.Value.absent(),
          endDate: endDate != null ? drift.Value(endDate.millisecondsSinceEpoch) : const drift.Value.absent(),
          maxOccurrences: maxOccurrences != null ? drift.Value(maxOccurrences) : const drift.Value.absent(),
          reminderDays: reminderDays != null ? drift.Value(reminderDays) : const drift.Value.absent(),
          notes: notes != null ? drift.Value(notes) : const drift.Value.absent(),
          isActive: isActive != null ? drift.Value(isActive) : const drift.Value.absent(),
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteRecurring(String id) async {
    state = const AsyncValue.loading();
    try {
      await _db.recurringTransactionsDao.deleteRecurring(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleActive(String id, bool isActive) async {
    state = const AsyncValue.loading();
    try {
      await _db.recurringTransactionsDao.toggleActive(id, isActive);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<String> generateNow(String recurringId) async {
    state = const AsyncValue.loading();
    try {
      final transactionId = await _db.recurringTransactionsDao.generateTransaction(recurringId);
      state = const AsyncValue.data(null);
      return transactionId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateNextDate(String recurringId) async {
    state = const AsyncValue.loading();
    try {
      await _db.recurringTransactionsDao.updateNextDate(recurringId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for the recurring notifier.
final recurringNotifierProvider = StateNotifierProvider<RecurringNotifier, AsyncValue<void>>((ref) {
  final db = ref.watch(databaseProvider);
  return RecurringNotifier(db);
});

/// Notifier for triggering recurring transaction generation.
class RecurringGenerationNotifier extends StateNotifier<AsyncValue<List<String>>> {
  final RecurringProcessor _processor;

  RecurringGenerationNotifier(this._processor) : super(const AsyncValue.data([]));

  /// Process all due recurring transactions.
  Future<void> processAll() async {
    state = const AsyncValue.loading();
    try {
      final ids = await _processor.processDueTransactions();
      state = AsyncValue.data(ids);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Generate a single recurring transaction manually.
  Future<String?> generateOne(String recurringId) async {
    try {
      return await _processor.generateSingle(recurringId);
    } catch (e) {
      return null;
    }
  }
}

/// Provider for the generation notifier.
final recurringGenerationNotifierProvider = StateNotifierProvider<RecurringGenerationNotifier, AsyncValue<List<String>>>((ref) {
  final processor = ref.watch(recurringProcessorProvider);
  return RecurringGenerationNotifier(processor);
});
