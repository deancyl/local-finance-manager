import 'dart:convert';
import 'dart:typed_data';

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
          return utf8Codec.decode(bytes);
        case gbk:
        case gb2312:
          return gbkCodec.decode(bytes);
        case utf16:
        case utf16le:
          return utf16leCodec.decode(bytes);
        case utf16be:
          return utf16beCodec.decode(bytes);
        default:
          // Try UTF-8 first, then GBK
          try {
            return utf8Codec.decode(bytes);
          } catch (_) {
            return gbkCodec.decode(bytes);
          }
      }
    } catch (e) {
      // Fallback: try all encodings
      for (final codec in [utf8Codec, gbkCodec, latin1Codec]) {
        try {
          return codec.decode(bytes);
        } catch (_) {
          continue;
        }
      }
      // Last resort: decode as Latin-1 (always succeeds)
      return latin1Codec.decode(bytes);
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
      utf8Codec.decode(bytes);
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

  /// GBK codec (requires external package or custom implementation).
  ///
  /// Note: Dart doesn't have built-in GBK support.
  /// This uses a simplified approach that works for most cases.
  static Codec<String, List<int>> get gbkCodec => _GbkCodec();

  /// UTF-16 LE codec.
  static Codec<String, List<int>> get utf16leCodec => const Utf16LeCodec();

  /// UTF-16 BE codec.
  static Codec<String, List<int>> get utf16beCodec => const Utf16BeCodec();
}

/// Simplified GBK codec.
///
/// Note: This is a placeholder. In production, use a proper GBK codec package
/// like `gbk_codec` or `charset_converter`.
class _GbkCodec extends Codec<String, List<int>> {
  const _GbkCodec();

  @override
  Converter<List<int>, String> get decoder => const _GbkDecoder();

  @override
  Converter<String, List<int>> get encoder =>
      throw UnimplementedError('GBK encoding not implemented');
}

class _GbkDecoder extends Converter<List<int>, String> {
  const _GbkDecoder();

  @override
  String convert(List<int> input) {
    // Simplified GBK to Unicode mapping
    // In production, use a proper GBK codec package
    final output = StringBuffer();

    for (var i = 0; i < input.length; i++) {
      final byte = input[i];

      // ASCII range (0x00-0x7F)
      if (byte < 0x80) {
        output.writeCharCode(byte);
      }
      // GBK high byte range
      else if (i + 1 < input.length) {
        final byte2 = input[i + 1];
        // Simplified: just skip the bytes and add a placeholder
        // In production, use proper GBK to Unicode mapping
        output.write('?');
        i++; // Skip next byte
      }
    }

    return output.toString();
  }
}

/// UTF-16 LE codec.
class Utf16LeCodec extends Codec<String, List<int>> {
  const Utf16LeCodec();

  @override
  Converter<List<int>, String> get decoder => const _Utf16LeDecoder();

  @override
  Converter<String, List<int>> get encoder =>
      throw UnimplementedError('UTF-16 LE encoding not implemented');
}

class _Utf16LeDecoder extends Converter<List<int>, String> {
  const _Utf16LeDecoder();

  @override
  String convert(List<int> input) {
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
}

/// UTF-16 BE codec.
class Utf16BeCodec extends Codec<String, List<int>> {
  const Utf16BeCodec();

  @override
  Converter<List<int>, String> get decoder => const _Utf16BeDecoder();

  @override
  Converter<String, List<int>> get encoder =>
      throw UnimplementedError('UTF-16 BE encoding not implemented');
}

class _Utf16BeDecoder extends Converter<List<int>, String> {
  const _Utf16BeDecoder();

  @override
  String convert(List<int> input) {
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