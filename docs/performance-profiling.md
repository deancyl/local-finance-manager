# Performance Profiling Guide

## Overview

This document provides guidelines for profiling and optimizing the Local Finance Manager application.

## Flutter DevTools

### CPU Profiling

1. Run the app in profile mode:
   ```bash
   flutter run --profile
   ```

2. Open DevTools:
   ```bash
   flutter pub global activate devtools
   flutter pub global run devtools
   ```

3. Connect to the running app and select "Performance" tab

4. Record performance traces during:
   - App startup
   - Transaction list loading
   - Report generation
   - Import operations

### Memory Profiling

1. In DevTools, select "Memory" tab

2. Track memory allocations during:
   - Large transaction imports
   - Report generation with charts
   - Multiple account viewing

3. Identify memory leaks:
   - Check for retained objects after page navigation
   - Verify provider disposal
   - Monitor widget tree growth

## Database Profiling

### Query Timing

Add timing logs to DAO methods:

```dart
Future<List<Transaction>> getTransactions() async {
  final stopwatch = Stopwatch()..start();
  final result = await select(transactions).get();
  stopwatch.stop();
  log('Query took: ${stopwatch.elapsedMilliseconds}ms');
  return result;
}
```

### SQLite Profiling

Enable SQLite query logging:

```dart
// In database initialization
 driftingDatabase.executor.logLevel = LogLevel.calls;
```

### Index Verification

Check index usage:

```sql
EXPLAIN QUERY PLAN SELECT * FROM transactions WHERE date BETWEEN ? AND ?;
```

## Performance Baselines

### Startup Time Targets

| Platform | Target | Current |
|----------|--------|---------|
| Android | < 2s | ~1.5s |
| iOS | < 1.5s | ~1.2s |
| Web | < 3s | ~2.5s |

### Memory Usage Targets

| Platform | Target | Current |
|----------|--------|---------|
| Android | < 100MB | ~80MB |
| iOS | < 80MB | ~60MB |
| Web | < 150MB | ~120MB |

### Database Query Targets

| Operation | Target | Current |
|-----------|--------|---------|
| 1000 transactions list | < 100ms | ~50ms |
| Monthly report | < 500ms | ~200ms |
| Import 100 transactions | < 1s | ~0.8s |

## Profiling Checklist

### Before Optimization

- [ ] Establish performance baseline
- [ ] Identify bottlenecks with DevTools
- [ ] Profile database queries
- [ ] Check memory allocation patterns

### Optimization Areas

- [ ] Lazy loading (pagination implemented in v0.3.15)
- [ ] Provider disposal (verified in v0.3.120)
- [ ] Database indexes (check schema v16)
- [ ] Widget rebuild optimization
- [ ] Chart rendering optimization

### After Optimization

- [ ] Verify improvements meet targets
- [ ] Document new baselines
- [ ] Add regression tests
- [ ] Update performance documentation

## Platform-Specific Tips

### Android

1. Use `flutter run --profile` for accurate measurements
2. Check APK size with `flutter build apk --analyze-size`
3. Profile with Android Studio Profiler for native calls

### iOS

1. Use Xcode Instruments for detailed native profiling
2. Check frame rates with CADebugPrintFPS
3. Profile Metal rendering for charts

### Web

1. Use Chrome DevTools Performance tab
2. Check WASM performance for database operations
3. Profile network requests for potential sync

## Performance Regression Testing

### Test Scenarios

1. **Startup Test**: Measure app launch time
2. **Scroll Test**: Measure transaction list scroll smoothness
3. **Import Test**: Measure 1000 transaction import time
4. **Report Test**: Measure monthly report generation time

### CI Integration

Add performance tests to CI pipeline:

```yaml
performance_test:
  steps:
    - run: flutter drive --target=test_driver/performance.dart
    - run: dart scripts/check_performance_baseline.dart
```

## References

- [Flutter Performance Documentation](https://docs.flutter.dev/performance)
- [Drift Database Optimization](https://drift.simonbinder.eu/docs/advanced-features/benchmarking/)
- [fl_chart Performance](https://github.com/islide-flutter/fl_chart#performance)