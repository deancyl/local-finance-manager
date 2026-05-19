import 'dart:convert';

import 'package:powersync/powersync.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../sync_config.dart' show AuthProvider;

/// Backend connector for PowerSync authentication and data upload.
/// 
/// Handles:
/// - Authentication token refresh
/// - Uploading local changes to the backend
/// - Error handling and retry logic
class FinanceAppConnector extends PowerSyncBackendConnector {
  final String serverUrl;
  final AuthProvider? authProvider;
  final PowerSyncDatabase? powerSyncDb;
  final http.Client _httpClient;
  final Logger _log = Logger('FinanceAppConnector');
  
  String? _currentToken;
  DateTime? _tokenExpiry;
  String? _deviceId;

  FinanceAppConnector({
    required this.serverUrl,
    this.authProvider,
    this.powerSyncDb,
    http.Client? httpClient,
    String? deviceId,
  })  : _httpClient = httpClient ?? http.Client(),
        _deviceId = deviceId;

  /// Sets the authentication token manually.
  void setToken(String token, {DateTime? expiry}) {
    _currentToken = token;
    _tokenExpiry = expiry;
  }

  /// Clears the authentication token.
  void clearToken() {
    _currentToken = null;
    _tokenExpiry = null;
  }
  
  /// Sets the device ID for upload requests.
  void setDeviceId(String deviceId) {
    _deviceId = deviceId;
  }

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    // If authProvider is available, use it to get fresh credentials
    if (authProvider != null) {
      final token = await authProvider!.getToken();
      if (token == null) {
        _log.warning('AuthProvider returned null token');
        return null;
      }
      
      final userId = await authProvider!.getUserId();
      if (userId == null) {
        _log.warning('AuthProvider returned null userId');
        return null;
      }
      
      _currentToken = token;
      
      return PowerSyncCredentials(
        endpoint: serverUrl,
        token: token,
        userId: userId,
      );
    }
    
    // Fall back to manually set token
    if (_currentToken == null) {
      _log.warning('No authentication token available');
      return null;
    }

    // Check if token is expired
    if (_tokenExpiry != null && DateTime.now().isAfter(_tokenExpiry!)) {
      _log.info('Token expired, clearing');
      clearToken();
      return null;
    }

    return PowerSyncCredentials(
      endpoint: serverUrl,
      token: _currentToken,
    );
  }
  
  /// Invalidates the current credentials.
  /// 
  /// Called when authentication fails or token is rejected.
  @override
  void invalidateCredentials() {
    _log.info('Invalidating credentials');
    clearToken();
    // Note: AuthProvider from sync_config doesn't have onCredentialsInvalidated
    // The caller should handle credential invalidation through their own mechanism
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    _log.info('Starting data upload');
    
    final credentials = await fetchCredentials();
    if (credentials == null) {
      _log.warning('No credentials available for upload');
      return;
    }

    try {
      // Get pending local changes
      final transaction = await database.getNextCrudTransaction();
      if (transaction == null) {
        _log.fine('No pending changes to upload');
        return;
      }

      _log.info('Uploading ${transaction.crud.length} changes');

      // Convert CRUD operations to sync records
      final records = transaction.crud.map((op) {
        final operation = switch (op.op) {
          UpdateType.put => 'INSERT',
          UpdateType.patch => 'UPDATE',
          UpdateType.delete => 'DELETE',
        };
        
        return {
          'table_name': op.table,
          'record_id': op.id,
          'operation': operation,
          'data': op.opData != null ? jsonEncode(op.opData) : null,
          'version': op.opData?['version'] ?? 1,
        };
      }).toList();

      // POST to /api/v1/sync/upload
      final response = await _httpClient.post(
        Uri.parse('$serverUrl/api/v1/sync/upload'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${credentials.token}',
        },
        body: jsonEncode({
          'device_id': _deviceId,
          'records': records,
        }),
      );

      if (response.statusCode == 200) {
        await transaction.complete();
        _log.info('Upload completed successfully');
      } else if (response.statusCode == 401) {
        _log.warning('Authentication failed, invalidating credentials');
        invalidateCredentials();
        throw Exception('Authentication failed');
      } else if (response.statusCode == 409) {
        // Conflict - server will send correct data via sync stream
        _log.info('Conflict detected, marking transaction complete');
        await transaction.complete();
      } else {
        _log.warning('Upload failed: ${response.statusCode}');
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      _log.severe('Upload error', e, stackTrace);
      rethrow;
    }
  }

  /// Disposes resources.
  void dispose() {
    _httpClient.close();
  }
}
