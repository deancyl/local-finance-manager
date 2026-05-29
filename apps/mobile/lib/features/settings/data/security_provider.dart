import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:io';
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

  /// Set a new password (stores PBKDF2 hash) (v0.3.188)
  Future<bool> setPassword(String password) async {
    if (password.length < 6) {
      return false;
    }
    
    // Use PBKDF2 with 100k iterations
    final hash = _hashPassword(password);
    await _secureStorage.write(key: _keyPasswordHash, value: hash);
    
    state = state.copyWith(hasPassword: true);
    return true;
  }

  /// Verify password with backward compatibility (v0.3.188)
  Future<bool> verifyPassword(String password) async {
    final storedHash = await _secureStorage.read(key: _keyPasswordHash);
    if (storedHash == null) return false;
    
    return _verifyPasswordHash(password, storedHash);
  }

  /// Set a new PIN (stores PBKDF2 hash) (v0.3.188)
  Future<bool> setPin(String pin) async {
    if (pin.length < 4 || pin.length > 6) {
      return false;
    }
    
    // Verify it's all digits
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      return false;
    }
    
    final hash = _hashPassword(pin);
    await _secureStorage.write(key: _keyPinHash, value: hash);
    
    state = state.copyWith(hasPin: true);
    return true;
  }

  /// Verify PIN with backward compatibility (v0.3.188)
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _secureStorage.read(key: _keyPinHash);
    if (storedHash == null) return false;
    
    return _verifyPasswordHash(pin, storedHash);
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

  /// Hash password using PBKDF2 with 100k iterations (v0.3.188)
  String _hashPassword(String input, {String? salt}) {
    salt ??= _generateSalt();
    const iterations = 100000;
    const keyLength = 32;
    
    try {
      final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
        ..init(Pbkdf2Parameters(
          Uint8List.fromList(utf8.encode(salt)),
          iterations,
          keyLength,
        ));
      
      final key = pbkdf2.process(Uint8List.fromList(utf8.encode(input)));
      final hashHex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      return '$salt:$hashHex';
    } catch (e) {
      debugPrint('PBKDF2 hashing failed, falling back to SHA-256: $e');
      // Fallback to SHA-256 if PBKDF2 fails
      final bytes = utf8.encode(input);
      final hash = sha256.convert(bytes);
      return hash.toString();
    }
  }
  
  /// Generate a random salt for PBKDF2
  String _generateSalt() {
    final random = DateTime.now().microsecondsSinceEpoch.toString() + 
                   const Uuid().v4();
    final bytes = utf8.encode(random);
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 16);
  }
  
  /// Verify password with backward compatibility for legacy SHA-256 (v0.3.188)
  bool _verifyPasswordHash(String input, String storedHash) {
    // Check if it's PBKDF2 format (salt:hash)
    if (storedHash.contains(':')) {
      final parts = storedHash.split(':');
      if (parts.length == 2) {
        final salt = parts[0];
        final newHash = _hashPassword(input, salt: salt);
        return newHash == storedHash;
      }
    }
    
    // Legacy SHA-256 verification
    final inputHash = _hashLegacySha256(input);
    return storedHash == inputHash;
  }
  
  /// Legacy SHA-256 hash for backward compatibility
  String _hashLegacySha256(String input) {
    final bytes = utf8.encode(input);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }
}

/// Provider for security settings state
final securityProvider = StateNotifierProvider<SecurityNotifier, SecuritySettings>((ref) {
  return SecurityNotifier();
});
