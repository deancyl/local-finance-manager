# Android 17 Memory Optimization

This document describes memory optimization strategies for Android 17+ compatibility.

## Image Cache Optimization

### Configuring Image Cache

```dart
class MemoryOptimizedImageCache {
  static const int maxCacheSizeBytes = 50 * 1024 * 1024;
  static const int maxObjects = 100;
  
  static void configure() {
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.maximumSize = maxObjects;
    imageCache.maximumSizeBytes = maxCacheSizeBytes;
  }
  
  static void onMemoryPressure() {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
  }
}
```

### Memory-Aware Image Loading

```dart
CachedNetworkImage(
  imageUrl: imageUrl,
  memCacheWidth: (width * 2).toInt(),
  memCacheHeight: (height * 2).toInt(),
)
```

## ListView Optimization

### Lazy Loading

```dart
ListView.builder(
  itemCount: transactions.length,
  cacheExtent: 500,
  itemBuilder: (context, index) {
    return TransactionTile(
      key: ValueKey(transactions[index].id),
      transaction: transactions[index],
    );
  },
)
```

### Pagination

Implement pagination for large lists to limit memory usage.

## Memory Pressure Handling

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused) {
    MemoryOptimizedImageCache.onMemoryPressure();
  }
}
```

## Best Practices

1. Use `memCacheWidth/memCacheHeight` for images
2. Use `ListView.builder` with pagination
3. Set appropriate cache limits (50MB)
4. Clear cache on memory pressure
5. Dispose controllers properly

---

*Document generated: 2026-05-27*