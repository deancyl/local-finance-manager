import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

/// Recurring transaction notification service for managing alerts.
class RecurringNotificationService {
  static final RecurringNotificationService _instance = RecurringNotificationService._internal();
  factory RecurringNotificationService() => _instance;
  RecurringNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Notification channel configuration for Android.
  static const AndroidNotificationDetails _transactionChannel = AndroidNotificationDetails(
    'recurring_transactions',
    '定期交易',
    channelDescription: '定期交易自动生成通知',
    importance: Importance.high,
    priority: Priority.high,
    showWhen: true,
  );

  /// Notification channel for reminders.
  static const AndroidNotificationDetails _reminderChannel = AndroidNotificationDetails(
    'recurring_reminders',
    '定期交易提醒',
    channelDescription: '定期交易即将到期提醒',
    importance: Importance.high,
    priority: Priority.high,
    showWhen: true,
  );

  /// iOS notification settings.
  static const DarwinNotificationDetails _iosSettings = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  /// Initialize the notification service.
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  /// Request notification permissions.
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.requestNotificationsPermission() ?? false;
    } else if (Platform.isIOS) {
      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await iosPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  /// Show notification for a generated transaction.
  Future<void> showTransactionGenerated({
    required String recurringId,
    required String recurringName,
    required String transactionId,
    double? amount,
  }) async {
    if (!_initialized) await initialize();

    final title = '定期交易已生成';
    final body = amount != null
        ? '"$recurringName" (¥${amount.toStringAsFixed(2)}) 的交易已自动创建'
        : '"$recurringName" 的交易已自动创建';

    final details = NotificationDetails(
      android: _transactionChannel,
      iOS: _iosSettings,
    );

    await _notifications.show(
      transactionId.hashCode,
      title,
      body,
      details,
      payload: jsonEncode({
        'type': 'recurring_generated',
        'recurringId': recurringId,
        'transactionId': transactionId,
      }),
    );
  }

  /// Show reminder notification for an upcoming recurring transaction.
  Future<void> showUpcomingReminder({
    required String recurringId,
    required String recurringName,
    required DateTime nextDate,
    required double amount,
    int daysUntil = 1,
  }) async {
    if (!_initialized) await initialize();

    final title = daysUntil == 0
        ? '定期交易今天执行'
        : '定期交易即将到期';
    
    final dateStr = DateFormat.yMMMd().format(nextDate);
    final body = daysUntil == 0
        ? '"$recurringName" (¥${amount.toStringAsFixed(2)}) 将在今天执行'
        : '"$recurringName" (¥${amount.toStringAsFixed(2)}) 将于$dateStr执行';

    final details = NotificationDetails(
      android: _reminderChannel,
      iOS: _iosSettings,
    );

    await _notifications.show(
      recurringId.hashCode,
      title,
      body,
      details,
      payload: jsonEncode({
        'type': 'recurring_reminder',
        'recurringId': recurringId,
        'nextDate': nextDate.millisecondsSinceEpoch,
      }),
    );
  }

  /// Show notification for overdue recurring transaction.
  Future<void> showOverdueNotification({
    required String recurringId,
    required String recurringName,
    required DateTime dueDate,
    required double amount,
  }) async {
    if (!_initialized) await initialize();

    final daysOverdue = DateTime.now().difference(dueDate).inDays;
    final title = '定期交易已逾期';
    final body = '"$recurringName" (¥${amount.toStringAsFixed(2)}) 已逾期 $daysOverdue 天';

    final details = NotificationDetails(
      android: _reminderChannel,
      iOS: _iosSettings,
    );

    await _notifications.show(
      recurringId.hashCode,
      title,
      body,
      details,
      payload: jsonEncode({
        'type': 'recurring_overdue',
        'recurringId': recurringId,
      }),
    );
  }

  /// Check for upcoming recurring transactions and send reminders.
  Future<void> checkAndSendReminders({
    required LocalFinanceDatabase db,
    required Ref ref,
  }) async {
    try {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();

      // Get all active recurring transactions
      final allRecurring = await db.recurringTransactionsDao.getAllActive();

      // Filter for reminderDays in Dart
      final withReminders = allRecurring.where((r) => r.reminderDays != null).toList();

      for (final recurring in withReminders) {

        final nextDate = DateTime.fromMillisecondsSinceEpoch(recurring.nextDate);
        final reminderDate = nextDate.subtract(Duration(days: recurring.reminderDays!));
        final amount = recurring.valueNum / recurring.valueDenom.toDouble();

        // Check if we should send a reminder today
        final shouldSendReminder = now.year == reminderDate.year &&
            now.month == reminderDate.month &&
            now.day == reminderDate.day;

        if (shouldSendReminder) {
          // Check if we already sent this reminder
          final reminderKey = 'recurring_reminder_${recurring.id}_${nextDate.millisecondsSinceEpoch}';

          if (!(prefs.getBool(reminderKey) ?? false)) {
            // Send reminder
            await showUpcomingReminder(
              recurringId: recurring.id,
              recurringName: recurring.name,
              nextDate: nextDate,
              amount: amount,
              daysUntil: recurring.reminderDays!,
            );

            // Mark as sent
            await prefs.setBool(reminderKey, true);
          }
        }
      }

      // Clean up old reminder keys (older than 30 days)
      await _cleanupOldReminderKeys(prefs);
    } catch (e) {
      debugPrint('Failed to check recurring reminders: $e');
    }
  }

  /// Check for overdue transactions and notify.
  Future<void> checkAndNotifyOverdue({
    required LocalFinanceDatabase db,
  }) async {
    try {
      final dueTransactions = await db.recurringTransactionsDao.getDueTransactions();
      final prefs = await SharedPreferences.getInstance();

      for (final recurring in dueTransactions) {
        final nextDate = DateTime.fromMillisecondsSinceEpoch(recurring.nextDate);
        final amount = recurring.valueNum / recurring.valueDenom.toDouble();

        // Only notify once per day for overdue
        final overdueKey = 'recurring_overdue_${recurring.id}_${DateTime.now().day}';
        
        if (!(prefs.getBool(overdueKey) ?? false)) {
          await showOverdueNotification(
            recurringId: recurring.id,
            recurringName: recurring.name,
            dueDate: nextDate,
            amount: amount,
          );
          
          await prefs.setBool(overdueKey, true);
        }
      }
    } catch (e) {
      debugPrint('Failed to check overdue recurring transactions: $e');
    }
  }

  /// Cancel notification for a specific recurring transaction.
  Future<void> cancelRecurringNotification(String recurringId) async {
    await _notifications.cancel(recurringId.hashCode);
  }

  /// Cancel all recurring notifications.
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Clean up old reminder keys from SharedPreferences.
  Future<void> _cleanupOldReminderKeys(SharedPreferences prefs) async {
    final now = DateTime.now();
    final thirtyDaysAgoMs = now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;

    final keys = prefs.getKeys().where((k) => k.startsWith('recurring_reminder_'));

    for (final key in keys) {
      // Extract timestamp from key
      final parts = key.split('_');
      if (parts.length >= 4) {
        final timestamp = int.tryParse(parts.last);
        if (timestamp != null && timestamp < thirtyDaysAgoMs) {
          await prefs.remove(key);
        }
      }
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // This will be handled by the notification tap handler in main.dart
    debugPrint('Recurring notification tapped: ${response.payload}');
  }
}

/// Provider for the recurring notification service.
final recurringNotificationServiceProvider = Provider<RecurringNotificationService>((ref) {
  return RecurringNotificationService();
});

/// Provider for checking recurring reminders.
final recurringReminderCheckProvider = FutureProvider<void>((ref) async {
  final notificationService = ref.watch(recurringNotificationServiceProvider);
  final db = ref.watch(databaseProvider);

  // Initialize notification service
  await notificationService.initialize();

  // Check and send reminders
  await notificationService.checkAndSendReminders(db: db, ref: ref);
  
  // Check for overdue
  await notificationService.checkAndNotifyOverdue(db: db);
});
