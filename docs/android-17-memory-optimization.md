# Android 17 Memory Optimization

This document describes memory optimization strategies for Android 17+ compatibility.

## Image Cache Optimization

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
    PaintingBinding.instance.imageCache.clear();
  }
}
```

## ListView Optimization

Use `ListView.builder` with pagination and appropriate `cacheExtent`.

## Memory Pressure Handling

Clear caches when app goes to background.

## Best Practices

1. Use `memCacheWidth/memCacheHeight` for images
2. Use `ListView.builder` with pagination
3. Set appropriate cache limits (50MB)
4. Clear cache on memory pressure

---

*Document generated: 2026-05-27*