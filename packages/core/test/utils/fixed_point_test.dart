import 'package:flutter_test/flutter_test.dart';
import 'package:core/src/utils/fixed_point.dart';

void main() {
  group('FixedPoint', () {
    group('construction', () {
      test('creates from numerator and denominator', () {
        final fp = FixedPoint(1, 10);
        expect(fp.numerator, equals(1));
        expect(fp.denominator, equals(10));
      });

      test('creates from int', () {
        final fp = FixedPoint.fromInt(42);
        expect(fp.numerator, equals(42));
        expect(fp.denominator, equals(1));
      });

      test('creates from parse with integer', () {
        final fp = FixedPoint.parse('123');
        expect(fp.toDouble(), equals(123.0));
      });

      test('creates from parse with decimal', () {
        final fp = FixedPoint.parse('12.34');
        expect(fp.toDouble(), equals(12.34));
      });

      test('creates from parse with negative', () {
        final fp = FixedPoint.parse('-0.5');
        expect(fp.toDouble(), equals(-0.5));
      });

      test('creates from parse with leading zeros', () {
        final fp = FixedPoint.parse('0.10');
        expect(fp.toDouble(), equals(0.1));
      });

      test('creates from parse with trailing zeros', () {
        final fp = FixedPoint.parse('1.2000');
        expect(fp.toDouble(), equals(1.2));
      });

      test('zero constant', () {
        expect(FixedPoint.zero.toDouble(), equals(0.0));
      });

      test('one constant', () {
        expect(FixedPoint.one.toDouble(), equals(1.0));
      });
    });

    group('precision demonstration', () {
      test('0.1 + 0.2 equals 0.3 exactly', () {
        // This is the key test showing floating-point vs fixed-point
        final a = FixedPoint.parse('0.1');
        final b = FixedPoint.parse('0.2');
        final sum = a + b;
        
        // Should be exactly 0.3, not 0.30000000000000004
        expect(sum.toDouble(), equals(0.3));
        expect(sum.toString(), equals('0.3'));
        
        // Verify against double's floating-point issue
        expect(0.1 + 0.2, isNot(equals(0.3))); // double has precision issue
      });

      test('0.3 - 0.1 equals 0.2 exactly', () {
        final a = FixedPoint.parse('0.3');
        final b = FixedPoint.parse('0.1');
        final diff = a - b;
        
        expect(diff.toDouble(), equals(0.2));
        expect(diff.toString(), equals('0.2'));
      });

      test('complex calculation preserves precision', () {
        final a = FixedPoint.parse('10.5');
        final b = FixedPoint.parse('3.2');
        final c = FixedPoint.parse('2.5');
        
        // (10.5 + 3.2) * 2.5 = 13.7 * 2.5 = 34.25
        final result = (a + b) * c;
        expect(result.toDouble(), equals(34.25));
        expect(result.toString(), equals('34.25'));
      });
    });

    group('arithmetic operations', () {
      test('addition', () {
        expect(
          FixedPoint.parse('1.5') + FixedPoint.parse('2.5'),
          equals(FixedPoint.parse('4.0')),
        );
        expect(
          FixedPoint.parse('0.1') + FixedPoint.parse('0.2'),
          equals(FixedPoint.parse('0.3')),
        );
      });

      test('subtraction', () {
        expect(
          FixedPoint.parse('5.5') - FixedPoint.parse('2.3'),
          equals(FixedPoint.parse('3.2')),
        );
      });

      test('multiplication', () {
        expect(
          FixedPoint.parse('2.5') * FixedPoint.parse('4.0'),
          equals(FixedPoint.parse('10.0')),
        );
        expect(
          FixedPoint.parse('0.1') * FixedPoint.parse('0.2'),
          equals(FixedPoint.parse('0.02')),
        );
      });

      test('division', () {
        expect(
          FixedPoint.parse('10.0') / FixedPoint.parse('2.5'),
          equals(FixedPoint.parse('4.0')),
        );
        expect(
          FixedPoint.parse('1.0') / FixedPoint.parse('3.0'),
          equals(FixedPoint(1, 3)),
        );
      });

      test('division by zero throws', () {
        expect(
          () => FixedPoint.one / FixedPoint.zero,
          throwsA(isA<IntegerDivisionByZeroException>()),
        );
      });

      test('negation', () {
        expect(-FixedPoint.parse('5.0'), equals(FixedPoint.parse('-5.0')));
        expect(-FixedPoint.parse('-3.0'), equals(FixedPoint.parse('3.0')));
      });

      test('abs', () {
        expect(FixedPoint.parse('-5.0').abs(), equals(FixedPoint.parse('5.0')));
        expect(FixedPoint.parse('3.0').abs(), equals(FixedPoint.parse('3.0')));
      });
    });

    group('comparison', () {
      test('less than', () {
        expect(FixedPoint.parse('1.0') < FixedPoint.parse('2.0'), isTrue);
        expect(FixedPoint.parse('2.0') < FixedPoint.parse('1.0'), isFalse);
        expect(FixedPoint.parse('1.0') < FixedPoint.parse('1.0'), isFalse);
      });

      test('greater than', () {
        expect(FixedPoint.parse('2.0') > FixedPoint.parse('1.0'), isTrue);
        expect(FixedPoint.parse('1.0') > FixedPoint.parse('2.0'), isFalse);
      });

      test('equality', () {
        expect(FixedPoint.parse('1.0'), equals(FixedPoint.parse('1.0')));
        expect(FixedPoint.parse('0.5'), equals(FixedPoint(1, 2)));
        expect(FixedPoint.parse('0.50'), equals(FixedPoint(1, 2)));
      });

      test('equality with normalization', () {
        // 2/4 and 1/2 should be equal after normalization
        expect(FixedPoint(2, 4), equals(FixedPoint(1, 2)));
        expect(FixedPoint(100, 1000), equals(FixedPoint(1, 10)));
      });
    });

    group('rounding', () {
      test('truncate', () {
        expect(FixedPoint.parse('3.7').truncate(), equals(FixedPoint.fromInt(3)));
        expect(FixedPoint.parse('-3.7').truncate(), equals(FixedPoint.fromInt(-3)));
      });

      test('floor', () {
        expect(FixedPoint.parse('3.7').floor(), equals(FixedPoint.fromInt(3)));
        expect(FixedPoint.parse('-3.7').floor(), equals(FixedPoint.fromInt(-4)));
      });

      test('ceil', () {
        expect(FixedPoint.parse('3.7').ceil(), equals(FixedPoint.fromInt(4)));
        expect(FixedPoint.parse('-3.7').ceil(), equals(FixedPoint.fromInt(-3)));
      });

      test('round', () {
        expect(FixedPoint.parse('3.4').round(), equals(FixedPoint.fromInt(3)));
        expect(FixedPoint.parse('3.5').round(), equals(FixedPoint.fromInt(4)));
        expect(FixedPoint.parse('3.6').round(), equals(FixedPoint.fromInt(4)));
        expect(FixedPoint.parse('-3.5').round(), equals(FixedPoint.fromInt(-4)));
      });

      test('roundToDecimalPlaces', () {
        expect(
          FixedPoint.parse('1.234').roundToDecimalPlaces(2).toDouble(),
          equals(1.23),
        );
        expect(
          FixedPoint.parse('1.235').roundToDecimalPlaces(2).toDouble(),
          equals(1.24),
        );
      });
    });

    group('string conversion', () {
      test('toString with integer', () {
        expect(FixedPoint.fromInt(42).toString(), equals('42'));
      });

      test('toString with decimal', () {
        expect(FixedPoint.parse('12.34').toString(), equals('12.34'));
      });

      test('toString with negative', () {
        expect(FixedPoint.parse('-5.5').toString(), equals('-5.5'));
      });

      test('toStringAsFixed', () {
        expect(FixedPoint.parse('1.2').toStringAsFixed(3), equals('1.200'));
        expect(FixedPoint.parse('1.2345').toStringAsFixed(2), equals('1.23'));
      });
    });

    group('properties', () {
      test('isZero', () {
        expect(FixedPoint.zero.isZero, isTrue);
        expect(FixedPoint.parse('0.0').isZero, isTrue);
        expect(FixedPoint.parse('1.0').isZero, isFalse);
      });

      test('isPositive', () {
        expect(FixedPoint.parse('1.0').isPositive, isTrue);
        expect(FixedPoint.parse('-1.0').isPositive, isFalse);
        expect(FixedPoint.zero.isPositive, isFalse);
      });

      test('isNegative', () {
        expect(FixedPoint.parse('-1.0').isNegative, isTrue);
        expect(FixedPoint.parse('1.0').isNegative, isFalse);
      });

      test('isInteger', () {
        expect(FixedPoint.fromInt(42).isInteger, isTrue);
        expect(FixedPoint.parse('5.0').isInteger, isTrue);
        expect(FixedPoint.parse('5.5').isInteger, isFalse);
      });
    });

    group('financial calculations', () {
      test('percentage calculation', () {
        final amount = FixedPoint.parse('1000.00');
        final rate = FixedPoint.parse('5.5'); // 5.5%
        final percentage = rate / FixedPoint.fromInt(100);
        final result = amount * percentage;
        
        expect(result.toDouble(), equals(55.0));
      });

      test('investment return calculation', () {
        final costBasis = FixedPoint.parse('10000.00');
        final currentValue = FixedPoint.parse('12500.00');
        final gain = currentValue - costBasis;
        final gainPercent = (gain / costBasis) * FixedPoint.fromInt(100);
        
        expect(gain.toDouble(), equals(2500.0));
        expect(gainPercent.toDouble(), equals(25.0));
      });

      test('currency conversion', () {
        final amount = FixedPoint.parse('100.00');
        final rate = FixedPoint.parse('7.25'); // USD to CNY
        final converted = amount * rate;
        
        expect(converted.toDouble(), equals(725.0));
      });

      test('compound interest (simple)', () {
        final principal = FixedPoint.parse('1000.00');
        final rate = FixedPoint.parse('0.05'); // 5% annual
        final years = FixedPoint.fromInt(3);
        
        final interest = principal * rate * years;
        expect(interest.toDouble(), equals(150.0));
        
        final total = principal + interest;
        expect(total.toDouble(), equals(1150.0));
      });

      test('average cost calculation', () {
        // Buy 100 shares at $10, then 50 shares at $12
        final firstBuy = FixedPoint.parse('100') * FixedPoint.parse('10');
        final secondBuy = FixedPoint.parse('50') * FixedPoint.parse('12');
        final totalCost = firstBuy + secondBuy;
        final totalShares = FixedPoint.parse('150');
        final avgCost = totalCost / totalShares;
        
        expect(avgCost.toDouble(), equals(10.666666666666667));
        // Or more precisely: avgCost = FixedPoint(32, 3) ≈ 10.67
        expect(avgCost.toString(), equals('10.666666666666667'));
      });
    });

    group('edge cases', () {
      test('very small numbers', () {
        final fp = FixedPoint.parse('0.001');
        expect(fp.toDouble(), equals(0.001));
      });

      test('very large numbers', () {
        final fp = FixedPoint.parse('999999999.99');
        expect(fp.toDouble(), equals(999999999.99));
      });

      test('normalization of zero', () {
        expect(FixedPoint(0, 100).normalize(), equals(FixedPoint.zero));
      });

      test('reciprocal', () {
        expect(FixedPoint.parse('4.0').reciprocal(), equals(FixedPoint(1, 4)));
        expect(FixedPoint(1, 4).reciprocal(), equals(FixedPoint.fromInt(4)));
      });

      test('scale', () {
        expect(FixedPoint.parse('1.5').scale(3), equals(FixedPoint.parse('4.5')));
      });
    });
  });
}