import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Saved search preset for quick filtering of transactions.
///
/// Stores filter criteria that can be quickly applied to search transactions.
class SavedSearch extends Equatable {
  final String id;
  final String name;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? categoryId;
  final String? accountId;
  final String? searchQuery;
  final double? minAmount;
  final double? maxAmount;
  final List<String> tagIds;
  final bool isFavorite;
  final int useCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavedSearch({
    required this.id,
    required this.name,
    this.description,
    this.startDate,
    this.endDate,
    this.categoryId,
    this.accountId,
    this.searchQuery,
    this.minAmount,
    this.maxAmount,
    this.tagIds = const [],
    this.isFavorite = false,
    this.useCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  SavedSearch.create({
    String? id,
    required this.name,
    this.description,
    this.startDate,
    this.endDate,
    this.categoryId,
    this.accountId,
    this.searchQuery,
    this.minAmount,
    this.maxAmount,
    this.tagIds = const [],
    this.isFavorite = false,
    this.useCount = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  SavedSearch copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? accountId,
    String? searchQuery,
    double? minAmount,
    double? maxAmount,
    List<String>? tagIds,
    bool? isFavorite,
    int? useCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedSearch(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      searchQuery: searchQuery ?? this.searchQuery,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      tagIds: tagIds ?? this.tagIds,
      isFavorite: isFavorite ?? this.isFavorite,
      useCount: useCount ?? this.useCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Creates a copy with incremented use count
  SavedSearch withIncrementedUseCount() {
    return copyWith(
      useCount: useCount + 1,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'start_date': startDate?.millisecondsSinceEpoch,
      'end_date': endDate?.millisecondsSinceEpoch,
      'category_id': categoryId,
      'account_id': accountId,
      'search_query': searchQuery,
      'min_amount': minAmount,
      'max_amount': maxAmount,
      'tag_ids': tagIds.join(','),
      'is_favorite': isFavorite ? 1 : 0,
      'use_count': useCount,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory SavedSearch.fromJson(Map<String, dynamic> json) {
    return SavedSearch(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      startDate: json['start_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['start_date'] as int)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['end_date'] as int)
          : null,
      categoryId: json['category_id'] as String?,
      accountId: json['account_id'] as String?,
      searchQuery: json['search_query'] as String?,
      minAmount: json['min_amount'] as double?,
      maxAmount: json['max_amount'] as double?,
      tagIds: json['tag_ids'] != null && (json['tag_ids'] as String).isNotEmpty
          ? (json['tag_ids'] as String).split(',')
          : [],
      isFavorite: json['is_favorite'] == 1,
      useCount: json['use_count'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        startDate,
        endDate,
        categoryId,
        accountId,
        searchQuery,
        minAmount,
        maxAmount,
        tagIds,
        isFavorite,
        useCount,
        createdAt,
        updatedAt,
      ];
}

/// Search history entry for tracking recent searches.
class SearchHistoryEntry extends Equatable {
  final String id;
  final String query;
  final DateTime searchedAt;

  const SearchHistoryEntry({
    required this.id,
    required this.query,
    required this.searchedAt,
  });

  SearchHistoryEntry.create({
    String? id,
    required this.query,
    DateTime? searchedAt,
  })  : id = id ?? const Uuid().v4(),
        searchedAt = searchedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'query': query,
      'searched_at': searchedAt.millisecondsSinceEpoch,
    };
  }

  factory SearchHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SearchHistoryEntry(
      id: json['id'] as String,
      query: json['query'] as String,
      searchedAt: DateTime.fromMillisecondsSinceEpoch(json['searched_at'] as int),
    );
  }

  @override
  List<Object?> get props => [id, query, searchedAt];
}
