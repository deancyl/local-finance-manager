import 'dart:convert';
import 'dart:typed_data';
import 'package:gbk_codec/gbk_codec.dart' as gbk_pkg;

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
    // GBK encoding patterns:
    // - Chinese characters are 2 bytes with first byte 0x81-0xFE
    // - Second byte 0x40-0xFE (excluding 0x7F)
    var gbkPatternCount = 0;
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
    }
    // If we found significant GBK patterns, it's likely GBK
    return gbkPatternCount > bytes.length * 0.1;
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
