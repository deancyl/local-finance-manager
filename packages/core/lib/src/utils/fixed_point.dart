/// Fixed-point arithmetic for precise financial calculations.
/// 
/// This class provides exact decimal arithmetic to avoid floating-point
/// precision issues (e.g., 0.1 + 0.2 = 0.3 exactly, not 0.30000000000000004).
/// 
/// The value is stored as a rational number (numerator/denominator) using
/// BigInt for intermediate calculations to prevent overflow.
class FixedPoint implements Comparable<FixedPoint> {
  /// The numerator of the rational number
  final int numerator;
  
  /// The denominator of the rational number (always positive)
  final int denominator;
  
  /// Creates a FixedPoint from numerator and denominator.
  /// The denominator must be positive and non-zero.
  const FixedPoint(this.numerator, this.denominator)
      : assert(denominator > 0, 'Denominator must be positive');
  
  /// Creates a FixedPoint from an integer value.
  const FixedPoint.fromInt(int value) : this(value, 1);
  
  /// Creates a FixedPoint from a double value.
  /// WARNING: This should only be used for initialization from known exact
  /// decimal values (e.g., from user input parsed as string).
  /// For string parsing, use [FixedPoint.parse] instead.
  factory FixedPoint.fromDouble(double value) {
    // Convert to string and parse to avoid floating-point errors
    return FixedPoint.parse(value.toString());
  }
  
  /// Parses a decimal string to FixedPoint.
  /// Supports negative numbers and decimal points.
  /// Examples:
  /// - "123" -> FixedPoint(123, 1)
  /// - "12.34" -> FixedPoint(1234, 100)
  /// - "-0.5" -> FixedPoint(-5, 10)
  /// - "0.1" -> FixedPoint(1, 10)
  factory FixedPoint.parse(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw FormatException('Empty string cannot be parsed as FixedPoint');
    }
    
    // Handle negative sign
    bool isNegative = false;
    String numberStr = trimmed;
    if (trimmed.startsWith('-')) {
      isNegative = true;
      numberStr = trimmed.substring(1);
    } else if (trimmed.startsWith('+')) {
      numberStr = trimmed.substring(1);
    }
    
    // Split by decimal point
    final parts = numberStr.split('.');
    if (parts.length > 2) {
      throw FormatException('Invalid decimal format: $value');
    }
    
    final intPart = parts[0];
    final decPart = parts.length == 2 ? parts[1] : '';
    
    // Remove leading zeros but keep at least one digit
    final normalizedInt = intPart.isEmpty ? '0' : intPart.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    
    // Calculate numerator and denominator
    int num;
    int denom;
    
    if (decPart.isEmpty) {
      num = int.parse(normalizedInt);
      denom = 1;
    } else {
      // Remove trailing zeros from decimal part for normalization
      final normalizedDec = decPart.replaceFirst(RegExp(r'0+$'), '');
      if (normalizedDec.isEmpty) {
        num = int.parse(normalizedInt);
        denom = 1;
      } else {
        num = int.parse('$normalizedInt$normalizedDec');
        denom = _pow10(normalizedDec.length);
      }
    }
    
    return FixedPoint(isNegative ? -num : num, denom);
  }
  
  /// Zero value
  static const FixedPoint zero = FixedPoint(0, 1);
  
  /// One value
  static const FixedPoint one = FixedPoint(1, 1);
  
  /// Helper to calculate 10^n
  static int _pow10(int n) {
    int result = 1;
    for (int i = 0; i < n; i++) {
      result *= 10;
    }
    return result;
  }
  
  /// Greatest Common Divisor using Euclidean algorithm
  static int _gcd(int a, int b) {
    a = a.abs();
    b = b.abs();
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a;
  }
  
  /// Returns a normalized (reduced) form of this FixedPoint.
  FixedPoint normalize() {
    if (numerator == 0) {
      return FixedPoint.zero;
    }
    final gcd = _gcd(numerator, denominator);
    if (gcd == 1) {
      return this;
    }
    return FixedPoint(numerator ~/ gcd, denominator ~/ gcd);
  }
  
  /// Converts to double. WARNING: May lose precision.
  double toDouble() => numerator / denominator;
  
  /// Converts to int by truncating towards zero.
  int toInt() => numerator ~/ denominator;
  
  /// Converts to string representation.
  /// Returns integer string if denominator is 1, otherwise decimal string.
  @override
  String toString() {
    if (denominator == 1) {
      return numerator.toString();
    }
    
    final isNegative = numerator < 0;
    final absNum = numerator.abs();
    
    // Calculate integer and fractional parts
    final intPart = absNum ~/ denominator;
    final remainder = absNum % denominator;
    
    // Build fractional part with leading zeros if needed
    final denomStr = denominator.toString();
    final remainderStr = remainder.toString().padLeft(denomStr.length - 1, '0');
    
    // Remove trailing zeros
    final trimmedFraction = remainderStr.replaceFirst(RegExp(r'0+$'), '');
    
    final sign = isNegative ? '-' : '';
    if (trimmedFraction.isEmpty) {
      return '$sign$intPart';
    }
    return '$sign$intPart.$trimmedFraction';
  }
  
  /// Returns a string with exactly [decimalPlaces] decimal places.
  String toStringAsFixed(int decimalPlaces) {
    if (decimalPlaces < 0) {
      throw ArgumentError('decimalPlaces must be non-negative');
    }
    
    final isNegative = numerator < 0;
    final absNum = numerator.abs();
    
    // Scale to desired decimal places
    final scale = _pow10(decimalPlaces);
    final scaledValue = (BigInt.from(absNum) * BigInt.from(scale)) ~/ BigInt.from(denominator);
    final intPart = scaledValue ~/ BigInt.from(scale);
    final fracPart = (scaledValue % BigInt.from(scale)).toString().padLeft(decimalPlaces, '0');
    
    final sign = isNegative ? '-' : '';
    if (decimalPlaces == 0) {
      return '$sign$intPart';
    }
    return '$sign$intPart.$fracPart';
  }
  
  /// Addition with another FixedPoint
  FixedPoint operator +(FixedPoint other) {
    // Use BigInt for intermediate calculation to prevent overflow
    final num1 = BigInt.from(numerator);
    final denom1 = BigInt.from(denominator);
    final num2 = BigInt.from(other.numerator);
    final denom2 = BigInt.from(other.denominator);
    
    final resultNum = num1 * denom2 + num2 * denom1;
    final resultDenom = denom1 * denom2;
    
    // Check if result fits in int
    if (resultNum.abs() > BigInt.from(9223372036854775807) ||
        resultDenom > BigInt.from(9223372036854775807)) {
      throw StateError('FixedPoint overflow in addition');
    }
    
    return FixedPoint(resultNum.toInt(), resultDenom.toInt()).normalize();
  }
  
  /// Subtraction with another FixedPoint
  FixedPoint operator -(FixedPoint other) {
    return this + (-other);
  }
  
  /// Unary negation
  FixedPoint operator -() => FixedPoint(-numerator, denominator);
  
  /// Multiplication with another FixedPoint
  FixedPoint operator *(FixedPoint other) {
    // Use BigInt for intermediate calculation
    final num1 = BigInt.from(numerator);
    final denom1 = BigInt.from(denominator);
    final num2 = BigInt.from(other.numerator);
    final denom2 = BigInt.from(other.denominator);
    
    final resultNum = num1 * num2;
    final resultDenom = denom1 * denom2;
    
    // Check if result fits in int
    if (resultNum.abs() > BigInt.from(9223372036854775807) ||
        resultDenom > BigInt.from(9223372036854775807)) {
      throw StateError('FixedPoint overflow in multiplication');
    }
    
    return FixedPoint(resultNum.toInt(), resultDenom.toInt()).normalize();
  }
  
  /// Division with another FixedPoint
  FixedPoint operator /(FixedPoint other) {
    if (other.numerator == 0) {
      throw IntegerDivisionByZeroException();
    }
    
    // Use BigInt for intermediate calculation
    final num1 = BigInt.from(numerator);
    final denom1 = BigInt.from(denominator);
    final num2 = BigInt.from(other.numerator);
    final denom2 = BigInt.from(other.denominator);
    
    // Division: (a/b) / (c/d) = (a*d) / (b*c)
    // Note: we need to handle the sign of num2 correctly
    final resultNum = num1 * denom2;
    final resultDenom = denom1 * num2;
    
    // Ensure denominator is positive
    if (resultDenom < BigInt.zero) {
      return FixedPoint((-resultNum).toInt(), (-resultDenom).toInt()).normalize();
    }
    
    // Check if result fits in int
    if (resultNum.abs() > BigInt.from(9223372036854775807) ||
        resultDenom > BigInt.from(9223372036854775807)) {
      throw StateError('FixedPoint overflow in division');
    }
    
    return FixedPoint(resultNum.toInt(), resultDenom.toInt()).normalize();
  }
  
  /// Integer division (truncating)
  FixedPoint operator ~/(FixedPoint other) {
    return (this / other).truncate();
  }
  
  /// Modulo operation
  FixedPoint operator %(FixedPoint other) {
    return this - (this ~/ other) * other;
  }
  
  /// Returns the absolute value
  FixedPoint abs() => numerator < 0 ? FixedPoint(-numerator, denominator) : this;
  
  /// Returns the truncated value (towards zero)
  FixedPoint truncate() => FixedPoint(toInt(), 1);
  
  /// Returns the floor value (towards negative infinity)
  FixedPoint floor() {
    if (numerator >= 0) {
      return FixedPoint(numerator ~/ denominator, 1);
    } else {
      // For negative numbers, floor goes more negative
      final intDiv = numerator ~/ denominator;
      final remainder = numerator % denominator;
      if (remainder == 0) {
        return FixedPoint(intDiv, 1);
      }
      return FixedPoint(intDiv - 1, 1);
    }
  }
  
  /// Returns the ceiling value (towards positive infinity)
  FixedPoint ceil() {
    if (numerator <= 0) {
      return FixedPoint(numerator ~/ denominator, 1);
    } else {
      final intDiv = numerator ~/ denominator;
      final remainder = numerator % denominator;
      if (remainder == 0) {
        return FixedPoint(intDiv, 1);
      }
      return FixedPoint(intDiv + 1, 1);
    }
  }
  
  /// Returns the rounded value (to nearest integer, half away from zero)
  FixedPoint round() {
    final absNum = numerator.abs();
    final intDiv = absNum ~/ denominator;
    final remainder = absNum % denominator;
    
    int result;
    if (remainder * 2 >= denominator) {
      result = intDiv + 1;
    } else {
      result = intDiv;
    }
    
    return FixedPoint(numerator < 0 ? -result : result, 1);
  }
  
  /// Comparison operators
  bool operator <(FixedPoint other) {
    // Use BigInt to avoid overflow
    final left = BigInt.from(numerator) * BigInt.from(other.denominator);
    final right = BigInt.from(other.numerator) * BigInt.from(denominator);
    return left < right;
  }
  
  bool operator <=(FixedPoint other) {
    return this == other || this < other;
  }
  
  bool operator >(FixedPoint other) {
    return other < this;
  }
  
  bool operator >=(FixedPoint other) {
    return this == other || this > other;
  }
  
  @override
  bool operator ==(Object other) {
    if (other is! FixedPoint) return false;
    // Normalize both for comparison
    final a = normalize();
    final b = other.normalize();
    return a.numerator == b.numerator && a.denominator == b.denominator;
  }
  
  @override
  int get hashCode {
    final normalized = normalize();
    return Object.hash(normalized.numerator, normalized.denominator);
  }
  
  @override
  int compareTo(FixedPoint other) {
    if (this < other) return -1;
    if (this > other) return 1;
    return 0;
  }
  
  /// Returns true if this value is zero
  bool get isZero => numerator == 0;
  
  /// Returns true if this value is positive
  bool get isPositive => numerator > 0;
  
  /// Returns true if this value is negative
  bool get isNegative => numerator < 0;
  
  /// Returns true if this is an integer (no fractional part)
  bool get isInteger => numerator % denominator == 0;
  
  /// Scales this FixedPoint by an integer factor
  FixedPoint scale(int factor) => FixedPoint(numerator * factor, denominator);
  
  /// Returns the reciprocal (1/this)
  FixedPoint reciprocal() {
    if (numerator == 0) {
      throw IntegerDivisionByZeroException();
    }
    return FixedPoint(denominator, numerator);
  }
  
  /// Rounds to a specific number of decimal places
  FixedPoint roundToDecimalPlaces(int decimalPlaces) {
    if (decimalPlaces < 0) {
      throw ArgumentError('decimalPlaces must be non-negative');
    }
    
    final scale = _pow10(decimalPlaces);
    final scaled = (this * FixedPoint(scale, 1)).round();
    return scaled / FixedPoint(scale, 1);
  }
}
