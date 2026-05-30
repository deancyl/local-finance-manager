/// Encryption migration helper with platform-specific implementations.
/// 
/// Exports the appropriate implementation based on the platform:
/// - Native platforms (Android, iOS, Windows, macOS, Linux): Full SQLCipher support
/// - Web platform: No-op stub (encryption not supported)
export 'encryption_migration_helper_native.dart'
    if (dart.library.js) 'encryption_migration_helper_web.dart';
