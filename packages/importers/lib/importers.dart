/// Chinese financial institution importers.
///
/// This package provides importers for:
/// - Alipay (支付宝)
/// - WeChat Pay (微信支付)
/// - ICBC (工商银行)
/// - CCB (建设银行)
/// - BOC (中国银行)
library importers;

export 'src/base/importer_base.dart';
export 'src/base/import_result.dart';
export 'src/base/import_config.dart';
export 'src/alipay/alipay_importer.dart';
export 'src/wechat/wechat_importer.dart';
export 'src/banks/icbc_importer.dart';
export 'src/banks/ccb_importer.dart';
export 'src/banks/boc_importer.dart';
export 'src/utils/csv_parser.dart';
export 'src/utils/encoding_detector.dart';
export 'src/utils/date_parser.dart';
export 'src/utils/amount_parser.dart';
export 'src/utils/duplicate_detector.dart';