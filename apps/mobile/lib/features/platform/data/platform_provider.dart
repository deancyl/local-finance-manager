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
  windows,
  macOS,
  linux,
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

/// Windows-specific styling configuration
class WindowsStyling {
  // Font scaling for Windows (larger fonts for better readability)
  static const double fontScale = 1.15;
  
  // Sidebar width for desktop layout
  static const double sidebarWidth = 280.0;
  
  // Content padding
  static const double contentPadding = 24.0;
  
  // Card elevation
  static const double cardElevation = 2.0;
  
  // Border radius
  static const double borderRadius = 8.0;
  
  // Icon sizes
  static const double iconSizeSmall = 20.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  
  // Button sizes
  static const double buttonHeight = 40.0;
  static const double buttonMinWidth = 88.0;
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

  /// Check if running on Windows
  bool get isWindows => _platform == PlatformType.windows;
  
  /// Check if running on macOS
  bool get isMacOS => _platform == PlatformType.macOS;
  
  /// Check if running on Linux
  bool get isLinux => _platform == PlatformType.linux;
  
  /// Check if running on any desktop platform
  bool get isDesktop => isWindows || isMacOS || isLinux;

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
      case PlatformType.windows:
      case PlatformType.macOS:
      case PlatformType.linux:
      case PlatformType.desktop: // Legacy desktop type
        return 100;
      case PlatformType.unknown:
        return 30;
    }
  }

  /// Check if should use compact UI
  bool get shouldUseCompactUI {
    return _platform == PlatformType.mobile;
  }
  
  /// Get sidebar width for desktop layout
  double getSidebarWidth() {
    if (isDesktop) {
      return WindowsStyling.sidebarWidth;
    }
    return 0; // No sidebar on mobile
  }
  
  /// Get font scale for current platform
  double getFontScale() {
    if (isWindows) {
      return WindowsStyling.fontScale;
    }
    return 1.0;
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
  } else if (Platform.isWindows) {
    return PlatformType.windows;
  } else if (Platform.isMacOS) {
    return PlatformType.macOS;
  } else if (Platform.isLinux) {
    return PlatformType.linux;
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
    case PlatformType.windows:
    case PlatformType.macOS:
    case PlatformType.linux:
    case PlatformType.desktop: // Legacy desktop type
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
    case PlatformType.unknown:
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
