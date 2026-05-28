import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../../security/data/biometric_service.dart';

/// Security settings state
class SecuritySettings {
  final bool isPasswordEnabled;
  final bool isPinEnabled;
  final bool isBiometricEnabled;
  final bool canCheckBiometrics;
  final int autoLockTimeoutMinutes;
  final bool hasPassword;
  final bool hasPin;

  const SecuritySettings({
    this.isPasswordEnabled = false,
    this.isPinEnabled = false,
    this.isBiometricEnabled = false,
    this.canCheckBiometrics = false,
    this.autoLockTimeoutMinutes = 5,
    this.hasPassword = false,
    this.hasPin = false,
  });

  SecuritySettings copyWith({
    bool? isPasswordEnabled,
    bool? isPinEnabled,
    bool? isBiometricEnabled,
    bool? canCheckBiometrics,
    int? autoLockTimeoutMinutes,
    bool? hasPassword,
    bool? hasPin,
  }) {
    return SecuritySettings(
      isPasswordEnabled: isPasswordEnabled ?? this.isPasswordEnabled,
      isPinEnabled: isPinEnabled ?? this.isPinEnabled,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      canCheckBiometrics: canCheckBiometrics ?? this.canCheckBiometrics,
      autoLockTimeoutMinutes: autoLockTimeoutMinutes ?? this.autoLockTimeoutMinutes,
      hasPassword: hasPassword ?? this.hasPassword,
      hasPin: hasPin ?? this.hasPin,
    );
  }
}

/// Notifier for managing security settings
class SecurityNotifier extends StateNotifier<SecuritySettings> {
  static const _keyPasswordEnabled = 'security_password_enabled';
  static const _keyPinEnabled = 'security_pin_enabled';
  static const _keyBiometricEnabled = 'security_biometric_enabled';
  static const _keyAutoLockTimeout = 'security_auto_lock_timeout';
  static const _keyPasswordHash = 'security_password_hash';
  static const _keyPinHash = 'security_pin_hash';
  
  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth;

  SecurityNotifier({
    FlutterSecureStorage? secureStorage,
    LocalAuthentication? localAuth,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication(),
        super(const SecuritySettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if biometrics are available
    bool canCheckBiometrics = false;
    try {
      canCheckBiometrics = await _localAuth.canCheckBiometrics;
    } catch (e) {
      debugPrint('Error checking biometrics: $e');
    }

    // Check if password/PIN exist
    final passwordHash = await _secureStorage.read(key: _keyPasswordHash);
    final pinHash = await _secureStorage.read(key: _keyPinHash);

    state = SecuritySettings(
      isPasswordEnabled: prefs.getBool(_keyPasswordEnabled) ?? false,
      isPinEnabled: prefs.getBool(_keyPinEnabled) ?? false,
      isBiometricEnabled: prefs.getBool(_keyBiometricEnabled) ?? false,
      canCheckBiometrics: canCheckBiometrics,
      autoLockTimeoutMinutes: prefs.getInt(_keyAutoLockTimeout) ?? 5,
      hasPassword: passwordHash != null && passwordHash.isNotEmpty,
      hasPin: pinHash != null && pinHash.isNotEmpty,
    );
  }

  Future<void> setPasswordEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPasswordEnabled, enabled);
    state = state.copyWith(isPasswordEnabled: enabled);
  }

  Future<void> setPinEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPinEnabled, enabled);
    state = state.copyWith(isPinEnabled: enabled);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);
    state = state.copyWith(isBiometricEnabled: enabled);
  }

  Future<void> setAutoLockTimeout(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAutoLockTimeout, minutes);
    state = state.copyWith(autoLockTimeoutMinutes: minutes);
  }

  /// Set a new password (stores hash only)
  Future<bool> setPassword(String password) async {
    if (password.length < 6) {
      return false;
    }
    
    // Use PBKDF2 with secure salt
    final hash = _hashPasswordPBKDF2(password);
    await _secureStorage.write(key: _keyPasswordHash, value: hash);
    
    state = state.copyWith(hasPassword: true);
    return true;
  }

  /// Verify password
  Future<bool> verifyPassword(String password) async {
    final storedHash = await _secureStorage.read(key: _keyPasswordHash);
    if (storedHash == null) return false;
    
    // Check if it's new PBKDF2 format or old simple hash
    if (storedHash.startsWith('pbkdf2:')) {
      return _verifyPBKDF2(password, storedHash);
    } else {
      // Legacy simple hash verification
      final inputHash = _hashPasswordLegacy(password);
      return storedHash == inputHash;
    }
  }

  /// Set a new PIN
  Future<bool> setPin(String pin) async {
    if (pin.length < 4 || pin.length > 6) {
      return false;
    }
    
    // Verify it's all digits
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      return false;
    }
    
    final hash = _hashPasswordPBKDF2(pin);
    await _secureStorage.write(key: _keyPinHash, value: hash);
    
    state = state.copyWith(hasPin: true);
    return true;
  }

  /// Verify PIN
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _secureStorage.read(key: _keyPinHash);
    if (storedHash == null) return false;
    
    // Check if it's new PBKDF2 format or old simple hash
    if (storedHash.startsWith('pbkdf2:')) {
      return _verifyPBKDF2(pin, storedHash);
    } else {
      // Legacy simple hash verification
      final inputHash = _hashPasswordLegacy(pin);
      return storedHash == inputHash;
    }
  }

  /// Clear password
  Future<void> clearPassword() async {
    await _secureStorage.delete(key: _keyPasswordHash);
    await setPasswordEnabled(false);
    state = state.copyWith(hasPassword: false, isPasswordEnabled: false);
  }

  /// Clear PIN
  Future<void> clearPin() async {
    await _secureStorage.delete(key: _keyPinHash);
    await setPinEnabled(false);
    state = state.copyWith(hasPin: false, isPinEnabled: false);
  }

  /// Authenticate with biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: '请验证身份以访问应用',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting biometrics: $e');
      return [];
    }
  }

  /// Legacy simple hash function (for backward compatibility)
  String _hashPasswordLegacy(String input) {
    final bytes = utf8.encode(input);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// PBKDF2 hash function with secure salt
  /// Format: pbkdf2:salt:iterations:hash
  String _hashPasswordPBKDF2(String password) {
    const iterations = 100000;
    const keyLength = 32; // 32 bytes = 256 bits
    
    // Generate secure random salt
    final salt = _generateSalt();
    final saltBase64 = base64Url.encode(salt);
    
    // Derive key using PBKDF2
    final hash = _deriveKey(password, salt, iterations, keyLength);
    final hashBase64 = base64Url.encode(hash);
    
    return 'pbkdf2:$saltBase64:$iterations:$hashBase64';
  }

  /// Verify PBKDF2 hash
  bool _verifyPBKDF2(String password, String storedHash) {
    try {
      final parts = storedHash.split(':');
      if (parts.length != 4 || parts[0] != 'pbkdf2') {
        return false;
      }
      
      final saltBase64 = parts[1];
      final iterations = int.parse(parts[2]);
      final hashBase64 = parts[3];
      
      final salt = base64Url.decode(saltBase64);
      final storedHashBytes = base64Url.decode(hashBase64);
      
      // Derive key with same parameters
      final derivedHash = _deriveKey(password, salt, iterations, storedHashBytes.length);
      
      // Constant-time comparison
      return _constantTimeEquals(derivedHash, storedHashBytes);
    } catch (e) {
      debugPrint('PBKDF2 verification error: $e');
      return false;
    }
  }

  /// Generate a random 32-byte salt using secure random
  Uint8List _generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
  }

  /// Derive key using PBKDF2 with SHA-256
  Uint8List _deriveKey(String password, Uint8List salt, int iterations, int keyLength) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, keyLength));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Constant-time comparison to prevent timing attacks
  bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}

/// Provider for security settings state
final securityProvider = StateNotifierProvider<SecurityNotifier, SecuritySettings>((ref) {
  return SecurityNotifier();
});
