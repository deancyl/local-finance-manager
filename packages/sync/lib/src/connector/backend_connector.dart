import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../sync_config.dart' show AuthProvider;
import '../models/sync_models.dart';

/// Stub backend connector for PowerSync authentication and data upload.
/// 
/// PowerSync integration is currently disabled. This stub allows the app to compile.
/// TODO: Re-integrate PowerSync when API compatibility is resolved.
class FinanceAppConnector {
  final String serverUrl;
  final AuthProvider? authProvider;
  final dynamic powerSyncDb;
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
  }) : _httpClient = httpClient ?? http.Client();

  /// Gets the current authentication token.
  String? get currentToken => _currentToken;

  /// Sets the authentication token.
  void setToken(String token, {DateTime? expiry}) {
    _currentToken = token;
    _tokenExpiry = expiry;
  }

  /// Clears the current token.
  void clearToken() {
    _currentToken = null;
    _tokenExpiry = null;
  }

  /// Sets the device ID.
  void setDeviceId(String deviceId) {
    _deviceId = deviceId;
  }

  /// Gets credentials for PowerSync.
  Future<PowerSyncCredentials?> fetchCredentials() async {
    _log.fine('Fetching credentials (stub)');
    
    if (_currentToken == null) {
      return null;
    }

    if (_tokenExpiry != null && DateTime.now().isAfter(_tokenExpiry!)) {
      _log.info('Token expired, clearing');
      clearToken();
      return null;
    }

    final token = _currentToken;
    if (token == null) {
      return null;
    }

    return PowerSyncCredentials(
      endpoint: serverUrl,
      token: token,
    );
  }
  
  /// Invalidates the current credentials.
  void invalidateCredentials() {
    _log.info('Invalidating credentials');
    clearToken();
  }

  /// Stub - no upload when sync is disabled.
  Future<void> uploadData(dynamic database) async {
    _log.info('Upload data called but PowerSync is disabled (stub)');
  }

  /// Disposes resources.
  void dispose() {
    _httpClient.close();
  }
}
