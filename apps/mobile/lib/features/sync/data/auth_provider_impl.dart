import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'package:sync/sync.dart';

final _log = Logger('AuthProviderImpl');

/// Provider for the sync auth implementation.
final authProviderImplProvider = Provider<SyncAuthProviderImpl?>((ref) {
  // Auth provider is available but requires user to configure server URL
  // For now, return null until user sets up sync server
  return null;
});

/// Provider for stored auth token.
/// 
/// Returns the JWT token if available, null otherwise.
final storedAuthTokenProvider = FutureProvider<String?>((ref) async {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  return await storage.read(key: _keyToken);
});

/// Provider for stored user ID.
/// 
/// Returns the user ID if available, null otherwise.
final storedUserIdProvider = FutureProvider<String?>((ref) async {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  return await storage.read(key: _keyUserId);
});

/// Provider for checking if user is authenticated.
final isAuthenticatedProvider = FutureProvider<bool>((ref) async {
  final token = await ref.watch(storedAuthTokenProvider.future);
  return token != null;
});

/// Storage key for user ID.
const String _keyUserId = 'sync_user_id';

/// Storage key for auth token.
const String _keyToken = 'sync_token';

/// Storage key for refresh token.
const String _keyRefreshToken = 'sync_refresh_token';

/// Storage key for token expiry.
const String _keyTokenExpiry = 'sync_token_expiry';

/// Implementation of AuthProvider for the sync system.
/// 
/// Uses FlutterSecureStorage for secure token storage and
/// communicates with the sync server for authentication.
class SyncAuthProviderImpl implements AuthProvider {
  /// The sync server URL.
  final String serverUrl;
  
  /// Secure storage for tokens.
  final FlutterSecureStorage _storage;
  
  /// HTTP client for API calls.
  final http.Client _httpClient;
  
  SyncAuthProviderImpl({
    required this.serverUrl,
    FlutterSecureStorage? storage,
    http.Client? httpClient,
  })  : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        ),
        _httpClient = httpClient ?? http.Client();

  /// Logs in with email and password.
  @override
  Future<AuthResult> login(String email, String password) async {
    _log.info('Attempting login for: $email');
    
    try {
      final response = await _httpClient.post(
        Uri.parse('$serverUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        await _saveCredentials(
          userId: data['userId'] as String,
          token: data['token'] as String,
          refreshToken: data['refreshToken'] as String?,
          expiresAt: data['expiresAt'] != null
              ? DateTime.tryParse(data['expiresAt'] as String)
              : null,
        );

        _log.info('Login successful for user: ${data['userId']}');
        return AuthResult.success(
          userId: data['userId'] as String,
          token: data['token'] as String,
        );
      } else {
        final error = jsonDecode(response.body)['error'] as String? 
            ?? 'Login failed';
        _log.warning('Login failed: $error');
        return AuthResult.failure(error);
      }
    } catch (e) {
      _log.severe('Login network error: $e');
      return AuthResult.failure('Network error: $e');
    }
  }

  /// Registers a new account with email and password.
  @override
  Future<AuthResult> register(String email, String password) async {
    _log.info('Attempting registration for: $email');
    
    try {
      final response = await _httpClient.post(
        Uri.parse('$serverUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        await _saveCredentials(
          userId: data['userId'] as String,
          token: data['token'] as String,
          refreshToken: data['refreshToken'] as String?,
          expiresAt: data['expiresAt'] != null
              ? DateTime.tryParse(data['expiresAt'] as String)
              : null,
        );

        _log.info('Registration successful for user: ${data['userId']}');
        return AuthResult.success(
          userId: data['userId'] as String,
          token: data['token'] as String,
        );
      } else {
        final error = jsonDecode(response.body)['error'] as String? 
            ?? 'Registration failed';
        _log.warning('Registration failed: $error');
        return AuthResult.failure(error);
      }
    } catch (e) {
      _log.severe('Registration network error: $e');
      return AuthResult.failure('Network error: $e');
    }
  }

  /// Logs out and clears stored credentials.
  @override
  Future<void> logout() async {
    _log.info('Logging out...');
    
    try {
      final token = await getToken();
      if (token != null) {
        // Notify server of logout
        await _httpClient.post(
          Uri.parse('$serverUrl/api/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
    } catch (_) {
      _log.warning('Logout API call failed, proceeding with local logout');
    }
    
    await _clearCredentials();
    _log.info('Logout complete');
  }

  /// Gets the stored authentication token.
  @override
  Future<String?> getToken() async {
    return _storage.read(key: _keyToken);
  }

  /// Gets the stored user ID.
  @override
  Future<String?> getUserId() async {
    return _storage.read(key: _keyUserId);
  }

  /// Returns true if the user is authenticated.
  @override
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    if (token == null) return false;
    
    // Check if token is expired
    final expiryStr = await _storage.read(key: _keyTokenExpiry);
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry == null) return false;
      if (DateTime.now().isAfter(expiry)) {
        // Try to refresh
        try {
          await refreshToken();
          return true;
        } catch (_) {
          return false;
        }
      }
    }
    
    return true;
  }

  /// Refreshes the authentication token.
  @override
  Future<void> refreshToken() async {
    _log.info('Refreshing token...');
    
    final refreshToken = await _storage.read(key: _keyRefreshToken);
    if (refreshToken == null) {
      throw StateError('No refresh token available');
    }

    try {
      final response = await _httpClient.post(
        Uri.parse('$serverUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        await _saveCredentials(
          userId: data['userId'] as String,
          token: data['token'] as String,
          refreshToken: data['refreshToken'] as String?,
          expiresAt: data['expiresAt'] != null
              ? DateTime.tryParse(data['expiresAt'] as String)
              : null,
        );
        
        _log.info('Token refresh successful');
      } else {
        await _clearCredentials();
        throw Exception('Token refresh failed');
      }
    } catch (e) {
      await _clearCredentials();
      _log.severe('Token refresh failed: $e');
      rethrow;
    }
  }

  /// Saves credentials to secure storage.
  Future<void> _saveCredentials({
    required String userId,
    required String token,
    String? refreshToken,
    DateTime? expiresAt,
  }) async {
    await _storage.write(key: _keyUserId, value: userId);
    await _storage.write(key: _keyToken, value: token);
    
    if (refreshToken != null) {
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
    }
    
    if (expiresAt != null) {
      await _storage.write(key: _keyTokenExpiry, value: expiresAt.toIso8601String());
    }
  }

  /// Clears all stored credentials.
  Future<void> _clearCredentials() async {
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyTokenExpiry);
  }

  /// Disposes resources.
  void dispose() {
    _httpClient.close();
  }
}