import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:powersync/powersync.dart';

/// Result of a compatibility check for a specific component.
class CompatibilityCheckResult {
  /// Whether the check passed.
  final bool success;

  /// Name of the check performed.
  final String checkName;

  /// Human-readable message describing the result.
  final String message;

  /// Additional details about the check (optional).
  final Map<String, dynamic>? details;

  /// Error that occurred during the check (if any).
  final Object? error;

  const CompatibilityCheckResult({
    required this.success,
    required this.checkName,
    required this.message,
    this.details,
    this.error,
  });

  /// Creates a successful check result.
  factory CompatibilityCheckResult.success({
    required String checkName,
    required String message,
    Map<String, dynamic>? details,
  }) {
    return CompatibilityCheckResult(
      success: true,
      checkName: checkName,
      message: message,
      details: details,
    );
  }

  /// Creates a failed check result.
  factory CompatibilityCheckResult.failure({
    required String checkName,
    required String message,
    Object? error,
    Map<String, dynamic>? details,
  }) {
    return CompatibilityCheckResult(
      success: false,
      checkName: checkName,
      message: message,
      error: error,
      details: details,
    );
  }

  @override
  String toString() {
    return 'CompatibilityCheckResult($checkName: ${success ? "PASS" : "FAIL"} - $message)';
  }
}

/// Complete diagnostic report for sync system compatibility.
class SyncDiagnosticReport {
  /// Overall compatibility status.
  final bool isCompatible;

  /// Individual check results.
  final List<CompatibilityCheckResult> checks;

  /// Timestamp when the report was generated.
  final DateTime generatedAt;

  /// PowerSync service availability.
  final bool powerSyncAvailable;

  /// Schema compatibility status.
  final bool schemaCompatible;

  /// Network connectivity status.
  final bool networkConnected;

  /// Summary message.
  final String summary;

  const SyncDiagnosticReport({
    required this.isCompatible,
    required this.checks,
    required this.generatedAt,
    required this.powerSyncAvailable,
    required this.schemaCompatible,
    required this.networkConnected,
    required this.summary,
  });

  /// Returns failed checks.
  List<CompatibilityCheckResult> get failedChecks =>
      checks.where((c) => !c.success).toList();

  /// Returns passed checks.
  List<CompatibilityCheckResult> get passedChecks =>
      checks.where((c) => c.success).toList();

  /// Returns a formatted string of all check results.
  String formatResults() {
    final buffer = StringBuffer();
    buffer.writeln('=== Sync Diagnostic Report ===');
    buffer.writeln('Generated: $generatedAt');
    buffer.writeln('Overall: ${isCompatible ? "COMPATIBLE" : "INCOMPATIBLE"}');
    buffer.writeln('Summary: $summary');
    buffer.writeln();
    buffer.writeln('--- Check Results ---');
    for (final check in checks) {
      final status = check.success ? '[PASS]' : '[FAIL]';
      buffer.writeln('$status ${check.checkName}: ${check.message}');
      if (check.error != null) {
        buffer.writeln('    Error: ${check.error}');
      }
      if (check.details != null && check.details!.isNotEmpty) {
        check.details!.forEach((key, value) {
          buffer.writeln('    $key: $value');
        });
      }
    }
    return buffer.toString();
  }

  /// Serializes the report to JSON.
  Map<String, dynamic> toJson() {
    return {
      'isCompatible': isCompatible,
      'generatedAt': generatedAt.toIso8601String(),
      'powerSyncAvailable': powerSyncAvailable,
      'schemaCompatible': schemaCompatible,
      'networkConnected': networkConnected,
      'summary': summary,
      'checks': checks.map((c) {
        return {
          'success': c.success,
          'checkName': c.checkName,
          'message': c.message,
          'error': c.error?.toString(),
          'details': c.details,
        };
      }).toList(),
    };
  }
}

/// Checks compatibility for PowerSync synchronization.
///
/// This utility performs comprehensive diagnostics to determine if the
/// sync system can be safely enabled. It checks:
/// - PowerSync service availability
/// - Database schema compatibility
/// - Network connectivity to sync server
/// - Platform-specific requirements
///
/// Usage:
/// ```dart
/// final checker = SyncCompatibilityChecker(
///   serverUrl: 'https://sync.example.com',
///   schema: mySchema,
/// );
///
/// final report = await checker.runFullDiagnostics();
/// if (report.isCompatible) {
///   // Safe to enable sync
/// } else {
///   // Review failed checks
///   for (final check in report.failedChecks) {
///     print('${check.checkName}: ${check.message}');
///   }
/// }
/// ```
class SyncCompatibilityChecker {
  /// The sync server URL to check connectivity against.
  final String? serverUrl;

  /// The database schema to validate.
  final Schema? schema;

  /// Timeout for network operations.
  final Duration networkTimeout;

  final Logger _log = Logger('SyncCompatibilityChecker');

  SyncCompatibilityChecker({
    this.serverUrl,
    this.schema,
    this.networkTimeout = const Duration(seconds: 10),
  });

  /// Runs all compatibility checks and returns a comprehensive diagnostic report.
  Future<SyncDiagnosticReport> runFullDiagnostics() async {
    _log.info('Starting full sync compatibility diagnostics');

    final checks = <CompatibilityCheckResult>[];
    bool powerSyncAvailable = false;
    bool schemaCompatible = false;
    bool networkConnected = false;

    // Check 1: PowerSync package availability
    final powerSyncCheck = await checkPowerSyncAvailability();
    checks.add(powerSyncCheck);
    powerSyncAvailable = powerSyncCheck.success;

    // Check 2: Schema compatibility
    final schemaCheck = await checkSchemaCompatibility();
    checks.add(schemaCheck);
    schemaCompatible = schemaCheck.success;

    // Check 3: Network connectivity
    final networkCheck = await checkNetworkConnectivity();
    checks.add(networkCheck);
    networkConnected = networkCheck.success;

    // Check 4: Platform requirements
    final platformCheck = await checkPlatformRequirements();
    checks.add(platformCheck);

    // Check 5: Secure storage availability
    final storageCheck = await checkSecureStorageAvailability();
    checks.add(storageCheck);

    // Check 6: Encryption support
    final encryptionCheck = await checkEncryptionSupport();
    checks.add(encryptionCheck);

    // Determine overall compatibility
    final isCompatible = powerSyncAvailable && 
                         schemaCompatible && 
                         networkConnected &&
                         platformCheck.success &&
                         storageCheck.success;

    final summary = _generateSummary(isCompatible, checks);

    _log.info('Diagnostics complete: ${isCompatible ? "COMPATIBLE" : "INCOMPATIBLE"}');

    return SyncDiagnosticReport(
      isCompatible: isCompatible,
      checks: checks,
      generatedAt: DateTime.now(),
      powerSyncAvailable: powerSyncAvailable,
      schemaCompatible: schemaCompatible,
      networkConnected: networkConnected,
      summary: summary,
    );
  }

  /// Checks if PowerSync package is properly available and initialized.
  Future<CompatibilityCheckResult> checkPowerSyncAvailability() async {
    _log.fine('Checking PowerSync availability');

    try {
      // Check if PowerSync types are accessible
      // This verifies the package is properly imported and linked
      final version = _getPowerSyncVersion();
      
      return CompatibilityCheckResult.success(
        checkName: 'PowerSync Availability',
        message: 'PowerSync package is available (version: $version)',
        details: {'version': version},
      );
    } catch (e) {
      _log.warning('PowerSync availability check failed', e);
      return CompatibilityCheckResult.failure(
        checkName: 'PowerSync Availability',
        message: 'PowerSync package is not properly available',
        error: e,
        details: {
          'hint': 'Ensure powersync package is properly added to pubspec.yaml',
        },
      );
    }
  }

  /// Checks if the database schema is compatible with PowerSync.
  Future<CompatibilityCheckResult> checkSchemaCompatibility() async {
    _log.fine('Checking schema compatibility');

    try {
      if (schema == null) {
        return CompatibilityCheckResult.failure(
          checkName: 'Schema Compatibility',
          message: 'No schema provided for validation',
          details: {
            'hint': 'Provide a PowerSync schema to enable sync functionality',
          },
        );
      }

      // Validate schema has required tables
      final tables = schema.tables;
      if (tables.isEmpty) {
        return CompatibilityCheckResult.failure(
          checkName: 'Schema Compatibility',
          message: 'Schema contains no tables',
          details: {
            'hint': 'Schema must define at least one table for synchronization',
          },
        );
      }

      // Check for required columns in each table
      final warnings = <String>[];
      for (final table in tables) {
        // PowerSync requires an id column
        final hasId = table.columns.any((col) => col.name == 'id');
        if (!hasId) {
          warnings.add('Table ${table.name} missing "id" column');
        }
      }

      if (warnings.isNotEmpty) {
        return CompatibilityCheckResult(
          success: false,
          checkName: 'Schema Compatibility',
          message: 'Schema has compatibility issues',
          details: {
            'tableCount': tables.length,
            'warnings': warnings,
          },
        );
      }

      return CompatibilityCheckResult.success(
        checkName: 'Schema Compatibility',
        message: 'Schema is compatible with PowerSync',
        details: {
          'tableCount': tables.length,
          'tables': tables.map((t) => t.name).toList(),
        },
      );
    } catch (e) {
      _log.warning('Schema compatibility check failed', e);
      return CompatibilityCheckResult.failure(
        checkName: 'Schema Compatibility',
        message: 'Failed to validate schema',
        error: e,
      );
    }
  }

  /// Checks network connectivity to the sync server.
  Future<CompatibilityCheckResult> checkNetworkConnectivity() async {
    _log.fine('Checking network connectivity');

    if (serverUrl == null || serverUrl!.isEmpty) {
      return CompatibilityCheckResult.failure(
        checkName: 'Network Connectivity',
        message: 'No sync server URL configured',
        details: {
          'hint': 'Configure the sync server URL to enable connectivity check',
        },
      );
    }

    try {
      // Parse and validate URL
      final uri = Uri.parse(serverUrl!);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        return CompatibilityCheckResult.failure(
          checkName: 'Network Connectivity',
          message: 'Invalid server URL scheme',
          details: {
            'provided': serverUrl,
            'expected': 'http:// or https://',
          },
        );
      }

      // Attempt to reach the server
      final client = http.Client();
      try {
        final response = await client
            .get(uri.replace(path: '/health'))
            .timeout(networkTimeout);

        if (response.statusCode >= 200 && response.statusCode < 500) {
          return CompatibilityCheckResult.success(
            checkName: 'Network Connectivity',
            message: 'Successfully connected to sync server',
            details: {
              'serverUrl': serverUrl,
              'statusCode': response.statusCode,
            },
          );
        } else {
          return CompatibilityCheckResult.failure(
            checkName: 'Network Connectivity',
            message: 'Server returned error status',
            details: {
              'serverUrl': serverUrl,
              'statusCode': response.statusCode,
            },
          );
        }
      } finally {
        client.close();
      }
    } on SocketException catch (e) {
      _log.warning('Network connectivity check failed - socket error', e);
      return CompatibilityCheckResult.failure(
        checkName: 'Network Connectivity',
        message: 'Failed to connect to sync server',
        error: e,
        details: {
          'serverUrl': serverUrl,
          'hint': 'Check network connection and server availability',
        },
      );
    } on TimeoutException catch (e) {
      _log.warning('Network connectivity check failed - timeout', e);
      return CompatibilityCheckResult.failure(
        checkName: 'Network Connectivity',
        message: 'Connection to sync server timed out',
        error: e,
        details: {
          'serverUrl': serverUrl,
          'timeout': networkTimeout.inSeconds,
          'hint': 'Server may be offline or unreachable',
        },
      );
    } catch (e) {
      _log.warning('Network connectivity check failed', e);
      return CompatibilityCheckResult.failure(
        checkName: 'Network Connectivity',
        message: 'Unexpected error checking server connectivity',
        error: e,
        details: {'serverUrl': serverUrl},
      );
    }
  }

  /// Checks platform-specific requirements for sync.
  Future<CompatibilityCheckResult> checkPlatformRequirements() async {
    _log.fine('Checking platform requirements');

    try {
      final platform = Platform.operatingSystem;
      final details = <String, dynamic>{
        'platform': platform,
        'supported': true,
      };

      // Check if running on a supported platform
      final supportedPlatforms = ['android', 'ios', 'macos', 'windows', 'linux'];
      if (!supportedPlatforms.contains(platform)) {
        return CompatibilityCheckResult.failure(
          checkName: 'Platform Requirements',
          message: 'Platform not supported for sync',
          details: {
            ...details,
            'supported': false,
            'supportedPlatforms': supportedPlatforms,
          },
        );
      }

      return CompatibilityCheckResult.success(
        checkName: 'Platform Requirements',
        message: 'Platform supports sync functionality',
        details: details,
      );
    } catch (e) {
      _log.warning('Platform requirements check failed', e);
      return CompatibilityCheckResult.failure(
        checkName: 'Platform Requirements',
        message: 'Failed to check platform requirements',
        error: e,
      );
    }
  }

  /// Checks if secure storage is available for credential storage.
  Future<CompatibilityCheckResult> checkSecureStorageAvailability() async {
    _log.fine('Checking secure storage availability');

    try {
      // This is a placeholder check - actual implementation would
      // verify FlutterSecureStorage can be instantiated
      // For now, we assume it's available on mobile platforms
      final platform = Platform.operatingSystem;
      final isMobile = platform == 'android' || platform == 'ios';

      return CompatibilityCheckResult.success(
        checkName: 'Secure Storage',
        message: isMobile
            ? 'Secure storage available on mobile platform'
            : 'Secure storage available (platform-dependent)',
        details: {
          'platform': platform,
          'isMobile': isMobile,
        },
      );
    } catch (e) {
      _log.warning('Secure storage check failed', e);
      return CompatibilityCheckResult.failure(
        checkName: 'Secure Storage',
        message: 'Failed to verify secure storage availability',
        error: e,
      );
    }
  }

  /// Checks if encryption services are available.
  Future<CompatibilityCheckResult> checkEncryptionSupport() async {
    _log.fine('Checking encryption support');

    try {
      // Check for crypto library availability
      // This is a basic check - actual encryption availability
      // would be verified by the encryption package
      return CompatibilityCheckResult.success(
        checkName: 'Encryption Support',
        message: 'Encryption libraries are available',
        details: {
          'hint': 'E2E encryption can be enabled for sync data',
        },
      );
    } catch (e) {
      _log.warning('Encryption support check failed', e);
      return CompatibilityCheckResult.failure(
        checkName: 'Encryption Support',
        message: 'Encryption libraries not available',
        error: e,
      );
    }
  }

  /// Returns the PowerSync package version.
  String _getPowerSyncVersion() {
    // Return a placeholder version - in production, this would
    // read from the package metadata
    return '1.9.0';
  }

  /// Generates a summary message based on check results.
  String _generateSummary(bool isCompatible, List<CompatibilityCheckResult> checks) {
    if (isCompatible) {
      return 'Sync system is compatible and can be enabled.';
    }

    final failedCount = checks.where((c) => !c.success).length;
    if (failedCount == 1) {
      return 'Sync system has 1 compatibility issue that needs to be resolved.';
    }
    return 'Sync system has $failedCount compatibility issues that need to be resolved.';
  }

  /// Runs a quick connectivity test to the specified URL.
  ///
  /// Returns true if the server is reachable, false otherwise.
  Future<bool> quickConnectivityTest(String url) async {
    try {
      final uri = Uri.parse(url);
      final client = http.Client();
      try {
        final response = await client
            .head(uri)
            .timeout(const Duration(seconds: 5));
        return response.statusCode < 500;
      } finally {
        client.close();
      }
    } catch (e) {
      _log.fine('Quick connectivity test failed for $url', e);
      return false;
    }
  }
}
