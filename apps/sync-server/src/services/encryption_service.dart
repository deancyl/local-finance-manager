import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:encryption/encryption.dart' as enc;

class EncryptionService {
  final String encryptionKey;
  late final enc.EncryptionService _service;
  
  EncryptionService(this.encryptionKey) {
    final keyBytes = utf8.encode(encryptionKey.padRight(32, '0').substring(0, 32));
    _service = enc.EncryptionService(Uint8List.fromList(keyBytes));
  }
  
  String encrypt(String plaintext) {
    return _service.encrypt(plaintext);
  }
  
  String decrypt(String ciphertext) {
    return _service.decrypt(ciphertext);
  }
  
  String hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    return sha256.convert(bytes).toString();
  }
  
  bool verifyPassword(String password, String salt, String hash) {
    return hashPassword(password, salt) == hash;
  }
  
  String generateSalt() {
    return const Uuid().v4().replaceAll('-', '').substring(0, 16);
  }
}
