/// Lazy loading utilities for performance optimization (v0.3.120)
/// 
/// Provides lazy initialization and deferred loading capabilities
/// to improve app startup time and memory usage.

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Lazy initializer that defers computation until first access.
/// 
/// Example:
/// ```dart
/// final expensiveData = LazyInitializer(() => computeExpensiveData());
/// // Data is not computed until expensiveData.value is accessed
/// ```
class LazyInitializer<T> {
  final Future<T> Function() _initializer;
  T? _value;
  bool _isInitialized = false;
  Future<T>? _initializationFuture;

  LazyInitializer(this._initializer);

  /// Gets the value, initializing it if necessary.
  Future<T> get value async {
    if (_isInitialized) {
      return _value as T;
    }

    // If initialization is in progress, wait for it
    if (_initializationFuture != null) {
      return _initializationFuture!;
    }

    // Start initialization
    _initializationFuture = _initializer();
    _value = await _initializationFuture;
    _isInitialized = true;
    _initializationFuture = null;
    return _value!;
  }

  /// Returns true if the value has been initialized.
  bool get isInitialized => _isInitialized;

  /// Resets the initializer, allowing it to be re-initialized.
  void reset() {
    _value = null;
    _isInitialized = false;
    _initializationFuture = null;
  }
}

/// Debouncer for rate-limiting expensive operations.
/// 
/// Useful for search inputs, auto-save, etc.
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({required this.delay});

  /// Runs the action after the delay, canceling any previous pending action.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancels any pending action.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Disposes the debouncer.
  void dispose() {
    cancel();
  }
}

/// Throttler for limiting the rate of function execution.
/// 
/// Unlike debouncing, throttling ensures the function runs
/// at most once per specified duration.
class Throttler {
  final Duration duration;
  DateTime? _lastRun;
  Timer? _timer;

  Throttler({required this.duration});

  /// Runs the action if enough time has passed since the last run.
  void run(VoidCallback action) {
    final now = DateTime.now();
    
    if (_lastRun == null || now.difference(_lastRun!) >= duration) {
      _lastRun = now;
      action();
    } else {
      // Schedule to run at the end of the throttle period
      _timer?.cancel();
      final remaining = duration - now.difference(_lastRun!);
      _timer = Timer(remaining, () {
        _lastRun = DateTime.now();
        action();
      });
    }
  }

  /// Disposes the throttler.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Memory-efficient cache with LRU eviction.
/// 
/// Automatically evicts least recently used items when the cache
/// exceeds the maximum size.
class LRUCache<K, V> {
  final int maxSize;
  final _cache = <K, V>{};
  final _accessOrder = <K>[];

  LRUCache({required this.maxSize});

  /// Gets a value from the cache, or null if not present.
  V? get(K key) {
    if (!_cache.containsKey(key)) return null;
    
    // Move to end (most recently used)
    _accessOrder.remove(key);
    _accessOrder.add(key);
    return _cache[key];
  }

  /// Puts a value in the cache.
  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      // Update existing
      _accessOrder.remove(key);
      _accessOrder.add(key);
      _cache[key] = value;
    } else {
      // Add new
      if (_cache.length >= maxSize) {
        // Evict least recently used
        final lruKey = _accessOrder.removeAt(0);
        _cache.remove(lruKey);
      }
      _cache[key] = value;
      _accessOrder.add(key);
    }
  }

  /// Removes a value from the cache.
  void remove(K key) {
    _cache.remove(key);
    _accessOrder.remove(key);
  }

  /// Clears the cache.
  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }

  /// Returns the current cache size.
  int get size => _cache.length;

  /// Returns true if the cache contains the key.
  bool containsKey(K key) => _cache.containsKey(key);
}

/// Deferred task queue for background initialization.
/// 
/// Queues tasks to run after the app has started,
/// improving perceived startup performance.
class DeferredTaskQueue {
  final _queue = <Future<void> Function()>[];
  bool _isProcessing = false;

  /// Adds a task to the queue.
  void add(Future<void> Function() task) {
    _queue.add(task);
    _processQueue();
  }

  /// Processes the queue one task at a time.
  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;
    
    _isProcessing = true;
    try {
      while (_queue.isNotEmpty) {
        final task = _queue.removeAt(0);
        try {
          await task();
        } catch (e) {
          // Log error but continue processing
          print('Deferred task error: $e');
        }
        // Small delay between tasks to avoid blocking UI
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Clears all pending tasks.
  void clear() {
    _queue.clear();
  }
}

/// Global deferred task queue instance.
final deferredTasks = DeferredTaskQueue();
