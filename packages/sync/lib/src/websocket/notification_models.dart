import 'dart:convert';

enum NotificationType {
  syncComplete,
  conflictDetected,
  newDeviceRegistered,
  deviceRemoved,
  connected,
}

class SyncNotification {
  final NotificationType type;
  final String? tableName;
  final String? recordId;
  final DateTime timestamp;
  
  SyncNotification({
    required this.type,
    this.tableName,
    this.recordId,
    required this.timestamp,
  });
  
  factory SyncNotification.fromJson(Map<String, dynamic> json) {
    return SyncNotification(
      type: NotificationType.values.byName(json['type'] as String),
      tableName: json['table_name'] as String?,
      recordId: json['record_id'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
  
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'table_name': tableName,
    'record_id': recordId,
    'timestamp': timestamp.toIso8601String(),
  };
}
