import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:core/core.dart' show BudgetPeriod, BudgetPeriodCalculator;

/// Background task identifier for budget checks.
const String _budgetCheckTask = 'budget_alert_check';

/// Callback dispatcher for workmanager.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case _budgetCheckTask:
        await _performBudgetCheck();
        break;
    }
    return Future.value(true);
  });
}

/// Perform budget check in background isolate.
Future<void> _performBudgetCheck() async {
  try {
    // Initialize database connection
    final db = await _openDatabase();
    
    // Get all active budgets
    final budgets = await db.budgetsDao.getAllActive();
    final now = DateTime.now();
    
    // Initialize notifications
    final notifications = FlutterLocalNotificationsPlugin();
    await _initializeNotifications(notifications);
    
    // Check each budget
    for (final budget in budgets) {
      if (!budget.alertEnabled) continue;
      
      // Calculate period bounds
      final period = _parseBudgetPeriod(budget.period);
      final (start, end) = BudgetPeriodCalculator.getCurrentPeriodBounds(
        period,
        now,
        customStart: DateTime.fromMillisecondsSinceEpoch(budget.startDate),
        customEnd: budget.endDate != null 
            ? DateTime.fromMillisecondsSinceEpoch(budget.endDate!) 
            : null,
      );
      
      final startMs = start.millisecondsSinceEpoch;
      final endMs = end.millisecondsSinceEpoch;
      
      // Calculate spending
      final spentNum = await db.budgetsDao.calculateSpentAmountNum(
        categoryId: budget.categoryId,
        startMs: startMs,
        endMs: endMs,
      );
      
      final spent = spentNum / 100.0;
      final budgetAmount = budget.amountNum / budget.amountDenom;
      
      if (budgetAmount <= 0) continue;
      
      final percentage = spent / budgetAmount;
      final percentageInt = (percentage * 100).round();
      
      // Get triggered alerts
      final prefs = await SharedPreferences.getInstance();
      final triggeredKey = 'budget_alerts_${budget.id}';
      final triggeredAlerts = prefs.getStringList(triggeredKey) ?? [];
      
      // Check thresholds
      final thresholds = [
        (50, budget.alertAt50),
        (75, budget.alertAt75),
        (90, budget.alertAt90),
        (100, budget.alertAt100),
      ];
      
      for (final (threshold, enabled) in thresholds) {
        if (!enabled) continue;
        if (percentageInt < threshold) continue;
        if (triggeredAlerts.contains(threshold.toString())) continue;
        
        // Show notification
        await _showBudgetNotification(
          notifications,
          budgetId: budget.id,
          budgetName: budget.name,
          spentAmount: spent,
          budgetAmount: budgetAmount,
          percentage: percentage,
          threshold: threshold,
        );
        
        // Mark as triggered
        triggeredAlerts.add(threshold.toString());
        await prefs.setStringList(triggeredKey, triggeredAlerts);
      }
    }
    
    await db.close();
  } catch (e) {
    debugPrint('Background budget check failed: $e');
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

/// Show budget notification from background.
Future<void> _showBudgetNotification(
  FlutterLocalNotificationsPlugin notifications, {
  required String budgetId,
  required String budgetName,
  required double spentAmount,
  required double budgetAmount,
  required double percentage,
  required int threshold,
}) async {
  final percentageInt = (percentage * 100).round();
  final title = _getAlertTitle(threshold, percentageInt);
  final body = _getAlertBody(budgetName, spentAmount, budgetAmount, percentageInt);
  
  const androidDetails = AndroidNotificationDetails(
    'budget_alerts',
    '预算提醒',
    channelDescription: '预算使用进度提醒通知',
    importance: Importance.high,
    priority: Priority.high,
  );
  const iosDetails = DarwinNotificationDetails();
  const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
  
  await notifications.show(
    budgetId.hashCode,
    title,
    body,
    details,
    payload: jsonEncode({
      'type': 'budget_alert',
      'budgetId': budgetId,
      'threshold': threshold,
    }),
  );
}

String _getAlertTitle(int threshold, int percentage) {
  if (threshold >= 100) {
    return '⚠️ 预算已用完';
  } else if (threshold >= 90) {
    return '🔴 预算即将用完 ($percentage%)';
  } else if (threshold >= 75) {
    return '🟠 预算使用警告 ($percentage%)';
  } else {
    return '🟡 预算使用提醒 ($percentage%)';
  }
}

String _getAlertBody(String budgetName, double spent, double budget, int percentage) {
  final remaining = budget - spent;
  if (remaining < 0) {
    return '$budgetName 已超出预算 ¥${(-remaining).toStringAsFixed(2)}\n'
        '已用: ¥${spent.toStringAsFixed(2)} / ¥${budget.toStringAsFixed(2)}';
  }
  return '$budgetName 已使用 $percentage%\n'
      '已用: ¥${spent.toStringAsFixed(2)} / ¥${budget.toStringAsFixed(2)}\n'
      '剩余: ¥${remaining.toStringAsFixed(2)}';
}

BudgetPeriod _parseBudgetPeriod(String period) {
  switch (period) {
    case 'MONTHLY':
      return BudgetPeriod.monthly;
    case 'YEARLY':
      return BudgetPeriod.yearly;
    case 'CUSTOM':
      return BudgetPeriod.custom;
    default:
      return BudgetPeriod.monthly;
  }
}

/// Open database connection for background task.
Future<dynamic> _openDatabase() async {
  // This is a simplified version - in production, use the actual database setup
  // with proper encryption support
  final dbFolder = await getApplicationDocumentsDirectory();
  final file = dbFolder.child('finance.db');
  
  // Note: For encrypted database, you'd need to handle the key retrieval
  // This is a placeholder for the background isolate database access
  final executor = NativeDatabase.createInBackground(file);
  
  // Return a minimal database instance
  // In production, this should be the actual LocalFinanceDatabase
  throw UnimplementedError('Database access in background isolate requires proper setup');
}

/// Background budget checker manager.
class BackgroundBudgetChecker {
  static final BackgroundBudgetChecker _instance = BackgroundBudgetChecker._internal();
  factory BackgroundBudgetChecker() => _instance;
  BackgroundBudgetChecker._internal();

  bool _initialized = false;

  /// Initialize background budget checking.
  Future<void> initialize() async {
    if (_initialized) return;

    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );

    _initialized = true;
  }

  /// Register periodic budget check task.
  /// Runs every hour to check budget status.
  Future<void> registerPeriodicCheck() async {
    if (!_initialized) await initialize();

    await Workmanager().registerPeriodicTask(
      _budgetCheckTask,
      _budgetCheckTask,
      frequency: const Duration(hours: 1),
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

  /// Cancel periodic budget check.
  Future<void> cancelPeriodicCheck() async {
    await Workmanager().cancelByUniqueName(_budgetCheckTask);
  }

  /// Run a one-time budget check.
  Future<void> runOneTimeCheck() async {
    if (!_initialized) await initialize();

    await Workmanager().registerOneOffTask(
      _budgetCheckTask,
      _budgetCheckTask,
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }
}
