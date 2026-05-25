import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:importers/importers.dart';
import 'package:core/core.dart';

void main() {
  group('AlipayImporter', () {
    late AlipayImporter importer;

    setUp(() {
      importer = AlipayImporter();
    });

    group('metadata', () {
      test('has correct name', () {
        expect(importer.name, equals('支付宝'));
      });

      test('has correct sourceId', () {
        expect(importer.sourceId, equals('alipay'));
      });

      test('supports CSV files', () {
        expect(importer.supportedExtensions, contains('.csv'));
      });

      test('has payment app source type', () {
        expect(importer.sourceType, equals(ImportSourceType.paymentApp));
      });
    });

    group('canParse', () {
      test('returns true for valid Alipay CSV', () {
        final csv = _createSampleAlipayCsv();
        final content = Uint8List.fromList(utf8.encode(csv));

        expect(
          importer.canParse(filename: 'alipay_export.csv', content: content),
          isTrue,
        );
      });

      test('returns false for non-CSV files', () {
        final content = Uint8List.fromList([1, 2, 3, 4]);

        expect(
          importer.canParse(filename: 'data.xlsx', content: content),
          isFalse,
        );
      });

      test('returns false for non-Alipay CSV', () {
        final csv = 'Date,Description,Amount\n2026-01-01,Test,100.00';
        final content = Uint8List.fromList(utf8.encode(csv));

        expect(
          importer.canParse(filename: 'other.csv', content: content),
          isFalse,
        );
      });
    });

    group('parse', () {
      test('parses valid Alipay CSV correctly', () async {
        final csv = _createSampleAlipayCsv();
        final content = Uint8List.fromList(utf8.encode(csv));

        final config = ImportConfig(
          targetAccountId: 'test-account',
          defaultCurrencyId: 'CNY',
        );

        final result = await importer.parse(
          content: content,
          config: config,
        );

        expect(result.isSuccess, isTrue);
        expect(result.transactions.length, equals(5));
        expect(result.detectedSource, equals('alipay'));
      });

      test('parses income transactions correctly', () async {
        final csv = '''
交易时间,交易分类,交易对方,商品说明,收/支,金额,收/付款方式,交易状态,交易订单号
2026-05-19 10:30:00,转账,张三,转账收款,收入,+100.00,余额,交易成功,20260519001
''';
        final content = Uint8List.fromList(utf8.encode(csv));

        final config = ImportConfig(
          targetAccountId: 'test-account',
          defaultCurrencyId: 'CNY',
        );

        final result = await importer.parse(
          content: content,
          config: config,
        );

        expect(result.transactions.length, equals(1));
        expect(result.transactions.first.amount, equals(100.0));
      });

      test('parses expense transactions correctly', () async {
        final csv = '''
交易时间,交易分类,交易对方,商品说明,收/支,金额,收/付款方式,交易状态,交易订单号
2026-05-19 12:00:00,餐饮美食,美团外卖,午餐,支出,-35.50,花呗,交易成功,20260519002
''';
        final content = Uint8List.fromList(utf8.encode(csv));

        final config = ImportConfig(
          targetAccountId: 'test-account',
          defaultCurrencyId: 'CNY',
        );

        final result = await importer.parse(
          content: content,
          config: config,
        );

        expect(result.transactions.length, equals(1));
        expect(result.transactions.first.amount, equals(-35.5));
        expect(result.transactions.first.category, equals('food'));
      });

      test('skips non-completed transactions', () async {
        final csv = '''
交易时间,交易分类,交易对方,商品说明,收/支,金额,收/付款方式,交易状态,交易订单号
2026-05-19 10:30:00,购物,淘宝,商品购买,支出,-99.00,余额,交易关闭,20260519003
''';
        final content = Uint8List.fromList(utf8.encode(csv));

        final config = ImportConfig(
          targetAccountId: 'test-account',
          defaultCurrencyId: 'CNY',
        );

        final result = await importer.parse(
          content: content,
          config: config,
        );

        expect(result.transactions.length, equals(0));
        expect(result.stats.skippedCount, equals(1));
      });

      test('applies category mapping from config', () async {
        final csv = '''
交易时间,交易分类,交易对方,商品说明,收/支,金额,收/付款方式,交易状态,交易订单号
2026-05-19 12:00:00,餐饮美食,美团外卖,午餐,支出,-35.50,余额,交易成功,20260519004
''';
        final content = Uint8List.fromList(utf8.encode(csv));

        final config = ImportConfig(
          targetAccountId: 'test-account',
          defaultCurrencyId: 'CNY',
          categoryMapping: {'餐饮美食': 'custom-food-category'},
        );

        final result = await importer.parse(
          content: content,
          config: config,
        );

        expect(result.transactions.first.category, equals('custom-food-category'));
      });

      test('applies account mapping from config', () async {
        final csv = '''
交易时间,交易分类,交易对方,商品说明,收/支,金额,收/付款方式,交易状态,交易订单号
2026-05-19 12:00:00,餐饮美食,美团外卖,午餐,支出,-35.50,余额宝,交易成功,20260519005
''';
        final content = Uint8List.fromList(utf8.encode(csv));

        final config = ImportConfig(
          targetAccountId: 'default-account',
          defaultCurrencyId: 'CNY',
          accountMapping: {'余额宝': 'yuebao-account-id'},
        );

        final result = await importer.parse(
          content: content,
          config: config,
        );

        expect(result.transactions.first.accountId, equals('yuebao-account-id'));
      });

      test('calculates statistics correctly', () async {
        final csv = _createSampleAlipayCsv();
        final content = Uint8List.fromList(utf8.encode(csv));

        final config = ImportConfig(
          targetAccountId: 'test-account',
          defaultCurrencyId: 'CNY',
        );

        final result = await importer.parse(
          content: content,
          config: config,
        );

        expect(result.stats.totalRows, equals(5));
        expect(result.stats.successCount, equals(5));
        expect(result.stats.detectedCurrency, equals('CNY'));
        expect(result.stats.firstDate, isNotNull);
        expect(result.stats.lastDate, isNotNull);
      });
    });

    group('preview', () {
      test('returns preview data', () async {
        final csv = _createSampleAlipayCsv();
        final content = Uint8List.fromList(utf8.encode(csv));

        final preview = await importer.preview(
          content: content,
          maxRows: 3,
        );

        expect(preview.rows.length, equals(3));
        expect(preview.headers.length, equals(9));
        expect(preview.totalRowCount, equals(5));
        expect(preview.detectedSource, equals('alipay'));
      });
    });

    group('validateConfig', () {
      test('returns empty list for valid config', () {
        final config = ImportConfig(
          targetAccountId: 'test-account',
          defaultCurrencyId: 'CNY',
        );

        final errors = importer.validateConfig(config);
        expect(errors, isEmpty);
      });

      test('returns error for missing account ID', () {
        final config = ImportConfig(
          targetAccountId: '',
          defaultCurrencyId: 'CNY',
        );

        final errors = importer.validateConfig(config);
        expect(errors, contains('目标账户ID不能为空'));
      });

      test('returns error for missing currency ID', () {
        final config = ImportConfig(
          targetAccountId: 'test-account',
          defaultCurrencyId: '',
        );

        final errors = importer.validateConfig(config);
        expect(errors, contains('默认货币ID不能为空'));
      });
    });

    group('getDefaultCategoryMappings', () {
      test('returns category mappings', () {
        final mappings = importer.getDefaultCategoryMappings();

        expect(mappings, isNotEmpty);
        expect(mappings['餐饮美食'], equals('food'));
        expect(mappings['交通出行'], equals('transport'));
        expect(mappings['购物'], equals('shopping'));
      });
    });
  });
}

/// Creates a sample Alipay CSV export for testing.
String _createSampleAlipayCsv() {
  return '''
交易时间,交易分类,交易对方,商品说明,收/支,金额,收/付款方式,交易状态,交易订单号
2026-05-19 08:30:00,交通出行,滴滴出行,打车上班,支出,-25.00,余额,交易成功,20260519001
2026-05-19 12:00:00,餐饮美食,美团外卖,午餐,支出,-35.50,花呗,交易成功,20260519002
2026-05-19 14:30:00,转账,张三,转账收款,收入,+100.00,余额宝,交易成功,20260519003
2026-05-19 18:00:00,购物,淘宝,日用品,支出,-89.00,余额,交易成功,20260519004
2026-05-19 20:00:00,休闲娱乐,爱奇艺,会员充值,支出,-15.00,余额宝,交易成功,20260519005
''';
}
