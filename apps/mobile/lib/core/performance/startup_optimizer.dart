/// Startup optimization service (v0.3.120)
/// 
/// Provides deferred initialization and startup performance tracking
/// to improve app launch time.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Startup phases for performance tracking.
enum StartupPhase {
  appInit,
  databaseInit,
  providersInit,
  uiInit,
  complete,
}

/// Startup performance tracker.
class StartupTracker {
  static final StartupTracker _instance = StartupTracker._internal();
  factory StartupTracker() => _instance;
  StartupTracker._internal();

  final _phaseStartTimes = <StartupPhase, int>{};
  final _phaseDurations = <StartupPhase, int>{};
  int _appStartTime = 0;

  /// Marks the start of the app.
  void markAppStart() {
    _appStartTime = DateTime.now().millisecondsSinceEpoch;
  }

  /// Marks the start of a phase.
  void markPhaseStart(StartupPhase phase) {
    _phaseStartTimes[phase] = DateTime.now().millisecondsSinceEpoch;
  }

  /// Marks the end of a phase.
  void markPhaseEnd(StartupPhase phase) {
    final startTime = _phaseStartTimes[phase];
    if (startTime != null) {
      _phaseDurations[phase] = DateTime.now().millisecondsSinceEpoch - startTime;
      _phaseStartTimes.remove(phase);
    }
  }

  /// Gets the total startup time in milliseconds.
  int get totalStartupTime {
    if (_appStartTime == 0) return 0;
    return DateTime.now().millisecondsSinceEpoch - _appStartTime;
  }

  /// Gets the duration of a phase in milliseconds.
  int? getPhaseDuration(StartupPhase phase) => _phaseDurations[phase];

  /// Prints startup statistics.
  void printStats() {
    if (kDebugMode) {
      print('=== Startup Performance ===');
      print('Total time: ${totalStartupTime}ms');
      for (final phase in StartupPhase.values) {
        final duration = _phaseDurations[phase];
        if (duration != null) {
          print('${phase.name}: ${duration}ms');
        }
      }
      print('===========================');
    }
  }
}

/// Startup task priority levels.
enum StartupPriority {
  /// Must run before app is visible
  critical,
  /// Should run soon after app is visible
  high,
  /// Can be deferred until idle
  normal,
  /// Can wait until explicitly needed
  low,
}

/// Deferred initialization task.
class DeferredTask {
  final String name;
  final Future<void> Function() task;
  final StartupPriority priority;
  bool _isComplete = false;

  DeferredTask({
    required this.name,
    required this.task,
    this.priority = StartupPriority.normal,
  });

  bool get isComplete => _isComplete;

  Future<void> run() async {
    if (_isComplete) return;
    
    try {
      await task();
      _isComplete = true;
    } catch (e) {
      print('Deferred task "$name" failed: $e');
    }
  }
}

/// Startup optimization manager.
class StartupOptimizer {
  static final StartupOptimizer _instance = StartupOptimizer._internal();
  factory StartupOptimizer() => _instance;
  StartupOptimizer._internal();

  final _criticalTasks = <DeferredTask>[];
  final _highTasks = <DeferredTask>[];
  final _normalTasks = <DeferredTask>[];
  final _lowTasks = <DeferredTask>[];
  
  bool _isInitialized = false;
  bool _isRunningDeferred = false;
  final _onComplete = <Completer<void>>[];

  /// Registers a task for deferred initialization.
  void registerTask(DeferredTask task) {
    switch (task.priority) {
      case StartupPriority.critical:
        _criticalTasks.add(task);
        break;
      case StartupPriority.high:
        _highTasks.add(task);
        break;
      case StartupPriority.normal:
        _normalTasks.add(task);
        break;
      case StartupPriority.low:
        _lowTasks.add(task);
        break;
    }
  }

  /// Runs critical initialization tasks.
  /// Call this before showing the UI.
  Future<void> runCriticalTasks() async {
    if (_isInitialized) return;
    
    final tracker = StartupTracker();
    tracker.markPhaseStart(StartupPhase.appInit);
    
    for (final task in _criticalTasks) {
      await task.run();
    }
    
    tracker.markPhaseEnd(StartupPhase.appInit);
    _isInitialized = true;
  }

  /// Runs deferred tasks in the background after app is visible.
  /// Call this after the first frame is rendered.
  Future<void> runDeferredTasks() async {
    if (_isRunningDeferred) return;
    _isRunningDeferred = true;

    try {
      // Run high priority tasks first
      for (final task in _highTasks) {
        await task.run();
        // Yield to UI between tasks
        await Future.delayed(Duration.zero);
      }

      // Run normal priority tasks
      for (final task in _normalTasks) {
        await task.run();
        // Yield to UI between tasks
        await Future.delayed(Duration.zero);
      }

      // Run low priority tasks last
      for (final task in _lowTasks) {
        await task.run();
        // Yield to UI between tasks
        await Future.delayed(Duration.zero);
      }

      // Notify all waiters
      for (final completer in _onComplete) {
        completer.complete();
      }
      _onComplete.clear();
    } finally {
      _isRunningDeferred = false;
    }
  }

  /// Waits for all deferred tasks to complete.
  Future<void> waitForCompletion() async {
    if (!_isRunningDeferred) return;
    
    final completer = Completer<void>();
    _onComplete.add(completer);
    await completer.future;
  }

  /// Checks if a specific task is complete.
  bool isTaskComplete(String name) {
    return [..._criticalTasks, ..._highTasks, ..._normalTasks, ..._lowTasks]
        .firstWhere((t) => t.name == name, orElse: () => DeferredTask(name: '', task: () async {}))
        .isComplete;
  }
}

/// Startup optimizer provider for use with Riverpod.
final startupOptimizerProvider = Provider<StartupOptimizer>((ref) {
  return StartupOptimizer();
});

/// Startup tracker provider for use with Riverpod.
final startupTrackerProvider = Provider<StartupTracker>((ref) {
  return StartupTracker();
});