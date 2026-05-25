import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:importers/importers.dart';
import 'package:core/core.dart';

void main() {
  group('AbcImporter', () {
    late AbcImporter importer;

    setUp(() {
      importer = AbcImporter();
    });

    group('metadata', () {
      test('has correct name', () {
        expect(importer.name, equals('农业银行'));
      });

      test('has correct sourceId', () {
        expect(importer.sourceId, equals('abc'));
      });

      test('supports CSV files', () {
        expect(importer.supportedExtensions, contains('.csv'));
      });

      test('has bank source type', () {
        expect(importer.sourceType, equals(ImportSourceType.bank));
      });
    });

    group('canParse', () {
      test('returns true for valid ABC CSV with headers', () {
        final csv = _createSampleAbcCsv();
        final content = Uint8List.fromList(utf8.encode(csv));

        expect(
          importer.canParse(filename: 'abc_export.csv', content: content),
          isTrue,
        );
      });

      test('returns true for ABC CSV with bank name in header', () {
        final csv = '中国农业银行交易明细\n交易日期,交易金额,账户余额\n20260519,100.00,1000.00';
        final content = Uint8List.fromList(utf8.encode(csv));

        expect(
          importer.canParse(filename: 'abc.csv', content: content),
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

      test('returns false for non-ABC CSV', () {
        final csv = 'Date,Description,Amount\n2026-01-01,Test,100.00';
        final content = Uint8List.fromList(utf8.encode(csv));

        expect(
          importer.canParse(filename: 'other.csv', content: content),
          isFalse,
        );
      });
    });

    group('parse', () {
      test('parses valid ABC CSV correctly', () async {
        final csv = _createSampleAbcCsv();
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
        expect(result.detectedSource, equals('abc'));
      });

      test('parses income transactions correctly', () async {
        final csv = '''
交易日期,交易金额,账户余额,交易摘要,对方户名
20260519,+1000.00,5000.00,转账收款,李四
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
20260519,-50.00,1000.00,POS消费
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
        expect(result.transactions.first.amount, equals(-50.0));
      });

      test('parses separate income/expense columns', () async {
        final csv = '''
交易日期,存入金额,取出金额,账户余额,交易摘要
20260519,200.00,,1200.00,存款
20260520,,80.00,1120.00,取款
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
        expect(result.transactions[0].amount, equals(200.0));
        expect(result.transactions[1].amount, equals(-80.0));
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
        final csv = _createSampleAbcCsv();
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

      test('handles counterparty information', () async {
        final csv = '''
交易日期,交易金额,账户余额,交易摘要,对方户名,对方账号
20260519,100.00,1000.00,转账,张三,6228481234567890
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
        expect(result.transactions.first.payee, equals('张三'));
        expect(result.transactions.first.memo, contains('6228481234567890'));
      });

      test('handles "--" as empty value', () async {
        final csv = '''
交易日期,存入金额,取出金额,账户余额,交易摘要
20260519,100.00,--,1100.00,存款
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
    });

    group('preview', () {
      test('returns preview data', () async {
        final csv = _createSampleAbcCsv();
        final content = Uint8List.fromList(utf8.encode(csv));

        final preview = await importer.preview(
          content: content,
          maxRows: 3,
        );

        expect(preview.rows.length, equals(3));
        expect(preview.totalRowCount, equals(5));
        expect(preview.detectedSource, equals('abc'));
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
        expect(mappings['金穗卡'], equals('shopping'));
        expect(mappings['惠农卡'], equals('transfer'));
      });
    });
  });
}

/// Creates a sample ABC CSV export for testing.
String _createSampleAbcCsv() {
  return '''
交易日期,交易金额,账户余额,交易摘要,对方户名,交易类型
20260519,-30.00,1000.00,POS消费,便利店,消费
20260520,-45.00,955.00,网购,京东,消费
20260521,+6000.00,6955.00,工资,公司财务,代发
20260522,-200.00,6755.00,ATM取款,,取款
20260523,-20.00,6735.00,水电费,供电局,缴费
''';
}
