import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'sync_feature_flag.dart';
import 'auth_provider_impl.dart';

final _log = Logger('DevicePairingService');

/// Device information for pairing.
class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String platform;
  final DateTime registeredAt;
  
  const DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.registeredAt,
  });
  
  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      platform: json['platform'] as String,
      registeredAt: DateTime.parse(json['registeredAt'] as String),
    );
  }
  
  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'platform': platform,
    'registeredAt': registeredAt.toIso8601String(),
  };
}

/// Pairing token with expiration.
class PairingToken {
  final String token;
  final String serverUrl;
  final DateTime expiresAt;
  final String deviceId;
  
  const PairingToken({
    required this.token,
    required this.serverUrl,
    required this.expiresAt,
    required this.deviceId,
  });
  
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  Duration get remainingTime => expiresAt.difference(DateTime.now());
}

/// Result of a pairing operation.
class PairingResult {
  final bool success;
  final String? errorMessage;
  final DeviceInfo? pairedDevice;
  
  const PairingResult({
    required this.success,
    this.errorMessage,
    this.pairedDevice,
  });
  
  factory PairingResult.success(DeviceInfo device) {
    return PairingResult(success: true, pairedDevice: device);
  }
  
  factory PairingResult.failure(String error) {
    return PairingResult(success: false, errorMessage: error);
  }
}

/// Device pairing service for QR code-based device pairing.
/// 
/// Handles both generating QR codes for other devices to scan
/// and processing scanned QR codes from other devices.
class DevicePairingService {
  final http.Client _httpClient;
  final FlutterSecureStorage _storage;
  final String? Function() _serverUrlProvider;
  final String? Function() _tokenProvider;
  
  static const _keyDeviceId = 'sync_device_id';
  static const _keyDeviceName = 'sync_device_name';
  static const String _pairingEndpoint = '/api/pairing';
  
  DevicePairingService({
    http.Client? httpClient,
    FlutterSecureStorage? storage,
    required String? Function() serverUrlProvider,
    required String? Function() tokenProvider,
  })  : _httpClient = httpClient ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        ),
        _serverUrlProvider = serverUrlProvider,
        _tokenProvider = tokenProvider;
  
  /// Gets or creates the device ID.
  Future<String> getDeviceId() async {
    var deviceId = await _storage.read(key: _keyDeviceId);
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await _storage.write(key: _keyDeviceId, value: deviceId);
      _log.info('Generated new device ID: $deviceId');
    }
    return deviceId;
  }
  
  /// Gets the device name.
  Future<String> getDeviceName() async {
    var deviceName = await _storage.read(key: _keyDeviceName);
    if (deviceName == null) {
      // Use platform info as default device name
      deviceName = '${Platform.operatingSystem} Device';
      await _storage.write(key: _keyDeviceName, value: deviceName);
    }
    return deviceName;
  }
  
  /// Sets a custom device name.
  Future<void> setDeviceName(String name) async {
    await _storage.write(key: _keyDeviceName, value: name);
    _log.info('Device name set to: $name');
  }
  
  /// Generates a pairing token for QR code display.
  /// 
  /// Returns null if sync is not configured or server is unreachable.
  Future<PairingToken?> generatePairingToken({
    Duration validity = const Duration(minutes: 5),
  }) async {
    final serverUrl = _serverUrlProvider();
    final token = _tokenProvider();
    
    if (serverUrl == null || token == null) {
      _log.warning('Cannot generate pairing token: server not configured');
      return null;
    }
    
    final deviceId = await getDeviceId();
    
    try {
      _log.info('Requesting pairing token from server...');
      
      final response = await _httpClient.post(
        Uri.parse('$serverUrl$_pairingEndpoint/generate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'deviceId': deviceId,
          'validityMinutes': validity.inMinutes,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        _log.info('Pairing token generated successfully');
        
        return PairingToken(
          token: data['pairingToken'] as String,
          serverUrl: serverUrl,
          expiresAt: DateTime.parse(data['expiresAt'] as String),
          deviceId: deviceId,
        );
      } else {
        final error = jsonDecode(response.body)['error'] as String?;
        _log.warning('Failed to generate pairing token: $error');
        return null;
      }
    } catch (e) {
      _log.severe('Error generating pairing token: $e');
      return null;
    }
  }
  
  /// Processes a scanned QR code pairing data.
  /// 
  /// Contacts the server to complete the pairing process.
  Future<PairingResult> processPairingRequest({
    required String serverUrl,
    required String pairingToken,
    required String remoteDeviceId,
  }) async {
    final token = _tokenProvider();
    
    if (token == null) {
      return PairingResult.failure('未登录');
    }
    
    final deviceId = await getDeviceId();
    final deviceName = await getDeviceName();
    
    try {
      _log.info('Processing pairing request...');
      
      final response = await _httpClient.post(
        Uri.parse('$serverUrl$_pairingEndpoint/complete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'pairingToken': pairingToken,
          'remoteDeviceId': remoteDeviceId,
          'deviceId': deviceId,
          'deviceName': deviceName,
          'platform': Platform.operatingSystem,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final pairedDevice = DeviceInfo.fromJson(data['device'] as Map<String, dynamic>);
        
        _log.info('Pairing successful with device: ${pairedDevice.deviceName}');
        
        return PairingResult.success(pairedDevice);
      } else {
        final error = jsonDecode(response.body)['error'] as String?;
        _log.warning('Pairing failed: $error');
        return PairingResult.failure(error ?? '配对失败');
      }
    } catch (e) {
      _log.severe('Error processing pairing: $e');
      return PairingResult.failure('网络错误: $e');
    }
  }
  
  /// Gets the list of paired devices.
  Future<List<DeviceInfo>> getPairedDevices() async {
    final serverUrl = _serverUrlProvider();
    final token = _tokenProvider();
    
    if (serverUrl == null || token == null) {
      return [];
    }
    
    try {
      final response = await _httpClient.get(
        Uri.parse('$serverUrl$_pairingEndpoint/devices'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.map((d) => DeviceInfo.fromJson(d as Map<String, dynamic>)).toList();
      }
      
      return [];
    } catch (e) {
      _log.warning('Failed to get paired devices: $e');
      return [];
    }
  }
  
  /// Removes a paired device.
  Future<bool> removeDevice(String deviceId) async {
    final serverUrl = _serverUrlProvider();
    final token = _tokenProvider();
    
    if (serverUrl == null || token == null) {
      return false;
    }
    
    try {
      final response = await _httpClient.delete(
        Uri.parse('$serverUrl$_pairingEndpoint/devices/$deviceId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      _log.warning('Failed to remove device: $e');
      return false;
    }
  }
  
  /// Disposes resources.
  void dispose() {
    _httpClient.close();
  }
}