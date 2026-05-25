import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

/// Result of a biometric authentication attempt
enum BiometricAuthResult {
  success,
  failed,
  notAvailable,
  notEnrolled,
  lockedOut,
  permanentlyLockedOut,
  userCancel,
  fallbackRequested,
  error,
}

/// Service for handling platform biometric authentication
class BiometricService {
  final LocalAuthentication _localAuth;

  BiometricService({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  /// Check if device supports biometric authentication
  Future<bool> isDeviceSupported() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      return isSupported;
    } catch (e) {
      debugPrint('Error checking device support: $e');
      return false;
    }
  }

  /// Check if biometrics can be checked (hardware available and biometrics enrolled)
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      debugPrint('Error checking biometrics: $e');
      return false;
    }
  }

  /// Get list of available biometric types on the device
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Get the primary biometric type (first available)
  Future<BiometricType?> getPrimaryBiometricType() async {
    final biometrics = await getAvailableBiometrics();
    if (biometrics.isEmpty) return null;
    return biometrics.first;
  }

  /// Get human-readable name for biometric type
  String getBiometricTypeName(BiometricType type) {
    return switch (type) {
      BiometricType.fingerprint => '指纹',
      BiometricType.face => '面容',
      BiometricType.iris => '虹膜',
      BiometricType.weak => '弱生物识别',
      BiometricType.strong => '生物识别',
    };
  }

  /// Get icon name for biometric type
  String getBiometricIcon(BiometricType type) {
    return switch (type) {
      BiometricType.fingerprint => 'fingerprint',
      BiometricType.face => 'face',
      BiometricType.iris => 'visibility',
      BiometricType.weak => 'lock',
      BiometricType.strong => 'lock',
    };
  }

  /// Authenticate with biometrics
  /// 
  /// [localizedReason] - The reason to show in the authentication prompt
  /// [useFallback] - If true, allows fallback to device credentials (PIN/pattern/password)
  Future<BiometricAuthResult> authenticate({
    String localizedReason = '请验证身份以访问应用',
    bool useFallback = false,
  }) async {
    try {
      // Check if biometrics are available
      final canCheck = await canCheckBiometrics();
      if (!canCheck) {
        final isSupported = await isDeviceSupported();
        if (!isSupported) {
          return BiometricAuthResult.notAvailable;
        }
        return BiometricAuthResult.notEnrolled;
      }

      final result = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: !useFallback,
          useErrorDialogs: true,
        ),
      );

      if (result) {
        return BiometricAuthResult.success;
      } else {
        return BiometricAuthResult.failed;
      }
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      
      // Parse error types
      final errorString = e.toString().toLowerCase();
      if (errorString.contains(auth_error.notAvailable) ||
          errorString.contains('notavailable')) {
        return BiometricAuthResult.notAvailable;
      }
      if (errorString.contains(auth_error.notEnrolled) ||
          errorString.contains('notenrolled')) {
        return BiometricAuthResult.notEnrolled;
      }
      if (errorString.contains(auth_error.lockedOut) ||
          errorString.contains('lockedout')) {
        return BiometricAuthResult.lockedOut;
      }
      if (errorString.contains(auth_error.permanentlyLockedOut) ||
          errorString.contains('permanentlylockedout')) {
        return BiometricAuthResult.permanentlyLockedOut;
      }
      
      return BiometricAuthResult.error;
    }
  }

  /// Stop authentication if in progress
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      debugPrint('Error stopping authentication: $e');
    }
  }
}

/// Provider for BiometricService
final biometricServiceProvider = BiometricService();
