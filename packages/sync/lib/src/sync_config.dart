import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'models/sync_models.dart';
import 'security/certificate_pinning.dart';

/// PowerSync Schema placeholder.
/// 
/// Defined locally to avoid dependency on powersync package while sync is disabled.
class Schema {
  final List<dynamic> tables;
  
  const Schema([this.tables = const []]);
}

/// Result of an authentication operation.
class AuthResult {
  /// Whether the authentication was successful.
  final bool success;
  
  /// User ID if authentication succeeded.
  final String? userId;
  
  /// Authentication token if authentication succeeded.
  final String? token;
  
  /// Error message if authentication failed.
  final String? error;

  AuthResult({
    required this.success,
    this.userId,
    this.token,
    this.error,
  });

  /// Creates a successful auth result.
  factory AuthResult.success({
    required String userId,
    required String token,
  }) {
    return AuthResult(
      success: true,
      userId: userId,
      token: token,
    );
  }

  /// Creates a failed auth result.
  factory AuthResult.failure(String error) {
    return AuthResult(
      success: false,
      error: error,
    );
  }

  @override
  String toString() {
    if (success) {
      return 'AuthResult.success(userId: $userId)';
    }
    return 'AuthResult.failure($error)';
  }
}

/// Abstract interface for authentication providers.
/// 
/// Implementations provide authentication functionality for the sync system,
/// including token management, login/logout, and user identification.
abstract class AuthProvider {
  /// Gets the current authentication token, or null if not authenticated.
  Future<String?> getToken();

  /// Gets the current user ID, or null if not authenticated.
  Future<String?> getUserId();

  /// Returns true if the user is currently authenticated.
  Future<bool> isAuthenticated();

  /// Refreshes the authentication token if it's about to expire.
  /// 
  /// Throws an exception if refresh fails.
  Future<void> refreshToken();

  /// Attempts to log in with the provided credentials.
  /// 
  /// Returns an [AuthResult] indicating success or failure.
  Future<AuthResult> login(String email, String password);

  /// Attempts to register a new account with the provided credentials.
  /// 
  /// Returns an [AuthResult] indicating success or failure.
  Future<AuthResult> register(String email, String password);

  /// Logs out the current user and clears authentication state.
  Future<void> logout();
}

/// Configuration for PowerSync synchronization.
/// 
/// Contains all settings needed to establish and maintain a sync connection,
/// including server URL, database name, schema, and authentication.
class SyncConfig {
  /// The URL of the PowerSync sync server.
  final String serverUrl;
  
  /// The name of the local database.
  final String databaseName;
  
  /// The database schema for PowerSync.
  final Schema schema;
  
  /// The authentication provider for obtaining tokens.
  final AuthProvider authProvider;
  
  /// Unique identifier for this device.
  /// If null, a new ID will be generated on first use.
  final String? deviceId;
  
  /// Interval between automatic syncs in seconds.
  final int syncIntervalSeconds;
  
  /// Whether to auto-sync on startup.
  final bool autoSync;
  
  /// SSL certificate pinning configuration for secure connections.
  /// If null, certificate pinning is disabled.
  final CertificatePinningConfig? certificatePinning;

  SyncConfig({
    required this.serverUrl,
    required this.databaseName,
    required this.schema,
    required this.authProvider,
    this.deviceId,
    this.syncIntervalSeconds = 30,
    this.autoSync = true,
    this.certificatePinning,
  });

  // Storage keys for secure storage
  static const _keyServerUrl = 'sync_server_url';
  static const _keyDatabaseName = 'sync_database_name';
  static const _keyDeviceId = 'sync_device_id';
  static const _keyUserId = 'sync_user_id';
  static const _keyToken = 'sync_token';
  static const _keyTokenExpiry = 'sync_token_expiry';
  static const _keyPinnedCerts = 'sync_pinned_certs';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Loads sync configuration from secure storage.
  /// 
  /// Returns null if no configuration is stored or if required fields are missing.
  /// Note: This method only loads stored credentials; [schema] and [authProvider]
  /// must be provided separately when constructing a usable SyncConfig.
  static Future<SyncConfig?> fromStorage({
    required Schema schema,
    required AuthProvider authProvider,
    CertificatePinningConfig? certificatePinning,
  }) async {
    try {
      final serverUrl = await _storage.read(key: _keyServerUrl);
      final databaseName = await _storage.read(key: _keyDatabaseName);
      final deviceId = await _storage.read(key: _keyDeviceId);

      if (serverUrl == null || databaseName == null) {
        return null;
      }

      // Load pinned certificates if available
      CertificatePinningConfig? loadedPinning = certificatePinning;
      if (loadedPinning == null) {
        final pinnedCertsJson = await _storage.read(key: _keyPinnedCerts);
        if (pinnedCertsJson != null) {
          try {
            final List<dynamic> hashes = jsonDecode(pinnedCertsJson);
            if (hashes.isNotEmpty) {
              loadedPinning = CertificatePinningConfig(
                pinnedSha256Hashes: hashes.cast<String>(),
              );
            }
          } catch (e) {
            // Ignore parsing errors
          }
        }
      }

      return SyncConfig(
        serverUrl: serverUrl,
        databaseName: databaseName,
        schema: schema,
        authProvider: authProvider,
        deviceId: deviceId,
        certificatePinning: loadedPinning,
      );
    } catch (e) {
      // If there's any error reading from storage, return null
      return null;
    }
  }

  /// Saves this configuration to secure storage.
  /// 
  /// Stores server URL, database name, device ID, and pinned certificates securely.
  Future<void> save() async {
    final id = deviceId ?? const Uuid().v4();
    
    await _storage.write(key: _keyServerUrl, value: serverUrl);
    await _storage.write(key: _keyDatabaseName, value: databaseName);
    await _storage.write(key: _keyDeviceId, value: id);
    
    // Save pinned certificates if configured
    if (certificatePinning != null) {
      final hashes = certificatePinning!.pinnedSha256Hashes;
      await _storage.write(
        key: _keyPinnedCerts,
        value: jsonEncode(hashes),
      );
    }
  }

  /// Clears all sync-related data from secure storage.
  /// 
  /// This should be called when logging out or when resetting sync.
  static Future<void> clearStorage() async {
    await _storage.delete(key: _keyServerUrl);
    await _storage.delete(key: _keyDatabaseName);
    await _storage.delete(key: _keyDeviceId);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyTokenExpiry);
    await _storage.delete(key: _keyPinnedCerts);
  }

  /// Gets the stored device ID, generating a new one if needed.
  Future<String> getOrCreateDeviceId() async {
    if (deviceId != null) return deviceId!;
    
    final stored = await _storage.read(key: _keyDeviceId);
    if (stored != null) return stored;
    
    final newId = const Uuid().v4();
    await _storage.write(key: _keyDeviceId, value: newId);
    return newId;
  }

  /// Gets the PowerSync endpoint URL.
  String get powerSyncEndpoint {
    // Ensure serverUrl doesn't end with a slash
    final baseUrl = serverUrl.endsWith('/') 
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    return '$baseUrl/api/sync';
  }

  /// Creates a copy with optionally updated fields.
  SyncConfig copyWith({
    String? serverUrl,
    String? databaseName,
    Schema? schema,
    AuthProvider? authProvider,
    String? deviceId,
    int? syncIntervalSeconds,
    bool? autoSync,
    CertificatePinningConfig? certificatePinning,
  }) {
    return SyncConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      databaseName: databaseName ?? this.databaseName,
      schema: schema ?? this.schema,
      authProvider: authProvider ?? this.authProvider,
      deviceId: deviceId ?? this.deviceId,
      syncIntervalSeconds: syncIntervalSeconds ?? this.syncIntervalSeconds,
      autoSync: autoSync ?? this.autoSync,
      certificatePinning: certificatePinning ?? this.certificatePinning,
    );
  }

  /// Stores authentication credentials in secure storage.
  Future<void> saveAuthCredentials({
    required String userId,
    required String token,
    DateTime? expiresAt,
  }) async {
    await _storage.write(key: _keyUserId, value: userId);
    await _storage.write(key: _keyToken, value: token);
    if (expiresAt != null) {
      await _storage.write(
        key: _keyTokenExpiry,
        value: expiresAt.toIso8601String(),
      );
    }
  }

  /// Reads stored auth credentials.
  Future<({String? userId, String? token, DateTime? expiresAt})> 
      readAuthCredentials() async {
    final userId = await _storage.read(key: _keyUserId);
    final token = await _storage.read(key: _keyToken);
    final expiryStr = await _storage.read(key: _keyTokenExpiry);
    
    return (
      userId: userId,
      token: token,
      expiresAt: expiryStr != null ? DateTime.parse(expiryStr) : null,
    );
  }

  /// Clears stored auth credentials.
  Future<void> clearAuthCredentials() async {
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyTokenExpiry);
  }

  @override
  String toString() {
    return 'SyncConfig(serverUrl: $serverUrl, databaseName: $databaseName, '
        'deviceId: $deviceId, syncIntervalSeconds: $syncIntervalSeconds)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncConfig &&
        other.serverUrl == serverUrl &&
        other.databaseName == databaseName &&
        other.deviceId == deviceId &&
        other.syncIntervalSeconds == syncIntervalSeconds;
  }

  @override
  int get hashCode {
    return Object.hash(
      serverUrl,
      databaseName,
      deviceId,
      syncIntervalSeconds,
    );
  }
}
