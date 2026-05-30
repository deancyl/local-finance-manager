import 'dart:convert';
import 'dart:typed_data';
import 'package:gbk_codec/gbk_codec.dart' as gbk_pkg;

/// Result of encoding detection with confidence and details.
class EncodingDetectionResult {
  /// The detected encoding name.
  final String encoding;

  /// Confidence level (0.0 to 1.0).
  final double confidence;

  /// Whether a BOM was detected.
  final bool hasBom;

  /// Source of the detection decision.
  final String source;

  /// Ratio of Chinese characters (for UTF-8).
  final double? chineseCharRatio;

  /// GBK pattern score.
  final double? gbkScore;

  /// Whether this is a default fallback.
  final bool isDefault;

  const EncodingDetectionResult({
    required this.encoding,
    required this.confidence,
    this.hasBom = false,
    required this.source,
    this.chineseCharRatio,
    this.gbkScore,
    this.isDefault = false,
  });

  /// Returns true if confidence is high (> 0.8).
  bool get isHighConfidence => confidence > 0.8;

  /// Returns a user-friendly encoding name.
  String get encodingDisplayName {
    switch (encoding.toLowerCase()) {
      case 'utf-8':
        return 'UTF-8';
      case 'gbk':
        return 'GBK (简体中文)';
      case 'gb2312':
        return 'GB2312 (简体中文)';
      case 'utf-16le':
        return 'UTF-16 LE';
      case 'utf-16be':
        return 'UTF-16 BE';
      default:
        return encoding.toUpperCase();
    }
  }
  
  /// Returns a description for the user.
  String get userDescription {
    if (hasBom) {
      return '检测到编码标记 ($encodingDisplayName)';
    }
    if (isHighConfidence) {
      return '高置信度检测为 $encodingDisplayName';
    }
    if (isDefault) {
      return '默认使用 $encodingDisplayName (建议手动确认)';
    }
    return '检测为 $encodingDisplayName (置信度: ${(confidence * 100).toInt()}%)';
  }
  
  /// Returns English description.
  String get userDescriptionEn {
    if (hasBom) {
      return 'BOM detected ($encodingDisplayName)';
    }
    if (isHighConfidence) {
      return 'High confidence: $encodingDisplayName';
    }
    if (isDefault) {
      return 'Default: $encodingDisplayName (please verify manually)';
    }
    return 'Detected: $encodingDisplayName (${(confidence * 100).toInt()}% confidence)';
  }
}

/// Result of a decode operation with metadata.
class DecodeResult {
  /// The decoded string content.
  final String content;

  /// The encoding that was used to decode.
  final String usedEncoding;

  /// Whether the decode was successful without fallback.
  final bool success;

  /// Error message if decoding failed or used fallback.
  final String? errorMessage;

  /// Whether fallback encoding was used.
  final bool usedFallback;

  /// Confidence level of the encoding detection (0.0 to 1.0).
  final double confidence;

  /// All tried encodings in order.
  final List<String> triedEncodings;

  const DecodeResult({
    required this.content,
    required this.usedEncoding,
    required this.success,
    this.errorMessage,
    this.usedFallback = false,
    this.confidence = 1.0,
    this.triedEncodings = const [],
  });

  /// Returns true if decoding used a fallback method.
  bool get isFallback => usedFallback || !success;
  
  /// Returns a user-friendly encoding name.
  String get encodingDisplayName {
    switch (usedEncoding.toLowerCase()) {
      case 'utf-8':
        return 'UTF-8';
      case 'gbk':
        return 'GBK (简体中文)';
      case 'gb2312':
        return 'GB2312 (简体中文)';
      case 'utf-16le':
        return 'UTF-16 LE';
      case 'utf-16be':
        return 'UTF-16 BE';
      case 'latin1':
        return 'Latin-1';
      default:
        return usedEncoding.toUpperCase();
    }
  }
}

/// Detects and handles file encoding for Chinese financial institution exports.
///
/// Chinese banks often export CSV files in GBK or GB2312 encoding,
/// while modern apps like Alipay use UTF-8.
class EncodingDetector {
  /// Common Chinese encodings.
  static const utf8 = 'utf-8';
  static const gbk = 'gbk';
  static const gb2312 = 'gb2312';
  static const utf16 = 'utf-16';
  static const utf16le = 'utf-16le';
  static const utf16be = 'utf-16be';

  /// BOM (Byte Order Mark) signatures.
  static const _utf8Bom = [0xEF, 0xBB, 0xBF];
  static const _utf16LeBom = [0xFF, 0xFE];
  static const _utf16BeBom = [0xFE, 0xFF];

  /// Normalize line endings to LF (\n).
  ///
  /// Handles:
  /// - Windows-style CRLF (\r\n)
  /// - Old Mac-style CR (\r)
  /// - Mixed line endings
  ///
  /// This is critical for Android compatibility as banking apps
  /// often export files with Windows-style line endings.
  static String normalizeLineEndings(String content) {
    // First replace CRLF with LF (Windows style)
    // Then replace standalone CR with LF (old Mac style)
    return content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  /// Split content into lines, handling all line ending styles.
  ///
  /// This is a convenience method that normalizes line endings first.
  static List<String> splitLines(String content) {
    return normalizeLineEndings(content).split('\n');
  }

  /// Detects the encoding of the given bytes.
  ///
  /// Returns the most likely encoding name.
  static String detect(Uint8List bytes) {
    // Check for BOM first
    if (_hasBom(bytes, _utf8Bom)) return utf8;
    if (_hasBom(bytes, _utf16LeBom)) return utf16le;
    if (_hasBom(bytes, _utf16BeBom)) return utf16be;

    // Try UTF-8 first
    if (_isValidUtf8(bytes)) return utf8;

    // Check for GBK/GB2312 patterns
    if (_looksLikeGbk(bytes)) return gbk;

    // Default to GBK for Chinese financial files
    return gbk;
  }

  /// Detects encoding with confidence score.
  ///
  /// Returns an EncodingDetectionResult with detailed information.
  static EncodingDetectionResult detectWithConfidence(Uint8List bytes) {
    // Check for BOM first - high confidence
    if (_hasBom(bytes, _utf8Bom)) {
      return EncodingDetectionResult(
        encoding: utf8,
        confidence: 1.0,
        hasBom: true,
        source: 'BOM detected',
      );
    }
    if (_hasBom(bytes, _utf16LeBom)) {
      return EncodingDetectionResult(
        encoding: utf16le,
        confidence: 1.0,
        hasBom: true,
        source: 'BOM detected',
      );
    }
    if (_hasBom(bytes, _utf16BeBom)) {
      return EncodingDetectionResult(
        encoding: utf16be,
        confidence: 1.0,
        hasBom: true,
        source: 'BOM detected',
      );
    }

    // Check if valid UTF-8
    if (_isValidUtf8(bytes)) {
      // Check for Chinese characters in UTF-8
      final chineseCharRatio = _countChineseCharsUtf8(bytes);
      if (chineseCharRatio > 0.1) {
        return EncodingDetectionResult(
          encoding: utf8,
          confidence: 0.95,
          hasBom: false,
          source: 'Valid UTF-8 with Chinese characters',
          chineseCharRatio: chineseCharRatio,
        );
      }
      return EncodingDetectionResult(
        encoding: utf8,
        confidence: 0.9,
        hasBom: false,
        source: 'Valid UTF-8',
      );
    }

    // Check for GBK patterns
    final gbkScore = _calculateGbkScore(bytes);
    if (gbkScore > 0.15) {
      return EncodingDetectionResult(
        encoding: gbk,
        confidence: gbkScore.clamp(0.7, 0.95),
        hasBom: false,
        source: 'GBK patterns detected',
        gbkScore: gbkScore,
      );
    }

    // Default to GBK for Chinese financial files
    return EncodingDetectionResult(
      encoding: gbk,
      confidence: 0.5,
      hasBom: false,
      source: 'Default for Chinese financial files',
      isDefault: true,
    );
  }

  /// Count Chinese character ratio in UTF-8 encoded content.
  static double _countChineseCharsUtf8(Uint8List bytes) {
    try {
      final content = const Utf8Codec().decode(bytes);
      var chineseCount = 0;
      for (final rune in content.runes) {
        // CJK Unified Ideographs range: U+4E00 to U+9FFF
        if (rune >= 0x4E00 && rune <= 0x9FFF) {
          chineseCount++;
        }
      }
      return content.isEmpty ? 0 : chineseCount / content.length;
    } catch (_) {
      return 0;
    }
  }

  /// Calculate GBK pattern score.
  static double _calculateGbkScore(Uint8List bytes) {
    // GBK encoding patterns:
    // - Chinese characters are 2 bytes with first byte 0x81-0xFE
    // - Second byte 0x40-0xFE (excluding 0x7F)
    var gbkPatternCount = 0;
    var totalBytes = 0;
    
    for (var i = 0; i < bytes.length - 1; i++) {
      final b1 = bytes[i];
      final b2 = bytes[i + 1];
      // Check for GBK high byte range
      if (b1 >= 0x81 && b1 <= 0xFE) {
        if ((b2 >= 0x40 && b2 <= 0xFE) && b2 != 0x7F) {
          gbkPatternCount++;
          i++; // Skip next byte
        }
      }
      totalBytes++;
    }
    
    return totalBytes > 0 ? gbkPatternCount / totalBytes : 0;
  }

  /// Decodes bytes to string using detected or specified encoding.
  ///
  /// If [encoding] is provided, uses that encoding.
  /// Otherwise, auto-detects the encoding.
  static String decode(Uint8List bytes, [String? encoding]) {
    final enc = encoding ?? detect(bytes);

    try {
      switch (enc.toLowerCase()) {
        case utf8:
          return const Utf8Codec().decode(bytes);
        case gbk:
        case gb2312:
          return gbk_pkg.gbk.decode(bytes);
        case utf16:
        case utf16le:
          return _decodeUtf16Le(bytes);
        case utf16be:
          return _decodeUtf16Be(bytes);
        default:
          // Try UTF-8 first, then GBK
          try {
            return const Utf8Codec().decode(bytes);
          } catch (_) {
            return gbk_pkg.gbk.decode(bytes);
          }
      }
    } catch (e) {
      // Fallback: try all encodings
      try {
        return const Utf8Codec().decode(bytes);
      } catch (_) {}
      try {
        return gbk_pkg.gbk.decode(bytes);
      } catch (_) {}
      // Last resort: decode as Latin-1 (always succeeds)
      return latin1.decode(bytes);
    }
  }

  /// Decodes bytes to string with detailed result information.
  ///
  /// This method provides more context about the decode operation,
  /// including which encoding was used and whether fallback was needed.
  static DecodeResult decodeWithDetails(Uint8List bytes, [String? encoding]) {
    final detection = encoding != null 
        ? EncodingDetectionResult(encoding: encoding, confidence: 1.0, source: 'User specified')
        : detectWithConfidence(bytes);
    
    final triedEncodings = <String>[];

    try {
      String result;
      switch (detection.encoding.toLowerCase()) {
        case utf8:
          triedEncodings.add(utf8);
          result = const Utf8Codec().decode(bytes);
          return DecodeResult(
            content: result,
            usedEncoding: utf8,
            success: true,
            confidence: detection.confidence,
            triedEncodings: triedEncodings,
          );
        case gbk:
        case gb2312:
          triedEncodings.add(gbk);
          result = gbk_pkg.gbk.decode(bytes);
          return DecodeResult(
            content: result,
            usedEncoding: gbk,
            success: true,
            confidence: detection.confidence,
            triedEncodings: triedEncodings,
          );
        case utf16:
        case utf16le:
          triedEncodings.add(utf16le);
          result = _decodeUtf16Le(bytes);
          return DecodeResult(
            content: result,
            usedEncoding: utf16le,
            success: true,
            confidence: detection.confidence,
            triedEncodings: triedEncodings,
          );
        case utf16be:
          triedEncodings.add(utf16be);
          result = _decodeUtf16Be(bytes);
          return DecodeResult(
            content: result,
            usedEncoding: utf16be,
            success: true,
            confidence: detection.confidence,
            triedEncodings: triedEncodings,
          );
        default:
          // Unknown encoding, try UTF-8 first, then GBK
          triedEncodings.add(utf8);
          try {
            result = const Utf8Codec().decode(bytes);
            return DecodeResult(
              content: result,
              usedEncoding: utf8,
              success: true,
              usedFallback: true,
              errorMessage: 'Unknown encoding, fell back to UTF-8',
              confidence: 0.5,
              triedEncodings: triedEncodings,
            );
          } catch (e) {
            triedEncodings.add(gbk);
            try {
              result = gbk_pkg.gbk.decode(bytes);
              return DecodeResult(
                content: result,
                usedEncoding: gbk,
                success: true,
                usedFallback: true,
                errorMessage: 'Unknown encoding, fell back to GBK: $e',
                confidence: 0.5,
                triedEncodings: triedEncodings,
              );
            } catch (e2) {
              // Both failed
              triedEncodings.add('latin1');
              return DecodeResult(
                content: latin1.decode(bytes),
                usedEncoding: 'latin1',
                success: false,
                errorMessage: 'UTF-8 and GBK decode failed: $e, $e2',
                confidence: 0.0,
                triedEncodings: triedEncodings,
              );
            }
          }
      }
    } catch (e) {
      // Primary decode failed, try fallbacks
      triedEncodings.add(detection.encoding);
      triedEncodings.add(utf8);
      try {
        final result = const Utf8Codec().decode(bytes);
        return DecodeResult(
          content: result,
          usedEncoding: utf8,
          success: true,
          usedFallback: true,
          errorMessage: 'Primary decode failed, fell back to UTF-8: $e',
          confidence: 0.5,
          triedEncodings: triedEncodings,
        );
      } catch (_) {}
      triedEncodings.add(gbk);
      try {
        final result = gbk_pkg.gbk.decode(bytes);
        return DecodeResult(
          content: result,
          usedEncoding: gbk,
          success: true,
          usedFallback: true,
          errorMessage: 'Primary decode failed, fell back to GBK: $e',
          confidence: 0.5,
          triedEncodings: triedEncodings,
        );
      } catch (_) {}
      // Last resort: decode as Latin-1 (always succeeds)
      triedEncodings.add('latin1');
      return DecodeResult(
        content: latin1.decode(bytes),
        usedEncoding: 'latin1',
        success: false,
        errorMessage: 'All decodings failed, using Latin-1: $e',
        confidence: 0.0,
        triedEncodings: triedEncodings,
      );
    }
  }

  /// Checks if bytes have a specific BOM.
  static bool _hasBom(Uint8List bytes, List<int> bom) {
    if (bytes.length < bom.length) return false;
    for (var i = 0; i < bom.length; i++) {
      if (bytes[i] != bom[i]) return false;
    }
    return true;
  }

  /// Checks if bytes are valid UTF-8.
  static bool _isValidUtf8(Uint8List bytes) {
    try {
      const Utf8Codec().decode(bytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Checks if bytes look like GBK encoded Chinese text.
  static bool _looksLikeGbk(Uint8List bytes) {
    return _calculateGbkScore(bytes) > 0.1;
  }

  /// Decode UTF-16 LE.
  static String _decodeUtf16Le(List<int> input) {
    // Skip BOM if present
    var start = 0;
    if (input.length >= 2 && input[0] == 0xFF && input[1] == 0xFE) {
      start = 2;
    }

    final codeUnits = <int>[];
    for (var i = start; i < input.length - 1; i += 2) {
      final codeUnit = input[i] | (input[i + 1] << 8);
      codeUnits.add(codeUnit);
    }

    return String.fromCharCodes(codeUnits);
  }

  /// Decode UTF-16 BE.
  static String _decodeUtf16Be(List<int> input) {
    // Skip BOM if present
    var start = 0;
    if (input.length >= 2 && input[0] == 0xFE && input[1] == 0xFF) {
      start = 2;
    }

    final codeUnits = <int>[];
    for (var i = start; i < input.length - 1; i += 2) {
      final codeUnit = (input[i] << 8) | input[i + 1];
      codeUnits.add(codeUnit);
    }

    return String.fromCharCodes(codeUnits);
  }
}
