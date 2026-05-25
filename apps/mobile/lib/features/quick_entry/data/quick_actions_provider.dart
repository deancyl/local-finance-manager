import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

// ============================================================
// QUICK ACTION TYPES
// ============================================================

/// Quick action types for the FAB menu
enum QuickActionType {
  expense,
  income,
  transfer,
  template,
  recentPayee,
}

/// Quick action item
class QuickActionItem {
  final QuickActionType type;
  final String label;
  final IconDataData? icon;
  final String? categoryId;
  final String? accountId;
  final String? templateId;
  final double? defaultAmount;
  final String? description;

  QuickActionItem({
    required this.type,
    required this.label,
    this.icon,
    this.categoryId,
    this.accountId,
    this.templateId,
    this.defaultAmount,
    this.description,
  });

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'label': label,
    'icon': icon?.toJson(),
    'categoryId': categoryId,
    'accountId': accountId,
    'templateId': templateId,
    'defaultAmount': defaultAmount,
    'description': description,
  };

  factory QuickActionItem.fromJson(Map<String, dynamic> json) {
    return QuickActionItem(
      type: QuickActionType.values[json['type'] as int],
      label: json['label'] as String,
      icon: json['icon'] != null ? IconDataData.fromJson(json['icon']) : null,
      categoryId: json['categoryId'] as String?,
      accountId: json['accountId'] as String?,
      templateId: json['templateId'] as String?,
      defaultAmount: json['defaultAmount'] as double?,
      description: json['description'] as String?,
    );
  }
}

/// Icon data for serialization
class IconDataData {
  final int codePoint;
  final String fontFamily;

  IconDataData({required this.codePoint, required this.fontFamily});

  Map<String, dynamic> toJson() => {
    'codePoint': codePoint,
    'fontFamily': fontFamily,
  };

  factory IconDataData.fromJson(Map<String, dynamic> json) {
    return IconDataData(
      codePoint: json['codePoint'] as int,
      fontFamily: json['fontFamily'] as String,
    );
  }
}

// ============================================================
// FREQUENT CATEGORY MODEL
// ============================================================

/// Model for frequently used categories
class FrequentCategory {
  final Category category;
  final int useCount;
  final DateTime lastUsed;

  FrequentCategory({
    required this.category,
    required this.useCount,
    required this.lastUsed,
  });
}

// ============================================================
// RECENT PAYEE MODEL
// ============================================================

/// Model for recent payees (description patterns)
class RecentPayee {
  final String description;
  final String? categoryId;
  final int useCount;
  final DateTime lastUsed;

  RecentPayee({
    required this.description,
    this.categoryId,
    required this.useCount,
    required this.lastUsed,
  });
}

// ============================================================
// ONE-TAP ENTRY TEMPLATE
// ============================================================

/// One-tap entry template for quick transactions
class OneTapEntryTemplate {
  final String id;
  final String name;
  final String? categoryId;
  final String? accountId;
  final double? defaultAmount;
  final String? description;
  final String? notes;
  final bool isIncome;
  final int sortOrder;

  OneTapEntryTemplate({
    required this.id,
    required this.name,
    this.categoryId,
    this.accountId,
    this.defaultAmount,
    this.description,
    this.notes,
    this.isIncome = false,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'categoryId': categoryId,
    'accountId': accountId,
    'defaultAmount': defaultAmount,
    'description': description,
    'notes': notes,
    'isIncome': isIncome,
    'sortOrder': sortOrder,
  };

  factory OneTapEntryTemplate.fromJson(Map<String, dynamic> json) {
    return OneTapEntryTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      categoryId: json['categoryId'] as String?,
      accountId: json['accountId'] as String?,
      defaultAmount: json['defaultAmount'] as double?,
      description: json['description'] as String?,
      notes: json['notes'] as String?,
      isIncome: json['isIncome'] as bool? ?? false,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}

// ============================================================
// QUICK ACTIONS PROVIDER
// ============================================================

/// Provider for frequent categories
final frequentCategoriesProvider = FutureProvider<List<FrequentCategory>>((ref) async {
  final db = ref.watch(databaseProvider);
  
  // Get splits from last 30 days
  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
  
  final splits = await (db.select(db.splits)
      ..where((s) => s.categoryId.isNotNull() & s.createdAt.isBiggerOrEqualValue(thirtyDaysAgo))
      ..orderBy([(s) => drift.OrderingTerm.desc(s.createdAt)]))
      .get();
  
  // Group by category and count
  final categoryCounts = <String, int>{};
  final categoryLastUsed = <String, DateTime>{};
  
  for (final split in splits) {
    if (split.categoryId != null) {
      categoryCounts[split.categoryId!] = (categoryCounts[split.categoryId!] ?? 0) + 1;
      final splitDate = DateTime.fromMillisecondsSinceEpoch(split.createdAt);
      if (!categoryLastUsed.containsKey(split.categoryId!) || 
          splitDate.isAfter(categoryLastUsed[split.categoryId!]!)) {
        categoryLastUsed[split.categoryId!] = splitDate;
      }
    }
  }
  
  // Get category details
  final categories = await (db.select(db.categories)).get();
  final categoryMap = {for (var c in categories) c.id: c};
  
  // Build frequent category list
  final result = <FrequentCategory>[];
  for (final entry in categoryCounts.entries) {
    final category = categoryMap[entry.key];
    if (category != null) {
      result.add(FrequentCategory(
        category: category,
        useCount: entry.value,
        lastUsed: categoryLastUsed[entry.key] ?? DateTime.now(),
      ));
    }
  }
  
  // Sort by use count (descending)
  result.sort((a, b) => b.useCount.compareTo(a.useCount));
  
  return result;
});

/// Provider for recent payees (frequently used descriptions)
final recentPayeesProvider = FutureProvider<List<RecentPayee>>((ref) async {
  final db = ref.watch(databaseProvider);
  
  // Get transactions from last 30 days
  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
  
  final transactions = await (db.select(db.transactions)
      ..where((t) => t.description.isNotNull() & t.postDate.isBiggerOrEqualValue(thirtyDaysAgo))
      ..orderBy([(t) => drift.OrderingTerm.desc(t.postDate)]))
      .get();
  
  // Get splits for category association
  final splits = await (db.select(db.splits)
      ..where((s) => s.categoryId.isNotNull()))
      .get();
  
  final transactionCategoryMap = <String, String>{};
  for (final split in splits) {
    if (split.categoryId != null) {
      transactionCategoryMap[split.transactionId] = split.categoryId!;
    }
  }
  
  // Group by description and count
  final descriptionCounts = <String, int>{};
  final descriptionCategoryMap = <String, String>{};
  final descriptionLastUsed = <String, DateTime>{};
  
  for (final txn in transactions) {
    if (txn.description != null && txn.description!.isNotEmpty) {
      final desc = txn.description!;
      descriptionCounts[desc] = (descriptionCounts[desc] ?? 0) + 1;
      
      // Associate most common category
      if (!descriptionCategoryMap.containsKey(desc) && transactionCategoryMap.containsKey(txn.id)) {
        descriptionCategoryMap[desc] = transactionCategoryMap[txn.id]!;
      }
      
      final txnDate = DateTime.fromMillisecondsSinceEpoch(txn.postDate);
      if (!descriptionLastUsed.containsKey(desc) || txnDate.isAfter(descriptionLastUsed[desc]!)) {
        descriptionLastUsed[desc] = txnDate;
      }
    }
  }
  
  // Build recent payee list
  final result = <RecentPayee>[];
  for (final entry in descriptionCounts.entries) {
    result.add(RecentPayee(
      description: entry.key,
      categoryId: descriptionCategoryMap[entry.key],
      useCount: entry.value,
      lastUsed: descriptionLastUsed[entry.key] ?? DateTime.now(),
    ));
  }
  
  // Sort by use count (descending) and limit to top 10
  result.sort((a, b) => b.useCount.compareTo(a.useCount));
  return result.take(10).toList();
});

/// Provider for one-tap entry templates
final oneTapTemplatesProvider = StateNotifierProvider<OneTapTemplatesNotifier, List<OneTapEntryTemplate>>((ref) {
  return OneTapTemplatesNotifier();
});

/// Notifier for managing one-tap templates
class OneTapTemplatesNotifier extends StateNotifier<List<OneTapEntryTemplate>> {
  static const _key = 'one_tap_templates';

  OneTapTemplatesNotifier() : super([]) {
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final templatesJson = prefs.getStringList(_key) ?? [];
    
    state = templatesJson
        .map((json) => OneTapEntryTemplate.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<void> addTemplate(OneTapEntryTemplate template) async {
    final newTemplate = template.copyWith(
      id: template.id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : template.id,
      sortOrder: state.length,
    );
    
    state = [...state, newTemplate];
    await _saveTemplates();
  }

  Future<void> updateTemplate(OneTapEntryTemplate template) async {
    state = state.map((t) => t.id == template.id ? template : t).toList();
    await _saveTemplates();
  }

  Future<void> deleteTemplate(String id) async {
    state = state.where((t) => t.id != id).toList();
    await _saveTemplates();
  }

  Future<void> reorderTemplates(int oldIndex, int newIndex) async {
    final items = List<OneTapEntryTemplate>.from(state);
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    
    // Update sort orders
    state = items.asMap().entries.map((e) => e.value.copyWith(sortOrder: e.key)).toList();
    await _saveTemplates();
  }

  Future<void> _saveTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final templatesJson = state.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList(_key, templatesJson);
  }
}

/// Extension for copyWith on OneTapEntryTemplate
extension on OneTapEntryTemplate {
  OneTapEntryTemplate copyWith({
    String? id,
    String? name,
    String? categoryId,
    String? accountId,
    double? defaultAmount,
    String? description,
    String? notes,
    bool? isIncome,
    int? sortOrder,
  }) {
    return OneTapEntryTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      defaultAmount: defaultAmount ?? this.defaultAmount,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      isIncome: isIncome ?? this.isIncome,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

/// Provider for quick action shortcuts (user-customizable)
final quickActionShortcutsProvider = StateNotifierProvider<QuickActionShortcutsNotifier, List<QuickActionItem>>((ref) {
  return QuickActionShortcutsNotifier();
});

/// Notifier for managing quick action shortcuts
class QuickActionShortcutsNotifier extends StateNotifier<List<QuickActionItem>> {
  static const _key = 'quick_action_shortcuts';

  QuickActionShortcutsNotifier() : super(_getDefaultActions()) {
    _loadShortcuts();
  }

  List<QuickActionItem> _getDefaultActions() {
    return [
      QuickActionItem(
        type: QuickActionType.expense,
        label: '记支出',
      ),
      QuickActionItem(
        type: QuickActionType.income,
        label: '记收入',
      ),
      QuickActionItem(
        type: QuickActionType.transfer,
        label: '转账',
      ),
      QuickActionItem(
        type: QuickActionType.template,
        label: '模板',
      ),
    ];
  }

  Future<void> _loadShortcuts() async {
    final prefs = await SharedPreferences.getInstance();
    final shortcutsJson = prefs.getStringList(_key);
    
    if (shortcutsJson != null && shortcutsJson.isNotEmpty) {
      state = shortcutsJson
          .map((json) => QuickActionItem.fromJson(jsonDecode(json) as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> updateShortcuts(List<QuickActionItem> shortcuts) async {
    state = shortcuts;
    final prefs = await SharedPreferences.getInstance();
    final shortcutsJson = shortcuts.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_key, shortcutsJson);
  }

  Future<void> resetToDefaults() async {
    state = _getDefaultActions();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
