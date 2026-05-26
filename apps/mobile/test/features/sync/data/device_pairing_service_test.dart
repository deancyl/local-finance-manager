import 'package:flutter_test/flutter_test.dart';
import 'package:finance_app/features/sync/data/device_pairing_service.dart';

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
}