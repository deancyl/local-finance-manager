/// Immutable filter state for transaction filtering.
class TransactionFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? categoryId;
  final String? accountId;
  final String? searchQuery;
  final double? minAmount;
  final double? maxAmount;

  const TransactionFilter({
    this.startDate,
    this.endDate,
    this.categoryId,
    this.accountId,
    this.searchQuery,
    this.minAmount,
    this.maxAmount,
  });

  /// Creates a copy with updated fields.
  /// Use clear* parameters to explicitly set a field to null.
  TransactionFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? accountId,
    String? searchQuery,
    double? minAmount,
    double? maxAmount,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearCategoryId = false,
    bool clearAccountId = false,
    bool clearSearchQuery = false,
    bool clearMinAmount = false,
    bool clearMaxAmount = false,
  }) {
    return TransactionFilter(
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      minAmount: clearMinAmount ? null : (minAmount ?? this.minAmount),
      maxAmount: clearMaxAmount ? null : (maxAmount ?? this.maxAmount),
    );
  }

  /// Returns true if no filters are applied.
  bool get isEmpty =>
      startDate == null &&
      endDate == null &&
      categoryId == null &&
      accountId == null &&
      (searchQuery == null || searchQuery!.isEmpty) &&
      minAmount == null &&
      maxAmount == null;

  /// Returns true if any filters are applied.
  bool get isNotEmpty => !isEmpty;

  /// Returns true if date range filter is active.
  bool get hasDateRange => startDate != null || endDate != null;

  /// Returns true if amount range filter is active.
  bool get hasAmountRange => minAmount != null || maxAmount != null;

  /// Returns a cleared filter (all fields null).
  static const TransactionFilter empty = TransactionFilter();

  /// Serializes the filter to JSON.
  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'categoryId': categoryId,
      'accountId': accountId,
      'searchQuery': searchQuery,
      'minAmount': minAmount,
      'maxAmount': maxAmount,
    };
  }

  /// Creates a filter from JSON.
  factory TransactionFilter.fromJson(Map<String, dynamic> json) {
    return TransactionFilter(
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      categoryId: json['categoryId'] as String?,
      accountId: json['accountId'] as String?,
      searchQuery: json['searchQuery'] as String?,
      minAmount: json['minAmount'] as double?,
      maxAmount: json['maxAmount'] as double?,
    );
  }
}
