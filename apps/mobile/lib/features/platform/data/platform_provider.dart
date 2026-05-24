import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

// ============================================================
// PLATFORM OPTIMIZATION MODELS
// ============================================================

/// Platform type
enum PlatformType {
  mobile,
  web,
  desktop,
  unknown,
}

/// Platform capabilities
class PlatformCapabilities {
  final bool supportsBiometrics;
  final bool supportsSecureStorage;
  final bool supportsBackgroundTasks;
  final bool supportsNotifications;
  final bool supportsCamera;
  final bool supportsFilePicker;
  final bool supportsSharing;
  final bool supportsHapticFeedback;

  const PlatformCapabilities({
    this.supportsBiometrics = false,
    this.supportsSecureStorage = false,
    this.supportsBackgroundTasks = false,
    this.supportsNotifications = false,
    this.supportsCamera = false,
    this.supportsFilePicker = false,
    this.supportsSharing = false,
    this.supportsHapticFeedback = false,
  });
}

/// Optimization settings
class OptimizationSettings {
  final bool enableLazyLoading;
  final bool enableCaching;
  final bool enableBackgroundSync;
  final bool enableImageCompression;
  final int cacheSizeMB;
  final int maxImageSizeKB;

  const OptimizationSettings({
    this.enableLazyLoading = true,
    this.enableCaching = true,
    this.enableBackgroundSync = true,
    this.enableImageCompression = true,
    this.cacheSizeMB = 100,
    this.maxImageSizeKB = 1024,
  });

  OptimizationSettings copyWith({
    bool? enableLazyLoading,
    bool? enableCaching,
    bool? enableBackgroundSync,
    bool? enableImageCompression,
    int? cacheSizeMB,
    int? maxImageSizeKB,
  }) {
    return OptimizationSettings(
      enableLazyLoading: enableLazyLoading ?? this.enableLazyLoading,
      enableCaching: enableCaching ?? this.enableCaching,
      enableBackgroundSync: enableBackgroundSync ?? this.enableBackgroundSync,
      enableImageCompression: enableImageCompression ?? this.enableImageCompression,
      cacheSizeMB: cacheSizeMB ?? this.cacheSizeMB,
      maxImageSizeKB: maxImageSizeKB ?? this.maxImageSizeKB,
    );
  }
}

// ============================================================
// PLATFORM SERVICE
// ============================================================

/// Service for platform-specific optimizations
class PlatformService {
  final PlatformType _platform;
  final PlatformCapabilities _capabilities;

  PlatformService(this._platform, this._capabilities);

  /// Get current platform type
  PlatformType get platform => _platform;

  /// Get platform capabilities
  PlatformCapabilities get capabilities => _capabilities;

  /// Check if platform supports a feature
  bool supportsFeature(String feature) {
    switch (feature) {
      case 'biometrics':
        return _capabilities.supportsBiometrics;
      case 'secureStorage':
        return _capabilities.supportsSecureStorage;
      case 'backgroundTasks':
        return _capabilities.supportsBackgroundTasks;
      case 'notifications':
        return _capabilities.supportsNotifications;
      case 'camera':
        return _capabilities.supportsCamera;
      case 'filePicker':
        return _capabilities.supportsFilePicker;
      case 'sharing':
        return _capabilities.supportsSharing;
      case 'hapticFeedback':
        return _capabilities.supportsHapticFeedback;
      default:
        return false;
    }
  }

  /// Get optimized page size for lists
  int getOptimizedPageSize() {
    switch (_platform) {
      case PlatformType.mobile:
        return 20;
      case PlatformType.web:
        return 50;
      case PlatformType.desktop:
        return 100;
      default:
        return 30;
    }
  }

  /// Check if should use compact UI
  bool get shouldUseCompactUI {
    return _platform == PlatformType.mobile;
  }

  /// Get default storage location
  String getDefaultStorageLocation() {
    if (Platform.isAndroid || Platform.isIOS) {
      return 'app_documents';
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return 'user_documents';
    }
    return 'browser_storage';
  }
}

// ============================================================
// PROVIDERS
// ============================================================

/// Provider for platform type
final platformTypeProvider = Provider<PlatformType>((ref) {
  if (kIsWeb) {
    return PlatformType.web;
  } else if (Platform.isAndroid || Platform.isIOS) {
    return PlatformType.mobile;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    return PlatformType.desktop;
  }
  return PlatformType.unknown;
});

/// Provider for platform capabilities
final platformCapabilitiesProvider = Provider<PlatformCapabilities>((ref) {
  final platform = ref.watch(platformTypeProvider);

  switch (platform) {
    case PlatformType.mobile:
      return const PlatformCapabilities(
        supportsBiometrics: true,
        supportsSecureStorage: true,
        supportsBackgroundTasks: true,
        supportsNotifications: true,
        supportsCamera: true,
        supportsFilePicker: true,
        supportsSharing: true,
        supportsHapticFeedback: true,
      );
    case PlatformType.desktop:
      return const PlatformCapabilities(
        supportsBiometrics: true,
        supportsSecureStorage: true,
        supportsBackgroundTasks: true,
        supportsNotifications: true,
        supportsCamera: true,
        supportsFilePicker: true,
        supportsSharing: true,
        supportsHapticFeedback: false,
      );
    case PlatformType.web:
      return const PlatformCapabilities(
        supportsBiometrics: false,
        supportsSecureStorage: false,
        supportsBackgroundTasks: false,
        supportsNotifications: true,
        supportsCamera: true,
        supportsFilePicker: false,
        supportsSharing: true,
        supportsHapticFeedback: true,
      );
    default:
      return const PlatformCapabilities();
  }
});

/// Provider for platform service
final platformServiceProvider = Provider<PlatformService>((ref) {
  final platform = ref.watch(platformTypeProvider);
  final capabilities = ref.watch(platformCapabilitiesProvider);
  return PlatformService(platform, capabilities);
});

/// Provider for optimization settings
final optimizationSettingsProvider = StateProvider<OptimizationSettings>((ref) {
  return const OptimizationSettings();
});
