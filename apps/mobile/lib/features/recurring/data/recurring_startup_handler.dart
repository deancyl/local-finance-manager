import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';
import 'package:finance_app/features/recurring/data/recurring_notification_service.dart';
import 'package:finance_app/features/recurring/data/background_recurring_processor.dart';

/// Service for handling recurring transactions on app startup.
class RecurringStartupHandler {
  final LocalFinanceDatabase _db;
  final Ref _ref;
  final RecurringNotificationService _notificationService;
  final BackgroundRecurringProcessor _backgroundProcessor;

  RecurringStartupHandler(
    this._db,
    this._ref,
    this._notificationService,
    this._backgroundProcessor,
  );

  /// Initialize recurring transaction processing on app startup.
  /// 
  /// This:
  /// 1. Processes any due transactions
  /// 2. Sends reminders for upcoming transactions
  /// 3. Notifies about overdue transactions
  /// 4. Registers background tasks
  Future<void> initializeOnStartup() async {
    try {
      await _notificationService.initialize();

      // Process due transactions
      await _processDueTransactions();

      // Check and send reminders
      await _checkReminders();

      // Check for overdue and notify
      await _checkOverdue();

      // Register background processing
      await _registerBackgroundTasks();

      debugPrint('Recurring transaction startup handling completed');
    } catch (e) {
      debugPrint('Failed to initialize recurring transaction handling: $e');
    }
  }

  /// Process all due recurring transactions.
  Future<List<String>> _processDueTransactions() async {
    final dueTransactions = await _db.recurringTransactionsDao.getDueTransactions();

    if (dueTransactions.isEmpty) {
      return [];
    }

    final generatedIds = <String>[];

    for (final recurring in dueTransactions) {
      try {
        final transactionId = await _db.recurringTransactionsDao.generateTransaction(recurring.id);
        generatedIds.add(transactionId);

        // Show notification for generated transaction
        final amount = recurring.valueNum / recurring.valueDenom.toDouble();
        await _notificationService.showTransactionGenerated(
          recurringId: recurring.id,
          recurringName: recurring.name,
          transactionId: transactionId,
          amount: amount,
        );

        debugPrint('Generated transaction from recurring: ${recurring.name}');
      } catch (e) {
        debugPrint('Failed to generate transaction for recurring ${recurring.id}: $e');
      }
    }

    return generatedIds;
  }

  /// Check for upcoming transactions and send reminders.
  Future<void> _checkReminders() async {
    await _notificationService.checkAndSendReminders(db: _db, ref: _ref);
  }

  /// Check for overdue transactions and notify.
  Future<void> _checkOverdue() async {
    await _notificationService.checkAndNotifyOverdue(db: _db);
  }

  /// Register background processing tasks.
  Future<void> _registerBackgroundTasks() async {
    try {
      // Register periodic processing (every 15 minutes)
      await _backgroundProcessor.registerPeriodicProcessing();

      // Register periodic reminder check (every 6 hours)
      await _backgroundProcessor.registerPeriodicReminderCheck();

      debugPrint('Background recurring tasks registered');
    } catch (e) {
      debugPrint('Failed to register background tasks: $e');
    }
  }

  /// Get count of due transactions for dashboard display.
  Future<int> getDueCount() async {
    final due = await _db.recurringTransactionsDao.getDueTransactions();
    return due.length;
  }

  /// Get upcoming transactions for the next N days.
  Future<List<RecurringTransaction>> getUpcomingTransactions({int days = 7}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final endDate = DateTime.now().millisecondsSinceEpoch + (days * 24 * 60 * 60 * 1000);

    // Get all active recurring transactions and filter in Dart
    final allActive = await _db.recurringTransactionsDao.getAllActive();

    return allActive.where((r) => 
        r.nextDate >= now && r.nextDate <= endDate).toList();
  }
}

/// Provider for the recurring startup handler.
final recurringStartupHandlerProvider = Provider<RecurringStartupHandler>((ref) {
  final db = ref.watch(databaseProvider);
  final notificationService = ref.watch(recurringNotificationServiceProvider);
  final backgroundProcessor = BackgroundRecurringProcessor();

  return RecurringStartupHandler(db, ref, notificationService, backgroundProcessor);
});

/// Provider for initializing recurring on app start.
final initializeRecurringProvider = FutureProvider<void>((ref) async {
  final handler = ref.watch(recurringStartupHandlerProvider);
  await handler.initializeOnStartup();
});

/// Provider for due transaction count.
final dueTransactionsCountProvider = FutureProvider<int>((ref) async {
  final handler = ref.watch(recurringStartupHandlerProvider);
  return handler.getDueCount();
});

/// Provider for upcoming transactions (next 7 days).
final upcomingRecurringProvider = FutureProvider<List<RecurringTransaction>>((ref) async {
  final handler = ref.watch(recurringStartupHandlerProvider);
  return handler.getUpcomingTransactions(days: 7);
});