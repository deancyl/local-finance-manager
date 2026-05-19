import 'dart:async';
import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_web_socket/dart_frog_web_socket.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../database/connection.dart';
import 'auth_service.dart';

/// WebSocket notification service using broadcast pattern.
/// 
/// Manages connections per user and broadcasts sync notifications.
class WebSocketService {
  final Map<String, Set<WebSocketChannel>> _userChannels = {};
  final AuthService _authService;
  
  WebSocketService(this._authService);
  
  /// Subscribe a channel to user-specific notifications.
  void subscribe(WebSocketChannel channel, String userId) {
    _userChannels.putIfAbsent(userId, () => {});
    _userChannels[userId]!.add(channel);
  }
  
  /// Unsubscribe a channel.
  void unsubscribe(WebSocketChannel channel, String userId) {
    _userChannels[userId]?.remove(channel);
    if (_userChannels[userId]?.isEmpty ?? false) {
      _userChannels.remove(userId);
    }
  }
  
  /// Broadcast notification to all channels for a user.
  void notifyUser(String userId, SyncNotification notification) {
    final channels = _userChannels[userId];
    if (channels == null) return;
    
    final message = jsonEncode(notification.toJson());
    for (final channel in channels) {
      channel.sink.add(message);
    }
  }
  
  /// Validate JWT token and return userId.
  Future<String?> validateToken(String token, String jwtSecret) async {
    try {
      final jwt = JWT.verify(token, SecretKey(jwtSecret));
      return jwt.payload['sub'] as String;
    } catch (e) {
      return null;
    }
  }
  
  /// Get connection count for a user.
  int getConnectionCount(String userId) {
    return _userChannels[userId]?.length ?? 0;
  }
  
  /// Get total connection count.
  int getTotalConnections() {
    return _userChannels.values.fold(0, (sum, set) => sum + set.length);
  }
}

/// Sync notification types.
enum NotificationType {
  syncComplete,
  conflictDetected,
  newDeviceRegistered,
  deviceRemoved,
}

/// Sync notification payload.
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
  
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'table_name': tableName,
    'record_id': recordId,
    'timestamp': timestamp.toIso8601String(),
  };
}
