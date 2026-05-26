import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'sync_feature_flag.dart';
import 'device_pairing_service.dart';
import 'websocket_provider.dart';
import 'auth_provider_impl.dart';

/// Provider for FlutterSecureStorage.
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

/// Provider for device pairing service.
final devicePairingServiceProvider = Provider<DevicePairingService>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  
  return DevicePairingService(
    storage: secureStorage,
    serverUrlProvider: () => ref.read(syncServerUrlProvider),
    tokenProvider: () => ref.read(storedAuthTokenProvider).valueOrNull,
  );
});

/// Provider for current device ID.
final currentDeviceIdProvider = FutureProvider<String>((ref) async {
  final service = ref.watch(devicePairingServiceProvider);
  return await service.getDeviceId();
});

/// Provider for current device name.
final currentDeviceNameProvider = FutureProvider<String>((ref) async {
  final service = ref.watch(devicePairingServiceProvider);
  return await service.getDeviceName();
});

/// Provider for pairing token (for QR code generation).
final pairingTokenProvider = FutureProvider<PairingToken?>((ref) async {
  final isSyncEnabled = ref.watch(syncFeatureFlagProvider);
  
  if (!isSyncEnabled) {
    return null;
  }
  
  final service = ref.watch(devicePairingServiceProvider);
  return await service.generatePairingToken();
});

/// Notifier for managing pairing token generation.
class PairingTokenNotifier extends StateNotifier<AsyncValue<PairingToken?>> {
  final DevicePairingService _service;
  final Ref _ref;
  
  PairingTokenNotifier(this._service, this._ref) 
      : super(const AsyncValue.data(null));
  
  /// Generates a new pairing token.
  Future<void> generateToken() async {
    state = const AsyncValue.loading();
    
    try {
      final token = await _service.generatePairingToken();
      state = AsyncValue.data(token);
    } catch (e) {
      state = AsyncValue.error(e, null);
    }
  }
  
  /// Clears the current pairing token.
  void clearToken() {
    state = const AsyncValue.data(null);
  }
}

final pairingTokenNotifierProvider = 
    StateNotifierProvider<PairingTokenNotifier, AsyncValue<PairingToken?>>((ref) {
  final service = ref.watch(devicePairingServiceProvider);
  return PairingTokenNotifier(service, ref);
});

/// Provider for paired devices list.
final pairedDevicesProvider = FutureProvider<List<DeviceInfo>>((ref) async {
  final isSyncEnabled = ref.watch(syncFeatureFlagProvider);
  
  if (!isSyncEnabled) {
    return [];
  }
  
  final service = ref.watch(devicePairingServiceProvider);
  return await service.getPairedDevices();
});

/// Notifier for handling device pairing operations.
class DevicePairingNotifier extends StateNotifier<AsyncValue<PairingResult?>> {
  final DevicePairingService _service;
  final Ref _ref;
  
  DevicePairingNotifier(this._service, this._ref) 
      : super(const AsyncValue.data(null));
  
  /// Completes a pairing request from scanned QR code.
  Future<PairingResult> completePairing({
    required String serverUrl,
    required String pairingToken,
    required String remoteDeviceId,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      final result = await _service.processPairingRequest(
        serverUrl: serverUrl,
        pairingToken: pairingToken,
        remoteDeviceId: remoteDeviceId,
      );
      
      state = AsyncValue.data(result);
      
      // Refresh paired devices list if successful
      if (result.success) {
        _ref.invalidate(pairedDevicesProvider);
      }
      
      return result;
    } catch (e) {
      final result = PairingResult.failure('网络错误: $e');
      state = AsyncValue.data(result);
      return result;
    }
  }
  
  /// Removes a paired device.
  Future<bool> removeDevice(String deviceId) async {
    final success = await _service.removeDevice(deviceId);
    
    if (success) {
      _ref.invalidate(pairedDevicesProvider);
    }
    
    return success;
  }
  
  /// Clears the current pairing result.
  void clearResult() {
    state = const AsyncValue.data(null);
  }
}

final devicePairingNotifierProvider = 
    StateNotifierProvider<DevicePairingNotifier, AsyncValue<PairingResult?>>((ref) {
  final service = ref.watch(devicePairingServiceProvider);
  return DevicePairingNotifier(service, ref);
});

/// Provider for updating device name.
class DeviceNameNotifier extends StateNotifier<String> {
  final DevicePairingService _service;
  
  DeviceNameNotifier(this._service, String initialName) : super(initialName);
  
  /// Updates the device name.
  Future<void> updateName(String newName) async {
    await _service.setDeviceName(newName);
    state = newName;
  }
}

final deviceNameNotifierProvider = 
    StateNotifierProvider<DeviceNameNotifier, String>((ref) {
  final initialName = ref.watch(currentDeviceNameProvider).valueOrNull ?? 'Unknown Device';
  final service = ref.watch(devicePairingServiceProvider);
  return DeviceNameNotifier(service, initialName);
});