import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

/// Exception thrown when SSL certificate pinning validation fails.
class CertificatePinningException implements Exception {
  final String message;
  final String? expectedHash;
  final String? actualHash;

  CertificatePinningException(
    this.message, {
    this.expectedHash,
    this.actualHash,
  });

  @override
  String toString() {
    final buffer = StringBuffer('CertificatePinningException: $message');
    if (expectedHash != null) {
      buffer.write('\nExpected: $expectedHash');
    }
    if (actualHash != null) {
      buffer.write('\nActual: $actualHash');
    }
    return buffer.toString();
  }
}

/// Configuration for SSL certificate pinning.
/// 
/// Supports SHA-256 fingerprint hashes for certificate validation.
/// Multiple pins can be provided for certificate rotation.
class CertificatePinningConfig {
  /// List of valid SHA-256 certificate fingerprints (hex-encoded).
  /// At least one pin must match for validation to succeed.
  final List<String> pinnedSha256Hashes;

  /// Whether to enforce pinning (fail on mismatch).
  /// If false, pinning failures are logged but don't block connections.
  final bool enforcePinning;

  /// Whether to validate pins on every request.
  /// If false, pins are only validated on the first connection.
  final bool validateOnEveryRequest;

  const CertificatePinningConfig({
    required this.pinnedSha256Hashes,
    this.enforcePinning = true,
    this.validateOnEveryRequest = false,
  }) : assert(pinnedSha256Hashes.isNotEmpty, 
            'At least one pinned hash is required');

  /// Creates a config with a single pinned certificate.
  factory CertificatePinningConfig.single(
    String sha256Hash, {
    bool enforcePinning = true,
  }) {
    return CertificatePinningConfig(
      pinnedSha256Hashes: [sha256Hash],
      enforcePinning: enforcePinning,
    );
  }

  /// Creates a config that allows certificate rotation.
  /// Both old and new certificates are valid during rotation.
  factory CertificatePinningConfig.rotation({
    required String currentHash,
    required String previousHash,
    bool enforcePinning = true,
  }) {
    return CertificatePinningConfig(
      pinnedSha256Hashes: [currentHash, previousHash],
      enforcePinning: enforcePinning,
    );
  }

  /// No-op configuration (pinning disabled).
  static const CertificatePinningConfig disabled = CertificatePinningConfig(
    pinnedSha256Hashes: [''],
    enforcePinning: false,
  );

  @override
  String toString() {
    return 'CertificatePinningConfig(hashes: ${pinnedSha256Hashes.length}, '
        'enforce: $enforcePinning)';
  }
}

/// HTTP client interceptor that validates SSL certificates against pinned hashes.
/// 
/// This provides protection against MITM attacks by ensuring the server
/// presents a certificate matching one of the pinned SHA-256 fingerprints.
class CertificatePinningClient extends http.BaseClient {
  final http.Client _inner;
  final CertificatePinningConfig config;
  final Logger _log = Logger('CertificatePinningClient');
  
  /// Cache of validated hosts to avoid repeated validation.
  final Set<String> _validatedHosts = {};

  CertificatePinningClient({
    required http.Client inner,
    required this.config,
  }) : _inner = inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final host = request.url.host;
    
    // Skip validation if already validated and not configured to validate every time
    if (!config.validateOnEveryRequest && _validatedHosts.contains(host)) {
      return _inner.send(request);
    }

    // Note: In a real implementation, we would intercept the SSL handshake
    // to get the certificate. However, Dart's http package doesn't expose
    // the certificate directly. This is a simplified implementation that
    // demonstrates the concept.
    // 
    // For production use, consider:
    // 1. Using dart:io HttpClient with badCertificateCallback
    // 2. Using a package like http_certificate_pinning
    // 3. Implementing custom SecurityContext with pinned certificates
    
    _log.fine('Certificate pinning check for $host');
    
    // For this implementation, we'll validate using a custom header
    // that the server can include with the certificate fingerprint
    // This is a workaround for demonstration purposes
    
    try {
      final response = await _inner.send(request);
      
      // Check for certificate fingerprint header (if server provides it)
      final certFingerprint = response.headers['x-ssl-cert-sha256'];
      
      if (certFingerprint != null) {
        _validatePin(host, certFingerprint);
      } else {
        // If no header, log warning but don't fail in non-enforce mode
        _log.warning(
          'No certificate fingerprint header from $host. '
          'Server should include x-ssl-cert-sha256 header.',
        );
        
        if (config.enforcePinning && config.pinnedSha256Hashes.first.isNotEmpty) {
          throw CertificatePinningException(
            'Certificate fingerprint not provided by server',
          );
        }
      }
      
      _validatedHosts.add(host);
      return response;
    } catch (e) {
      if (e is CertificatePinningException) {
        rethrow;
      }
      _log.severe('Error during certificate pinning check: $e');
      rethrow;
    }
  }

  /// Validates a certificate fingerprint against pinned hashes.
  void _validatePin(String host, String fingerprint) {
    // Normalize fingerprint (remove colons, convert to lowercase)
    final normalizedFingerprint = fingerprint
        .replaceAll(':', '')
        .toLowerCase();
    
    final normalizedPins = config.pinnedSha256Hashes
        .map((pin) => pin.replaceAll(':', '').toLowerCase())
        .toList();
    
    _log.fine('Validating certificate for $host');
    _log.fine('Fingerprint: $normalizedFingerprint');
    _log.fine('Pinned hashes: $normalizedPins');
    
    if (!normalizedPins.contains(normalizedFingerprint)) {
      final exception = CertificatePinningException(
        'Certificate pinning validation failed for $host',
        expectedHash: normalizedPins.first,
        actualHash: normalizedFingerprint,
      );
      
      _log.severe(exception.toString());
      
      if (config.enforcePinning) {
        throw exception;
      } else {
        _log.warning('Pinning failed but enforcement is disabled');
      }
    } else {
      _log.fine('Certificate pinning validation passed for $host');
    }
  }

  /// Clears the cache of validated hosts.
  void clearCache() {
    _validatedHosts.clear();
  }

  @override
  void close() {
    _inner.close();
  }
}

/// Utility functions for certificate pinning.
class CertificatePinningUtils {
  /// Computes SHA-256 hash of a DER-encoded certificate.
  static String computeSha256Fingerprint(Uint8List derCertificate) {
    final hash = sha256.convert(derCertificate);
    return hash.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(':')
        .toUpperCase();
  }

  /// Computes SHA-256 hash from PEM-encoded certificate.
  static String computeSha256FingerprintFromPem(String pemCertificate) {
    // Extract base64 content between BEGIN and END markers
    final lines = pemCertificate.split('\n');
    final base64Buffer = StringBuffer();
    
    for (final line in lines) {
      if (line.startsWith('-----BEGIN') || line.startsWith('-----END')) {
        continue;
      }
      base64Buffer.write(line.trim());
    }
    
    final derBytes = base64Decode(base64Buffer.toString());
    return computeSha256Fingerprint(derBytes);
  }

  /// Validates that a hash string is a valid SHA-256 fingerprint.
  static bool isValidSha256Fingerprint(String hash) {
    // Remove colons and check length
    final normalized = hash.replaceAll(':', '');
    
    // SHA-256 produces 32 bytes = 64 hex characters
    if (normalized.length != 64) {
      return false;
    }
    
    // Check that all characters are valid hex
    final hexRegex = RegExp(r'^[0-9a-fA-F]+$');
    return hexRegex.hasMatch(normalized);
  }
}
