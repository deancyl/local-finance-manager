import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// Encryption service for encrypting/decrypting sensitive data.
///
/// Uses AES-256-GCM for symmetric encryption.
class EncryptionService {
  static const int _keyLength = 32; // 256 bits
  static const int _nonceLength = 12; // 96 bits for GCM
  static const int _tagLength = 16; // 128 bits

  final Uint8List _key;

  EncryptionService(this._key) {
    if (_key.length != _keyLength) {
      throw ArgumentError('Key must be $_keyLength bytes, got ${_key.length}');
    }
  }

  /// Creates an encryption service from a password using PBKDF2.
  factory EncryptionService.fromPassword(String password, {String? salt}) {
    final saltBytes = salt != null
        ? utf8.encode(salt)
        : utf8.encode('local-finance-manager-salt');

    final key = _deriveKey(password, Uint8List.fromList(saltBytes));
    return EncryptionService(key);
  }

  /// Encrypts data and returns base64-encoded ciphertext.
  String encrypt(String plaintext) {
    final plaintextBytes = utf8.encode(plaintext);
    final nonce = _generateNonce();

    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(
        KeyParameter(_key),
        _tagLength * 8,
        nonce,
        Uint8List(0),
      ));

    final ciphertext = Uint8List(plaintextBytes.length + _tagLength);
    var len = cipher.processBytes(
      Uint8List.fromList(plaintextBytes),
      0,
      plaintextBytes.length,
      ciphertext,
      0,
    );
    len += cipher.doFinal(ciphertext, len);

    // Combine nonce + ciphertext (only use actual output length)
    final result = Uint8List(nonce.length + len);
    result.setAll(0, nonce);
    result.setAll(nonce.length, Uint8List.sublistView(ciphertext, 0, len));

    return base64Url.encode(result);
  }

  /// Decrypts base64-encoded ciphertext.
  String decrypt(String ciphertextBase64) {
    final combined = base64Url.decode(ciphertextBase64);

    final nonce = Uint8List.sublistView(combined, 0, _nonceLength);
    final ciphertext = Uint8List.sublistView(combined, _nonceLength);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(
        KeyParameter(_key),
        _tagLength * 8,
        nonce,
        Uint8List(0),
      ));

    final plaintext = Uint8List(ciphertext.length);
    var len = cipher.processBytes(ciphertext, 0, ciphertext.length, plaintext, 0);
    len += cipher.doFinal(plaintext, len);

    return utf8.decode(Uint8List.sublistView(plaintext, 0, len));
  }

  /// Encrypts a map to JSON string.
  String encryptMap(Map<String, dynamic> data) {
    return encrypt(jsonEncode(data));
  }

  /// Decrypts JSON string to map.
  Map<String, dynamic> decryptMap(String ciphertext) {
    final plaintext = decrypt(ciphertext);
    return jsonDecode(plaintext) as Map<String, dynamic>;
  }

  /// Generates a random encryption key.
  static Uint8List generateKey() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(_keyLength, (_) => random.nextInt(256)),
    );
  }

  /// Derives a key from password using PBKDF2.
  static Uint8List _deriveKey(String password, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, 100000, _keyLength));

    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Generates a random nonce.
  Uint8List _generateNonce() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(_nonceLength, (_) => random.nextInt(256)),
    );
  }
}

/// Extension to convert Uint8List to hex string.
extension Uint8ListExtension on Uint8List {
  String toHexString() {
    return map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}