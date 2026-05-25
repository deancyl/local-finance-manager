/// Memory optimization utilities (v0.3.120)
/// 
/// Provides memory management, caching, and resource cleanup
/// to reduce memory footprint and prevent memory leaks.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Memory manager for tracking and cleaning up resources.
class MemoryManager {
  static final MemoryManager _instance = MemoryManager._internal();
  factory MemoryManager() => _instance;
  MemoryManager._internal();

  final _resources = <String, WeakReference<Disposable>>{};
  Timer? _cleanupTimer;

  /// Registers a disposable resource for tracking.
  void register(String id, Disposable resource) {
    _resources[id] = WeakReference(resource);
    _startPeriodicCleanup();
  }

  /// Unregisters a resource.
  void unregister(String id) {
    _resources.remove(id);
  }

  /// Starts periodic cleanup of disposed resources.
  void _startPeriodicCleanup() {
    _cleanupTimer ??= Timer.periodic(
      const Duration(minutes: 5),
      (_) => _cleanup(),
    );
  }

  /// Cleans up disposed resources.
  void _cleanup() {
    final deadKeys = <String>[];
    
    _resources.forEach((key, ref) {
      final target = ref.target;
      if (target == null || target.isDisposed) {
        deadKeys.add(key);
      }
    });

    for (final key in deadKeys) {
      _resources.remove(key);
    }
  }

  /// Forces immediate cleanup.
  void forceCleanup() {
    _cleanup();
  }

  /// Disposes the memory manager.
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _resources.clear();
  }
}

/// Interface for disposable resources.
abstract class Disposable {
  bool get isDisposed;
  void dispose();
}

/// Memory-efficient provider that auto-disposes when not in use.
/// 
/// Use this for large data providers that should be cleaned up
/// when the user navigates away.
class AutoDisposeCacheNotifier<T> extends StateNotifier<AsyncValue<T>> implements Disposable {
  final Future<T> Function() _loader;
  final Duration _keepAliveDuration;
  Timer? _keepAliveTimer;
  bool _isDisposed = false;

  AutoDisposeCacheNotifier({
    required Future<T> Function() loader,
    Duration keepAliveDuration = const Duration(minutes: 5),
  })  : _loader = loader,
        _keepAliveDuration = keepAliveDuration,
        super(const AsyncValue.loading()) {
    MemoryManager().register('cache_${hashCode}', this);
  }

  /// Loads the data.
  Future<void> load() async {
    if (_isDisposed) return;
    
    _keepAliveTimer?.cancel();
    state = const AsyncValue.loading();
    
    try {
      final data = await _loader();
      if (!_isDisposed) {
        state = AsyncValue.data(data);
        _startKeepAliveTimer();
      }
    } catch (e, st) {
      if (!_isDisposed) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// Refreshes the data.
  Future<void> refresh() async {
    await load();
  }

  void _startKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer(_keepAliveDuration, () {
      // Clear the data after keep-alive duration
      if (!_isDisposed) {
        state = const AsyncValue.loading();
      }
    });
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    _isDisposed = true;
    _keepAliveTimer?.cancel();
    MemoryManager().unregister('cache_${hashCode}');
    super.dispose();
  }
}

/// Stream subscription manager for preventing memory leaks.
class SubscriptionManager implements Disposable {
  final _subscriptions = <StreamSubscription>[];
  bool _isDisposed = false;

  /// Adds a subscription to be managed.
  void add(StreamSubscription subscription) {
    if (_isDisposed) {
      subscription.cancel();
      return;
    }
    _subscriptions.add(subscription);
  }

  /// Cancels all subscriptions.
  void cancelAll() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    _isDisposed = true;
    cancelAll();
  }
}

/// Object pool for reusing expensive-to-create objects.
/// 
/// Useful for objects like formatters, parsers, etc.
class ObjectPool<T> {
  final T Function() _factory;
  final void Function(T)? _resetter;
  final int _maxSize;
  final _pool = <T>[];

  ObjectPool({
    required T Function() factory,
    void Function(T)? resetter,
    int maxSize = 10,
  })  : _factory = factory,
        _resetter = resetter,
        _maxSize = maxSize;

  /// Gets an object from the pool or creates a new one.
  T acquire() {
    if (_pool.isNotEmpty) {
      return _pool.removeLast();
    }
    return _factory();
  }

  /// Returns an object to the pool.
  void release(T object) {
    if (_pool.length < _maxSize) {
      _resetter?.call(object);
      _pool.add(object);
    }
  }

  /// Clears the pool.
  void clear() {
    _pool.clear();
  }
}

/// Memory pressure handler for responding to low memory situations.
class MemoryPressureHandler {
  static final MemoryPressureHandler _instance = MemoryPressureHandler._internal();
  factory MemoryPressureHandler() => _instance;
  MemoryPressureHandler._internal();

  final _handlers = <VoidCallback>[];

  /// Registers a handler to be called on memory pressure.
  void registerHandler(VoidCallback handler) {
    _handlers.add(handler);
  }

  /// Unregisters a handler.
  void unregisterHandler(VoidCallback handler) {
    _handlers.remove(handler);
  }

  /// Handles a memory pressure event.
  void handleMemoryPressure() {
    for (final handler in _handlers) {
      try {
        handler();
      } catch (e) {
        print('Memory pressure handler error: $e');
      }
    }
  }
}

typedef VoidCallback = void Function();
