import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:database/database.dart';

/// Background task identifier for recurring transaction processing.
const String _recurringProcessTask = 'recurring_transaction_process';

/// Background task identifier for recurring reminders.
const String _recurringReminderTask = 'recurring_reminder_check';

/// Callback dispatcher for workmanager.
@pragma('vm:entry-point')
void recurringCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case _recurringProcessTask:
        await _processRecurringTransactions();
        break;
      case _recurringReminderTask:
        await _checkRecurringReminders();
        break;
    }
    return Future.value(true);
  });
}

/// Process due recurring transactions in background isolate.
Future<void> _processRecurringTransactions() async {
  try {
    // Initialize database connection
    final db = await _openDatabase();
    
    // Get due transactions
    final dueTransactions = await db.recurringTransactionsDao.getDueTransactions();
    
    if (dueTransactions.isEmpty) {
      await db.close();
      return;
    }

    // Initialize notifications
    final notifications = FlutterLocalNotificationsPlugin();
    await _initializeNotifications(notifications);
    
    final generatedIds = <String>[];
    
    for (final recurring in dueTransactions) {
      try {
        final transactionId = await db.recurringTransactionsDao.generateTransaction(recurring.id);
        generatedIds.add(transactionId);
        
        // Show notification for generated transaction
        await _showGeneratedNotification(
          notifications,
          recurringName: recurring.name,
          transactionId: transactionId,
        );
      } catch (e) {
        debugPrint('Failed to generate transaction for recurring ${recurring.id}: $e');
      }
    }
    
    await db.close();
    
    debugPrint('Generated ${generatedIds.length} recurring transactions in background');
  } catch (e) {
    debugPrint('Background recurring processing failed: $e');
  }
}

/// Check for upcoming recurring transactions and send reminders.
Future<void> _checkRecurringReminders() async {
  try {
    final db = await _openDatabase();
    final notifications = FlutterLocalNotificationsPlugin();
    await _initializeNotifications(notifications);
    
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    
    // Get all active recurring transactions with reminders enabled
    final allRecurring = await (db.select(db.recurringTransactions)
          ..where((r) =>
              r.isActive.equals(true) &
              r.deletedAt.isNull() &
              r.reminderDays.isNotNull()))
        .get();
    
    for (final recurring in allRecurring) {
      if (recurring.reminderDays == null) continue;
      
      final nextDate = DateTime.fromMillisecondsSinceEpoch(recurring.nextDate);
      final reminderDate = nextDate.subtract(Duration(days: recurring.reminderDays!));
      
      // Check if we should send a reminder today
      if (now.year == reminderDate.year &&
          now.month == reminderDate.month &&
          now.day == reminderDate.day) {
        // Check if we already sent this reminder
        final prefs = await SharedPreferences.getInstance();
        final reminderKey = 'recurring_reminder_${recurring.id}_${nextDate.millisecondsSinceEpoch}';
        
        if (!prefs.getBool(reminderKey) ?? false) {
          // Send reminder
          await _showReminderNotification(
            notifications,
            recurringId: recurring.id,
            recurringName: recurring.name,
            nextDate: nextDate,
            amount: recurring.valueNum / recurring.valueDenom.toDouble(),
          );
          
          // Mark as sent
          await prefs.setBool(reminderKey, true);
        }
      }
    }
    
    await db.close();
  } catch (e) {
    debugPrint('Background recurring reminder check failed: $e');
  }
}

/// Initialize notifications for background task.
Future<void> _initializeNotifications(FlutterLocalNotificationsPlugin notifications) async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  await notifications.initialize(initSettings);
}

/// Show notification for generated transaction.
Future<void> _showGeneratedNotification(
  FlutterLocalNotificationsPlugin notifications, {
  required String recurringName,
  required String transactionId,
}) async {
  const androidDetails = AndroidNotificationDetails(
    'recurring_transactions',
    '定期交易',
    channelDescription: '定期交易自动生成通知',
    importance: Importance.high,
    priority: Priority.high,
  );
  const iosDetails = DarwinNotificationDetails();
  const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
  
  await notifications.show(
    transactionId.hashCode,
    '定期交易已生成',
    '"$recurringName" 的交易已自动创建',
    details,
    payload: jsonEncode({
      'type': 'recurring_generated',
      'transactionId': transactionId,
    }),
  );
}

/// Show reminder notification for upcoming recurring transaction.
Future<void> _showReminderNotification(
  FlutterLocalNotificationsPlugin notifications, {
  required String recurringId,
  required String recurringName,
  required DateTime nextDate,
  required double amount,
}) async {
  const androidDetails = AndroidNotificationDetails(
    'recurring_reminders',
    '定期交易提醒',
    channelDescription: '定期交易即将到期提醒',
    importance: Importance.high,
    priority: Priority.high,
  );
  const iosDetails = DarwinNotificationDetails();
  const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
  
  await notifications.show(
    recurringId.hashCode,
    '定期交易即将到期',
    '"$recurringName" 将于 ${nextDate.month}月${nextDate.day}日 执行，金额: ¥${amount.toStringAsFixed(2)}',
    details,
    payload: jsonEncode({
      'type': 'recurring_reminder',
      'recurringId': recurringId,
    }),
  );
}

/// Open database connection for background task.
Future<LocalFinanceDatabase> _openDatabase() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  final file = File('${dbFolder.path}/finance.db');
  
  // Note: For encrypted database, you'd need to handle the key retrieval
  // This is a simplified version - in production, use the actual encrypted database setup
  final executor = NativeDatabase.createInBackground(file);
  
  return LocalFinanceDatabase.forTesting(executor);
}

/// Background recurring transaction processor manager.
class BackgroundRecurringProcessor {
  static final BackgroundRecurringProcessor _instance = BackgroundRecurringProcessor._internal();
  factory BackgroundRecurringProcessor() => _instance;
  BackgroundRecurringProcessor._internal();

  bool _initialized = false;

  /// Initialize background recurring processing.
  Future<void> initialize() async {
    if (_initialized) return;

    await Workmanager().initialize(
      recurringCallbackDispatcher,
      isInDebugMode: kDebugMode,
    );

    _initialized = true;
  }

  /// Register periodic task to process due recurring transactions.
  /// Runs every 15 minutes (minimum interval for workmanager).
  Future<void> registerPeriodicProcessing() async {
    if (!_initialized) await initialize();

    await Workmanager().registerPeriodicTask(
      _recurringProcessTask,
      _recurringProcessTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  /// Register periodic task to check for reminders.
  /// Runs once per day at a specific time.
  Future<void> registerPeriodicReminderCheck() async {
    if (!_initialized) await initialize();

    await Workmanager().registerPeriodicTask(
      _recurringReminderTask,
      _recurringReminderTask,
      frequency: const Duration(hours: 6), // Check every 6 hours
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  /// Cancel periodic processing.
  Future<void> cancelPeriodicProcessing() async {
    await Workmanager().cancelByUniqueName(_recurringProcessTask);
  }

  /// Cancel periodic reminder check.
  Future<void> cancelPeriodicReminderCheck() async {
    await Workmanager().cancelByUniqueName(_recurringReminderTask);
  }

  /// Run a one-time processing of due transactions.
  Future<void> runOneTimeProcessing() async {
    if (!_initialized) await initialize();

    await Workmanager().registerOneOffTask(
      _recurringProcessTask,
      _recurringProcessTask,
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  /// Run a one-time reminder check.
  Future<void> runOneTimeReminderCheck() async {
    if (!_initialized) await initialize();

    await Workmanager().registerOneOffTask(
      _recurringReminderTask,
      _recurringReminderTask,
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }
}
