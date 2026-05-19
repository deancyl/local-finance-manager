import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Import source type enumeration.
enum ImportSourceType {
  bank('BANK', '银行'),
  paymentApp('PAYMENT_APP', '支付应用'),
  csv('CSV', 'CSV文件'),
  api('API', 'API接口');

  final String code;
  final String labelZh;

  const ImportSourceType(this.code, this.labelZh);
}

/// Import source model representing a financial institution or data source.
class ImportSource extends Equatable {
  final String id;
  final String name;
  final ImportSourceType sourceType;
  final String? institutionId;
  final String? accountId;
  final String? config;
  final DateTime? lastImportAt;
  final bool isActive;
  final DateTime createdAt;

  ImportSource({
    String? id,
    required this.name,
    required this.sourceType,
    this.institutionId,
    this.accountId,
    this.config,
    this.lastImportAt,
    this.isActive = true,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Predefined Chinese financial institutions.
  static const alipay = 'alipay';
  static const wechatPay = 'wechat_pay';
  static const icbc = 'icbc';
  static const ccb = 'ccb';
  static const boc = 'boc';

  ImportSource copyWith({
    String? id,
    String? name,
    ImportSourceType? sourceType,
    String? institutionId,
    String? accountId,
    String? config,
    DateTime? lastImportAt,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return ImportSource(
      id: id ?? this.id,
      name: name ?? this.name,
      sourceType: sourceType ?? this.sourceType,
      institutionId: institutionId ?? this.institutionId,
      accountId: accountId ?? this.accountId,
      config: config ?? this.config,
      lastImportAt: lastImportAt ?? this.lastImportAt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'source_type': sourceType.code,
      'institution_id': institutionId,
      'account_id': accountId,
      'config': config,
      'last_import_at': lastImportAt?.millisecondsSinceEpoch,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory ImportSource.fromJson(Map<String, dynamic> json) {
    return ImportSource(
      id: json['id'] as String,
      name: json['name'] as String,
      sourceType: ImportSourceType.values.firstWhere(
        (e) => e.code == json['source_type'],
        orElse: () => ImportSourceType.csv,
      ),
      institutionId: json['institution_id'] as String?,
      accountId: json['account_id'] as String?,
      config: json['config'] as String?,
      lastImportAt: json['last_import_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['last_import_at'] as int)
          : null,
      isActive: json['is_active'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        sourceType,
        institutionId,
        accountId,
        config,
        lastImportAt,
        isActive,
        createdAt,
      ];
}