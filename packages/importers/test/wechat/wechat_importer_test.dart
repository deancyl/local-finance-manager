import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:importers/importers.dart';
import 'package:core/core.dart';
import 'package:core/core.dart';

void main() {
  group('WeChatPayImporter', () {
    late WeChatPayImporter importer;

    setUp(() {
      importer = WeChatPayImporter();
    });

    group('metadata', () {
      test('has correct name', () {
        expect(importer.name, equals('WeChat Pay'));
      });

      test('has correct sourceId', () {
        expect(importer.sourceId, equals('wechat_pay'));
      });

      test('supports CSV files', () {
        expect(importer.supportedExtensions, contains('.csv'));
      });

      test('has payment app source type', () {
        expect(importer.sourceType, equals(ImportSourceType.paymentApp));
      });
    });

    group('canParse', () {
      test('returns true for valid WeChat Pay CSV', () {
        final csv = _createSampleWeChatPayCsv();
        final content = Uint8List.fromList(utf8.encode(csv));

        expect(
          importer.canParse(filename: 'wechat_export.csv', content: content),
          isTrue,
        );
      });

      test('returns true for WeChat Pay CSV with backtick prefix', () {
        final csv = '`' + _createSampleWeChatPayCsv();
        final content = Uint8List.fromList(utf8.encode(csv));

        expect(
          importer.canParse(filename: 'wechat_export.csv', content: content),
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

      test('returns false for non-WeChat Pay CSV', () {
        final csv = 'Date,Description,Amount\n2026-01-01,Test,100.00';
        final content = Uint8List.fromList(utf8.encode(csv));

        expect(
          importer.canParse(filename: 'other.csv', content: content),
          isFalse,
        );
      });
    });

    group('parse', () {
      test('parses valid WeChat Pay CSV correctly', () async {
        final csv = _createSampleWeChatPayCsv();
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
        expect(result.transactions.length, equals(6));
        expect(result.detectedSource, equals('wechat_pay'));
      });

      test('parses income transactions correctly', () async {
        final csv = '''
交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,交易单号,商户单号,备注
2026-05-19 10:30:00,转账,张三,转账收款,收入,¥100.00,零钱,支付成功,4200001234567890,/,
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
交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,交易单号,商户单号,备注
2026-05-19 12:00:00,商户消费,美团外卖,午餐,支出,¥35.50,零钱,支付成功,4200001234567891,/,
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

      test('parses Lingqiantong (零钱通) transactions correctly', () async {
        final csv = '''
交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,交易单号,商户单号,备注
2026-05-19 09:00:00,零钱通转入,/,/,支出,¥1000.00,零钱,已转账,4200001234567892,/,
2026-05-19 09:05:00,零钱通收益,/,/,收入,¥0.35,零钱通,已到账,4200001234567893,/,
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
        // 零钱通转入 is an expense (transfer out of 零钱)
        expect(result.transactions[0].amount, equals(-1000.0));
        // 零钱通收益 is income
        expect(result.transactions[1].amount, equals(0.35));
      });

      test('parses red packet (红包) transactions correctly', () async {
        final csv = '''
交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,交易单号,商户单号,备注
2026-05-19 08:00:00,微信红包,李四,新年红包,收入,¥8.88,零钱,已领取,4200001234567894,/,
2026-05-19 08:30:00,发红包,王五,生日红包,支出,¥66.66,零钱,已发送,4200001234567895,/,
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
        expect(result.transactions[0].amount, equals(8.88));
        expect(result.transactions[1].amount, equals(-66.66));
      });

      test('parses small amounts correctly', () async {
        final csv = '''
交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,交易单号,商户单号,备注
2026-05-19 10:00:00,商户消费,便利店,矿泉水,支出,¥0.01,零钱,支付成功,4200001234567896,/,
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
        expect(result.transactions.first.amount, equals(-0.01));
      });

      test('handles backtick prefix in CSV', () async {
        final csv = '`' + _createSampleWeChatPayCsv();
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
        expect(result.transactions.length, equals(6));
      });

      test('calculates statistics correctly', () async {
        final csv = _createSampleWeChatPayCsv();
        final content = Uint8List.fromList(utf8.encode(csv));

        final config = ImportConfig(
          targetAccountId: 'test-account',
          defaultCurrencyId: 'CNY',
        );

        final result = await importer.parse(
          content: content,
          config: config,
        );

        expect(result.stats.totalRows, equals(6));
        expect(result.stats.successCount, equals(6));
        expect(result.stats.detectedCurrency, equals('CNY'));
        expect(result.stats.firstDate, isNotNull);
        expect(result.stats.lastDate, isNotNull);
      });

      test('extracts external ID from transaction ID', () async {
        final csv = '''
交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,交易单号,商户单号,备注
2026-05-19 10:00:00,商户消费,测试商户,测试商品,支出,¥10.00,零钱,支付成功,4200001234567897,/,
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

        expect(result.transactions.first.externalId, equals('4200001234567897'));
      });
    });

    group('preview', () {
      test('returns preview data', () async {
        final csv = _createSampleWeChatPayCsv();
        final content = Uint8List.fromList(utf8.encode(csv));

        final preview = await importer.preview(
          content: content,
          maxRows: 3,
        );

        expect(preview.rows.length, equals(3));
        expect(preview.headers.length, equals(11));
        expect(preview.totalRowCount, equals(6));
        expect(preview.detectedSource, equals('wechat_pay'));
      });

      test('includes parsed preview fields', () async {
        final csv = '''
交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,交易单号,商户单号,备注
2026-05-19 10:00:00,商户消费,美团外卖,午餐,支出,¥35.50,零钱,支付成功,4200001234567898,/,
''';
        final content = Uint8List.fromList(utf8.encode(csv));

        final preview = await importer.preview(
          content: content,
          maxRows: 10,
        );

        expect(preview.rows.first['_parsed_date'], equals('2026-05-19 10:00:00'));
        expect(preview.rows.first['_parsed_amount'], equals('¥35.50'));
        expect(preview.rows.first['_parsed_type'], equals('支出'));
        expect(preview.rows.first['_parsed_payee'], equals('美团外卖'));
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
        expect(errors, contains('必须指定目标账户ID'));
      });

      test('returns error for missing currency ID', () {
        final config = ImportConfig(
          targetAccountId: 'test-account',
          defaultCurrencyId: '',
        );

        final errors = importer.validateConfig(config);
        expect(errors, contains('必须指定默认货币ID'));
      });
    });

    group('getDefaultCategoryMappings', () {
      test('returns category mappings', () {
        final mappings = importer.getDefaultCategoryMappings();

        expect(mappings, isNotEmpty);
        expect(mappings['商户消费'], equals('expense:shopping'));
        expect(mappings['转账'], equals('transfer'));
        expect(mappings['微信红包'], equals('income:gift'));
        expect(mappings['零钱通转入'], equals('transfer'));
      });
    });
  });
}

/// Creates a sample WeChat Pay CSV export for testing.
String _createSampleWeChatPayCsv() {
  return '''
交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,交易单号,商户单号,备注
2026-05-19 08:30:00,商户消费,滴滴出行,打车上班,支出,¥25.00,零钱,支付成功,4200001234567801,/,
2026-05-19 12:00:00,商户消费,美团外卖,午餐,支出,¥35.50,零钱,支付成功,4200001234567802,/,
2026-05-19 14:30:00,转账,张三,转账收款,收入,¥100.00,零钱,已收钱,4200001234567803,/,
2026-05-19 18:00:00,商户消费,淘宝,日用品,支出,¥89.00,银行卡(招商银行),支付成功,4200001234567804,/,
2026-05-19 20:00:00,微信红包,李四,生日红包,收入,¥8.88,零钱,已领取,4200001234567805,/,
2026-05-19 22:00:00,零钱通转入,/,/,支出,¥500.00,零钱,已转账,4200001234567806,/,
''';
}
