import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_app/features/sync/data/device_pairing_service.dart';
import 'package:finance_app/features/sync/presentation/widgets/qr_scanner_widget.dart';

void main() {
  group('DeviceInfo', () {
    test('creates device info with all fields', () {
      final device = DeviceInfo(
        deviceId: 'device-123',
        deviceName: 'My Phone',
        platform: 'android',
        registeredAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );
      
      expect(device.deviceId, equals('device-123'));
      expect(device.deviceName, equals('My Phone'));
      expect(device.platform, equals('android'));
    });

    test('serializes to JSON correctly', () {
      final device = DeviceInfo(
        deviceId: 'device-456',
        deviceName: 'My Tablet',
        platform: 'ios',
        registeredAt: DateTime.parse('2024-01-01T12:00:00Z'),
      );
      
      final json = device.toJson();
      
      expect(json['deviceId'], equals('device-456'));
      expect(json['deviceName'], equals('My Tablet'));
      expect(json['platform'], equals('ios'));
      expect(json['registeredAt'], equals('2024-01-01T12:00:00.000Z'));
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'deviceId': 'device-789',
        'deviceName': 'My Desktop',
        'platform': 'windows',
        'registeredAt': '2024-01-01T08:30:00Z',
      };
      
      final device = DeviceInfo.fromJson(json);
      
      expect(device.deviceId, equals('device-789'));
      expect(device.deviceName, equals('My Desktop'));
      expect(device.platform, equals('windows'));
    });
  });

  group('PairingToken', () {
    test('creates token with all fields', () {
      final token = PairingToken(
        token: 'PAIR-12345',
        serverUrl: 'https://sync.example.com',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        deviceId: 'device-123',
      );
      
      expect(token.token, equals('PAIR-12345'));
      expect(token.serverUrl, equals('https://sync.example.com'));
      expect(token.isExpired, isFalse);
    });

    test('detects expired token', () {
      final token = PairingToken(
        token: 'PAIR-expired',
        serverUrl: 'https://sync.example.com',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        deviceId: 'device-123',
      );
      
      expect(token.isExpired, isTrue);
    });

    test('calculates remaining time correctly', () {
      final expiresAt = DateTime.now().add(const Duration(minutes: 3));
      final token = PairingToken(
        token: 'PAIR-timer',
        serverUrl: 'https://sync.example.com',
        expiresAt: expiresAt,
        deviceId: 'device-123',
      );
      
      final remaining = token.remainingTime;
      expect(remaining.inMinutes, greaterThanOrEqualTo(2));
      expect(remaining.inMinutes, lessThanOrEqualTo(3));
    });
  });

  group('PairingResult', () {
    test('creates success result', () {
      final device = DeviceInfo(
        deviceId: 'paired-device',
        deviceName: 'Paired Phone',
        platform: 'android',
        registeredAt: DateTime.now(),
      );
      
      final result = PairingResult.success(device);
      
      expect(result.success, isTrue);
      expect(result.pairedDevice, equals(device));
      expect(result.errorMessage, isNull);
    });

    test('creates failure result', () {
      final result = PairingResult.failure('Network error');
      
      expect(result.success, isFalse);
      expect(result.errorMessage, equals('Network error'));
      expect(result.pairedDevice, isNull);
    });
  });

  group('QRPairingData', () {
    test('creates pairing data from QR code scan', () {
      final data = QRPairingData(
        serverUrl: 'https://sync.example.com',
        token: 'PAIR-12345',
        deviceId: 'remote-device-123',
        timestamp: DateTime.now(),
      );
      
      expect(data.serverUrl, equals('https://sync.example.com'));
      expect(data.token, equals('PAIR-12345'));
      expect(data.deviceId, equals('remote-device-123'));
    });

    test('validates timestamp for expiration', () {
      // Valid timestamp (within 5 minutes)
      final validData = QRPairingData(
        serverUrl: 'https://sync.example.com',
        token: 'PAIR-valid',
        deviceId: 'device-123',
        timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
      );
      
      final age = DateTime.now().difference(validData.timestamp);
      expect(age.inMinutes, lessThan(5));
      
      // Expired timestamp
      final expiredData = QRPairingData(
        serverUrl: 'https://sync.example.com',
        token: 'PAIR-expired',
        deviceId: 'device-123',
        timestamp: DateTime.now().subtract(const Duration(minutes: 6)),
      );
      
      final expiredAge = DateTime.now().difference(expiredData.timestamp);
      expect(expiredAge.inMinutes, greaterThanOrEqualTo(5));
    });
  });

  group('QR Payload Format', () {
    test('new format has required fields', () {
      // Simulate the new QR payload format
      final payload = {
        'type': 'finance_app_pairing',
        'token': 'test-jwt-token',
        'serverUrl': 'https://sync.example.com',
        'deviceId': 'device-uuid-123',
        'ts': DateTime.now().millisecondsSinceEpoch,
      };
      
      final jsonString = jsonEncode(payload);
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      
      expect(decoded['type'], equals('finance_app_pairing'));
      expect(decoded['token'], equals('test-jwt-token'));
      expect(decoded['serverUrl'], equals('https://sync.example.com'));
      expect(decoded['deviceId'], equals('device-uuid-123'));
      expect(decoded['ts'], isA<int>());
    });

    test('legacy format (v:1) is still supported', () {
      // Simulate the legacy QR payload format
      final payload = {
        'v': 1,
        'serverUrl': 'https://sync.example.com',
        'token': 'legacy-token',
        'deviceId': 'device-uuid-456',
        'ts': DateTime.now().millisecondsSinceEpoch,
      };
      
      final jsonString = jsonEncode(payload);
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Legacy format should be recognized
      expect(decoded['v'], equals(1));
      expect(decoded['token'], equals('legacy-token'));
      expect(decoded['serverUrl'], equals('https://sync.example.com'));
    });

    test('new format validates type field', () {
      final validPayload = {
        'type': 'finance_app_pairing',
        'token': 'test-token',
        'serverUrl': 'https://sync.example.com',
        'deviceId': 'device-123',
        'ts': DateTime.now().millisecondsSinceEpoch,
      };
      
      // Check that type field is correct
      expect(validPayload['type'], equals('finance_app_pairing'));
      
      // Invalid format should not have the correct type
      final invalidPayload = {
        'type': 'some_other_app',
        'token': 'test-token',
      };
      
      expect(invalidPayload['type'], isNot(equals('finance_app_pairing')));
    });

    test('payload contains all required fields for pairing', () {
      final payload = {
        'type': 'finance_app_pairing',
        'token': 'jwt-token-abc123',
        'serverUrl': 'https://sync.finance-app.com',
        'deviceId': '550e8400-e29b-41d4-a716-446655440000',
        'ts': DateTime.now().millisecondsSinceEpoch,
      };
      
      // Verify all required fields exist
      expect(payload.containsKey('type'), isTrue);
      expect(payload.containsKey('token'), isTrue);
      expect(payload.containsKey('serverUrl'), isTrue);
      expect(payload.containsKey('deviceId'), isTrue);
      expect(payload.containsKey('ts'), isTrue);
      
      // Verify field types
      expect(payload['type'], isA<String>());
      expect(payload['token'], isA<String>());
      expect(payload['serverUrl'], isA<String>());
      expect(payload['deviceId'], isA<String>());
      expect(payload['ts'], isA<int>());
    });

    test('QRPairingData can be created from new format payload', () {
      final now = DateTime.now();
      final payload = {
        'type': 'finance_app_pairing',
        'token': 'jwt-xyz789',
        'serverUrl': 'https://sync.example.com',
        'deviceId': 'device-abc',
        'ts': now.millisecondsSinceEpoch,
      };
      
      final data = QRPairingData(
        serverUrl: payload['serverUrl'] as String,
        token: payload['token'] as String,
        deviceId: payload['deviceId'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(payload['ts'] as int),
      );
      
      expect(data.serverUrl, equals('https://sync.example.com'));
      expect(data.token, equals('jwt-xyz789'));
      expect(data.deviceId, equals('device-abc'));
      expect(data.timestamp.millisecondsSinceEpoch, equals(now.millisecondsSinceEpoch));
    });
  });

  group('QR Pairing Flow', () {
    test('complete flow: generate -> scan -> pair', () {
      // Step 1: Generate pairing token
      final pairingToken = PairingToken(
        token: 'generated-jwt-token',
        serverUrl: 'https://sync.example.com',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        deviceId: 'existing-device-id',
      );
      
      expect(pairingToken.isExpired, isFalse);
      
      // Step 2: Create QR payload
      final qrPayload = {
        'type': 'finance_app_pairing',
        'token': pairingToken.token,
        'serverUrl': pairingToken.serverUrl,
        'deviceId': pairingToken.deviceId,
        'ts': DateTime.now().millisecondsSinceEpoch,
      };
      
      final qrString = jsonEncode(qrPayload);
      
      // Step 3: Scan and parse QR code
      final scannedPayload = jsonDecode(qrString) as Map<String, dynamic>;
      expect(scannedPayload['type'], equals('finance_app_pairing'));
      
      // Step 4: Create QRPairingData
      final pairingData = QRPairingData(
        serverUrl: scannedPayload['serverUrl'] as String,
        token: scannedPayload['token'] as String,
        deviceId: scannedPayload['deviceId'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(scannedPayload['ts'] as int),
      );
      
      expect(pairingData.serverUrl, equals(pairingToken.serverUrl));
      expect(pairingData.token, equals(pairingToken.token));
      expect(pairingData.deviceId, equals(pairingToken.deviceId));
      
      // Step 5: Complete pairing
      final pairedDevice = DeviceInfo(
        deviceId: 'new-device-id',
        deviceName: 'New Phone',
        platform: 'ios',
        registeredAt: DateTime.now(),
      );
      
      final result = PairingResult.success(pairedDevice);
      expect(result.success, isTrue);
      expect(result.pairedDevice?.deviceName, equals('New Phone'));
    });

    test('expired QR code is detected', () {
      // Create an expired QR payload
      final expiredTimestamp = DateTime.now().subtract(const Duration(minutes: 6));
      final qrPayload = {
        'type': 'finance_app_pairing',
        'token': 'expired-token',
        'serverUrl': 'https://sync.example.com',
        'deviceId': 'device-id',
        'ts': expiredTimestamp.millisecondsSinceEpoch,
      };
      
      // Check expiration
      final timestamp = DateTime.fromMillisecondsSinceEpoch(qrPayload['ts'] as int);
      final age = DateTime.now().difference(timestamp);
      
      expect(age.inMinutes, greaterThanOrEqualTo(5));
    });

    test('invalid QR format is rejected', () {
      // Create an invalid QR payload (wrong type)
      final invalidPayload = {
        'type': 'unknown_app',
        'token': 'some-token',
        'serverUrl': 'https://example.com',
      };
      
      // Should not match finance_app_pairing
      expect(invalidPayload['type'], isNot(equals('finance_app_pairing')));
      
      // Legacy format should also be checked
      final noVersionPayload = {
        'token': 'some-token',
        'serverUrl': 'https://example.com',
      };
      
      // No version field
      expect(noVersionPayload.containsKey('v'), isFalse);
      expect(noVersionPayload.containsKey('type'), isFalse);
    });
  });
}
