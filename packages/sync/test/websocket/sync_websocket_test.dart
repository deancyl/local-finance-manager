import 'package:flutter_test/flutter_test.dart';
import 'package:sync/sync.dart';

void main() {
  group('SyncWebSocket', () {
    test('creates instance with required parameters', () {
      final websocket = SyncWebSocket(
        serverUrl: 'http://localhost:8080',
        jwtToken: 'test-token',
      );
      
      expect(websocket.serverUrl, equals('http://localhost:8080'));
      expect(websocket.jwtToken, equals('test-token'));
      expect(websocket.isConnected, isFalse);
    });

    test('notifications stream is available before connection', () {
      final websocket = SyncWebSocket(
        serverUrl: 'http://localhost:8080',
        jwtToken: 'test-token',
      );
      
      expect(websocket.notifications, isNotNull);
    });

    test('disconnect without prior connect does not throw', () async {
      final websocket = SyncWebSocket(
        serverUrl: 'http://localhost:8080',
        jwtToken: 'test-token',
      );
      
      // Should not throw
      await websocket.disconnect();
      expect(websocket.isConnected, isFalse);
    });
  });

  group('SyncNotification', () {
    test('creates notification with all fields', () {
      final notification = SyncNotification(
        type: NotificationType.syncComplete,
        tableName: 'transactions',
        recordId: 'record-123',
        timestamp: DateTime.parse('2024-01-01T00:00:00Z'),
      );
      
      expect(notification.type, equals(NotificationType.syncComplete));
      expect(notification.tableName, equals('transactions'));
      expect(notification.recordId, equals('record-123'));
    });

    test('serializes to JSON correctly', () {
      final notification = SyncNotification(
        type: NotificationType.conflictDetected,
        tableName: 'accounts',
        recordId: 'acc-456',
        timestamp: DateTime.parse('2024-01-01T12:00:00Z'),
      );
      
      final json = notification.toJson();
      
      expect(json['type'], equals('conflictDetected'));
      expect(json['table_name'], equals('accounts'));
      expect(json['record_id'], equals('acc-456'));
      expect(json['timestamp'], equals('2024-01-01T12:00:00.000Z'));
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'type': 'syncComplete',
        'table_name': 'categories',
        'record_id': 'cat-789',
        'timestamp': '2024-01-01T08:30:00Z',
      };
      
      final notification = SyncNotification.fromJson(json);
      
      expect(notification.type, equals(NotificationType.syncComplete));
      expect(notification.tableName, equals('categories'));
      expect(notification.recordId, equals('cat-789'));
    });

    test('handles notification without optional fields', () {
      final json = {
        'type': 'connected',
        'timestamp': '2024-01-01T00:00:00Z',
      };
      
      final notification = SyncNotification.fromJson(json);
      
      expect(notification.type, equals(NotificationType.connected));
      expect(notification.tableName, isNull);
      expect(notification.recordId, isNull);
    });
  });

  group('NotificationType', () {
    test('contains all expected types', () {
      expect(NotificationType.values, contains(NotificationType.syncComplete));
      expect(NotificationType.values, contains(NotificationType.conflictDetected));
      expect(NotificationType.values, contains(NotificationType.newDeviceRegistered));
      expect(NotificationType.values, contains(NotificationType.deviceRemoved));
      expect(NotificationType.values, contains(NotificationType.connected));
    });

    test('serializes by name', () {
      expect(NotificationType.syncComplete.name, equals('syncComplete'));
      expect(NotificationType.conflictDetected.name, equals('conflictDetected'));
      expect(NotificationType.connected.name, equals('connected'));
    });
  });
}