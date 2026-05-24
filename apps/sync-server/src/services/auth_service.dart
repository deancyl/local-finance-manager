import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:uuid/uuid.dart';
import 'package:postgres/postgres.dart';
import '../database/connection.dart';
import '../models/sync_models.dart';
import 'encryption_service.dart';

class AuthService {
  final EncryptionService _encryption;
  final String jwtSecret;

  AuthService(this._encryption, this.jwtSecret);

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
  }) async {
    final conn = await DatabaseConnection.connection;
    final userId = const Uuid().v4();
    final salt = _encryption.generateSalt();
    final passwordHash = _encryption.hashPassword(password, salt);

    await conn.execute(
      Sql.named('''
      INSERT INTO users (id, email, encrypted_key, created_at)
      VALUES (@id, @email, @encryptedKey, @createdAt)
      '''),
      parameters: {
        'id': userId,
        'email': email,
        'encryptedKey': '$salt:$passwordHash',
        'createdAt': DateTime.now(),
      },
    );

    final token = _generateJwt(userId);
    return {
      'user_id': userId,
      'token': token,
    };
  }

  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT id, encrypted_key FROM users WHERE email = @email'),
      parameters: {'email': email},
    );

    if (result.isEmpty) return null;

    final user = result.first;
    final userId = user[0] as String;
    final encryptedKey = user[1] as String;
    final parts = encryptedKey.split(':');
    final salt = parts[0];
    final storedHash = parts[1];

    if (!_encryption.verifyPassword(password, salt, storedHash)) {
      return null;
    }

    final token = _generateJwt(userId);
    return {
      'user_id': userId,
      'token': token,
    };
  }

  Future<User?> getUser(String userId) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT id, email, encrypted_key, created_at FROM users WHERE id = @id'),
      parameters: {'id': userId},
    );

    if (result.isEmpty) return null;
    return User.fromRow(result.first);
  }

  String _generateJwt(String userId) {
    final jwt = JWT({
      'sub': userId,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp': DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch ~/ 1000,
    });

    return jwt.sign(SecretKey(jwtSecret));
  }

  Future<String?> validateToken(String token) async {
    try {
      final jwt = JWT.verify(token, SecretKey(jwtSecret));
      return jwt.payload['sub'] as String;
    } catch (e) {
      return null;
    }
  }
}