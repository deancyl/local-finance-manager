/// Configuration for import operations.
class ImportConfig {
  /// Target account ID for imported transactions.
  final String targetAccountId;

  /// Default currency ID (e.g., 'CNY').
  final String defaultCurrencyId;

  /// Category mapping from source categories to app categories.
  ///
  /// Key: source category name (e.g., "餐饮美食")
  /// Value: app category ID
  final Map<String, String> categoryMapping;

  /// Account mapping from source accounts to app accounts.
  ///
  /// Key: source account name (e.g., "余额宝")
  /// Value: app account ID
  final Map<String, String> accountMapping;

  /// Whether to skip duplicate transactions.
  final bool skipDuplicates;

  /// Whether to auto-categorize transactions.
  final bool autoCategorize;

  /// Date format override (e.g., 'yyyy-MM-dd').
  final String? dateFormatOverride;

  /// Amount format override.
  final AmountFormat? amountFormatOverride;

  /// Custom field mappings.
  ///
  /// Key: source column name
  /// Value: target field name
  final Map<String, String> fieldMapping;

  /// Rows to skip (e.g., header rows).
  final int skipRows;

  /// Maximum rows to import (0 = all).
  final int maxRows;

  /// Whether to create missing categories.
  final bool createMissingCategories;

  /// Whether to create missing accounts.
  final bool createMissingAccounts;

  const ImportConfig({
    required this.targetAccountId,
    required this.defaultCurrencyId,
    this.categoryMapping = const {},
    this.accountMapping = const {},
    this.skipDuplicates = true,
    this.autoCategorize = true,
    this.dateFormatOverride,
    this.amountFormatOverride,
    this.fieldMapping = const {},
    this.skipRows = 0,
    this.maxRows = 0,
    this.createMissingCategories = false,
    this.createMissingAccounts = false,
  });

  ImportConfig copyWith({
    String? targetAccountId,
    String? defaultCurrencyId,
    Map<String, String>? categoryMapping,
    Map<String, String>? accountMapping,
    bool? skipDuplicates,
    bool? autoCategorize,
    String? dateFormatOverride,
    AmountFormat? amountFormatOverride,
    Map<String, String>? fieldMapping,
    int? skipRows,
    int? maxRows,
    bool? createMissingCategories,
    bool? createMissingAccounts,
  }) {
    return ImportConfig(
      targetAccountId: targetAccountId ?? this.targetAccountId,
      defaultCurrencyId: defaultCurrencyId ?? this.defaultCurrencyId,
      categoryMapping: categoryMapping ?? this.categoryMapping,
      accountMapping: accountMapping ?? this.accountMapping,
      skipDuplicates: skipDuplicates ?? this.skipDuplicates,
      autoCategorize: autoCategorize ?? this.autoCategorize,
      dateFormatOverride: dateFormatOverride ?? this.dateFormatOverride,
      amountFormatOverride: amountFormatOverride ?? this.amountFormatOverride,
      fieldMapping: fieldMapping ?? this.fieldMapping,
      skipRows: skipRows ?? this.skipRows,
      maxRows: maxRows ?? this.maxRows,
      createMissingCategories: createMissingCategories ?? this.createMissingCategories,
      createMissingAccounts: createMissingAccounts ?? this.createMissingAccounts,
    );
  }

  /// Get category ID for a source category.
  String? getCategoryId(String sourceCategory) {
    return categoryMapping[sourceCategory];
  }

  /// Get account ID for a source account.
  String? getAccountId(String sourceAccount) {
    return accountMapping[sourceAccount];
  }
}

/// Amount format options.
enum AmountFormat {
  /// Standard format: 1234.56
  standard,

  /// Chinese format with 万: 1.23万
  chinese,

  /// Format with comma separator: 1,234.56
  commaSeparated,

  /// Format with parentheses for negative: (1234.56)
  parenthesesNegative,
}