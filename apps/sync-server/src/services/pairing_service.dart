import 'package:uuid/uuid.dart';
import 'package:postgres/postgres.dart';
import '../database/connection.dart';

class PairingService {
  /// Generate a pairing token for a device.
  /// 
  /// Token format: PAIR-XXXXXXXX (8 alphanumeric characters)
  /// Expires in 5 minutes.
  Future<PairingToken> initiatePairing({
    required String userId,
    required String deviceId,
  }) async {
    final conn = await DatabaseConnection.connection;
    final tokenId = const Uuid().v4();
    final token = 'PAIR-${_generateTokenCode()}';
    final expiresAt = DateTime.now().add(const Duration(minutes: 5));
    
    await conn.execute(
      Sql.named('''
      INSERT INTO pairing_tokens (id, user_id, device_id, token, expires_at)
      VALUES (@id, @userId, @deviceId, @token, @expiresAt)
      '''),
      parameters: {
        'id': tokenId,
        'userId': userId,
        'deviceId': deviceId,
        'token': token,
        'expiresAt': expiresAt,
      },
    );
    
    return PairingToken(
      id: tokenId,
      userId: userId,
      deviceId: deviceId,
      token: token,
      expiresAt: expiresAt,
    );
  }
  
  /// Complete pairing with a token.
  /// 
  /// Returns the paired device ID if successful.
  Future<String?> completePairing({
    required String token,
    required String newDeviceId,
    required String userId,
  }) async {
    final conn = await DatabaseConnection.connection;
    
    // Find valid token
    final result = await conn.execute(
      Sql.named('''
      SELECT id, device_id FROM pairing_tokens
      WHERE token = @token AND user_id = @userId AND expires_at > @now
      '''),
      parameters: {
        'token': token,
        'userId': userId,
        'now': DateTime.now(),
      },
    );
    
    if (result.isEmpty) return null;
    
    final pairingId = result.first[0] as String;
    
    // Delete the token (one-time use)
    await conn.execute(
      Sql.named('DELETE FROM pairing_tokens WHERE id = @id'),
      parameters: {'id': pairingId},
    );
    
    return newDeviceId;
  }
  
  /// Check pairing status.
  Future<PairingStatus> checkStatus(String tokenId) async {
    final conn = await DatabaseConnection.connection;
    
    final result = await conn.execute(
      Sql.named('''
      SELECT expires_at FROM pairing_tokens WHERE id = @id
      '''),
      parameters: {'id': tokenId},
    );
    
    if (result.isEmpty) {
      return PairingStatus.completed;
    }
    
    final expiresAt = result.first[0] as DateTime;
    if (DateTime.now().isAfter(expiresAt)) {
      return PairingStatus.expired;
    }
    
    return PairingStatus.pending;
  }
  
  /// Clean up expired tokens.
  Future<void> cleanupExpired() async {
    final conn = await DatabaseConnection.connection;
    await conn.execute(
      Sql.named('DELETE FROM pairing_tokens WHERE expires_at < @now'),
      parameters: {'now': DateTime.now()},
    );
  }
  
  String _generateTokenCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    return List.generate(8, (i) => chars[(random + i) % chars.length]).join();
  }
}

class PairingToken {
  final String id;
  final String userId;
  final String deviceId;
  final String token;
  final DateTime expiresAt;
  
  PairingToken({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.token,
    required this.expiresAt,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'token': token,
    'expires_at': expiresAt.toIso8601String(),
  };
}

enum PairingStatus {
  pending,
  completed,
  expired,
}