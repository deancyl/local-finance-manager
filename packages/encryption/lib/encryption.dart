/// Encryption package for the finance application.
///
/// This package provides:
/// - Secure key storage (platform-specific keychain)
/// - AES-256-GCM encryption for sensitive data
/// - Password-based key derivation (PBKDF2)
library encryption;

export 'src/keychain/keychain_service.dart';
export 'src/keychain/mobile_keychain_service.dart';
export 'src/keychain/web_keychain_service.dart';
export 'src/crypto/encryption_service.dart';