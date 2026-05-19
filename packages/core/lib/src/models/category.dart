import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Category model for transaction categorization.
///
/// Supports hierarchical structure via [parentId] for organizing
/// categories into groups (e.g., "Food" -> "Groceries" -> "Vegetables").
class Category extends Equatable {
  final String id;
  final String name;
  final String? parentId;
  final String? icon;
  final String? color;
  final bool isIncome;
  final int sortOrder;
  final DateTime createdAt;

  Category({
    String? id,
    required this.name,
    this.parentId,
    this.icon,
    this.color,
    this.isIncome = false,
    this.sortOrder = 0,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Category copyWith({
    String? id,
    String? name,
    String? parentId,
    String? icon,
    String? color,
    bool? isIncome,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isIncome: isIncome ?? this.isIncome,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'icon': icon,
      'color': color,
      'is_income': isIncome ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      parentId: json['parent_id'] as String?,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      isIncome: json['is_income'] == 1,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
    );
  }

  @override
  List<Object?> get props => [id, name, parentId, icon, color, isIncome, sortOrder, createdAt];
}
