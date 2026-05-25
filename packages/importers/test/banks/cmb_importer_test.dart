import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:importers/importers.dart';
import 'package:core/core.dart';

void main() {
  group('CmbImporter', () {
    late CmbImporter importer;

    setUp(() {
      importer = CmbImporter();
    });

    group('metadata', () {
      test('has correct name', () {
        expect(importer.name, equals('招商银行'));
      });

      test('has correct sourceId', () {
        expect(importer.sourceId, equals('cmb'));
      });

      test('supports CSV files', () {
        expect(importer.supportedExtensions, contains('.csv'));
      });

      test('has bank source type', () {
        expect(importer.sourceType, equals(ImportSourceType.bank));
      });
    });

    group('canParse', () {
      test('returns true for valid CMB CSV with headers', () {
        final csv = _createSampleCmbCsv();
        final content = Uint8List.fromList(utf8.encode(csv));

        expect(
          importer.canParse(filename: 'cmb_export.csv', content: content),
          isTrue,
        );
      });

      test('returns true for CMB CSV with bank name in header', () {
        final csv = '招商银行交易明细\n交易日期,交易金额,账户余额\n20260519,100.00,1000.00';
        final content = Uint8List.fromList(utf8.encode(csv));

        expect(
          importer.canParse(filename: 'cmb.csv', content: content),
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

      test('returns false for non-CMB CSV', () {
        final csv = 'Date,Description,Amount\n2026-01-01,Test,100.00';
        final content = Uint8List.fromList(utf8.encode(csv));

        expect(
          importer.canParse(filename: 'other.csv', content: content),
          isFalse,
        );
      });
    });

    group('parse', () {
      test('parses valid CMB CSV correctly', () async {
        final csv = _createSampleCmbCsv();
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
        expect(result.detectedSource, equals('cmb'));
      });

      test('parses income transactions correctly', () async {
        final csv = '''
交易日期,交易金额,账户余额,交易摘要,对方户名
20260519,+1000.00,5000.00,转账收款,张三
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
        expect(result.transactions.first.amount, equals(1000.0));
      });

      test('parses expense transactions correctly', () async {
        final csv = '''
交易日期,交易金额,账户余额,交易摘要
20260519,-35.50,1000.00,ATM取款
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
      });

      test('parses separate income/expense columns', () async {
        final csv = '''
交易日期,收入,支出,账户余额,交易摘要
20260519,100.00,,1100.00,存款
20260520,,50.00,1050.00,消费
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

        expect(result.transactions.length, equals(2));
        expect(result.transactions[0].amount, equals(100.0));
        expect(result.transactions[1].amount, equals(-50.0));
      });

      test('skips rows with zero amount', () async {
        final csv = '''
交易日期,交易金额,账户余额,交易摘要
20260519,0.00,1000.00,查询
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
      });

      test('calculates statistics correctly', () async {
        final csv = _createSampleCmbCsv();
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

      test('handles different date formats', () async {
        final csv = '''
交易日期,交易金额,账户余额,交易摘要
2026-05-19,100.00,1000.00,测试
20260520,200.00,1200.00,测试2
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

        expect(result.transactions.length, equals(2));
      });

      test('handles reference number', () async {
        final csv = '''
交易日期,交易金额,账户余额,交易摘要,交易流水号
20260519,100.00,1000.00,转账,REF123456
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
        expect(result.transactions.first.externalId, contains('REF123456'));
      });
    });

    group('preview', () {
      test('returns preview data', () async {
        final csv = _createSampleCmbCsv();
        final content = Uint8List.fromList(utf8.encode(csv));

        final preview = await importer.preview(
          content: content,
          maxRows: 3,
        );

        expect(preview.rows.length, equals(3));
        expect(preview.totalRowCount, equals(5));
        expect(preview.detectedSource, equals('cmb'));
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
        expect(mappings['转账'], equals('transfer'));
        expect(mappings['工资'], equals('salary'));
        expect(mappings['ATM取款'], equals('cash'));
      });
    });
  });
}

/// Creates a sample CMB CSV export for testing.
String _createSampleCmbCsv() {
  return '''
交易日期,交易金额,账户余额,交易摘要,对方户名,交易类型
20260519,-25.00,1000.00,POS消费,超市,消费
20260520,-35.50,964.50,网购,淘宝,消费
20260521,+5000.00,5964.50,工资,公司,代发
20260522,-100.00,5864.50,ATM取款,,取款
20260523,-15.00,5849.50,话费,中国移动,缴费
''';
}
