import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration for a single dashboard widget.
class DashboardWidgetConfig {
  final String id;
  final bool enabled;
  final int order;

  const DashboardWidgetConfig({
    required this.id,
    this.enabled = true,
    this.order = 0,
  });

  DashboardWidgetConfig copyWith({
    String? id,
    bool? enabled,
    int? order,
  }) {
    return DashboardWidgetConfig(
      id: id ?? this.id,
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'enabled': enabled,
      'order': order,
    };
  }

  factory DashboardWidgetConfig.fromJson(Map<String, dynamic> json) {
    return DashboardWidgetConfig(
      id: json['id'] as String,
      enabled: json['enabled'] as bool? ?? true,
      order: json['order'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DashboardWidgetConfig &&
        other.id == id &&
        other.enabled == enabled &&
        other.order == order;
  }

  @override
  int get hashCode => Object.hash(id, enabled, order);
}

/// Full dashboard configuration containing all widget configs.
class DashboardConfig {
  final List<DashboardWidgetConfig> widgets;
  final bool isEditMode;

  const DashboardConfig({
    this.widgets = const [],
    this.isEditMode = false,
  });

  DashboardConfig copyWith({
    List<DashboardWidgetConfig>? widgets,
    bool? isEditMode,
  }) {
    return DashboardConfig(
      widgets: widgets ?? this.widgets,
      isEditMode: isEditMode ?? this.isEditMode,
    );
  }

  /// Get enabled widgets sorted by order.
  List<DashboardWidgetConfig> get enabledWidgets {
    return widgets.where((w) => w.enabled).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Get all widgets sorted by order.
  List<DashboardWidgetConfig> get sortedWidgets {
    return List.from(widgets)..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Check if a widget is enabled.
  bool isWidgetEnabled(String widgetId) {
    return widgets.firstWhere(
          (w) => w.id == widgetId,
          orElse: () => DashboardWidgetConfig(id: widgetId, enabled: false),
        ).enabled;
  }

  /// Get widget config by ID.
  DashboardWidgetConfig? getWidgetConfig(String widgetId) {
    try {
      return widgets.firstWhere((w) => w.id == widgetId);
    } catch (_) {
      return null;
    }
  }
}

/// Notifier for managing dashboard configuration.
class DashboardConfigNotifier extends StateNotifier<DashboardConfig> {
  static const _key = 'dashboard_config';

  DashboardConfigNotifier() : super(const DashboardConfig()) {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final savedConfig = prefs.getString(_key);
    
    if (savedConfig != null) {
      try {
        final json = jsonDecode(savedConfig) as List<dynamic>;
        final widgets = json
            .map((e) => DashboardWidgetConfig.fromJson(e as Map<String, dynamic>))
            .toList();
        state = DashboardConfig(widgets: widgets);
      } catch (_) {
        // If loading fails, use default config
        state = DashboardConfig(widgets: _getDefaultWidgets());
      }
    } else {
      // First time - use default config
      state = DashboardConfig(widgets: _getDefaultWidgets());
    }
  }

  List<DashboardWidgetConfig> _getDefaultWidgets() {
    return const [
      DashboardWidgetConfig(id: 'net_worth', enabled: true, order: 0),
      DashboardWidgetConfig(id: 'quick_stats', enabled: true, order: 1),
      DashboardWidgetConfig(id: 'quick_actions', enabled: true, order: 2),
      DashboardWidgetConfig(id: 'recent_transactions', enabled: true, order: 3),
      DashboardWidgetConfig(id: 'budget_progress', enabled: false, order: 4),
      DashboardWidgetConfig(id: 'monthly_trend', enabled: false, order: 5),
      DashboardWidgetConfig(id: 'category_breakdown', enabled: false, order: 6),
    ];
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final json = state.widgets.map((w) => w.toJson()).toList();
    await prefs.setString(_key, jsonEncode(json));
  }

  /// Toggle edit mode.
  void toggleEditMode() {
    state = state.copyWith(isEditMode: !state.isEditMode);
  }

  /// Enable or disable a widget.
  Future<void> setWidgetEnabled(String widgetId, bool enabled) async {
    final newWidgets = state.widgets.map((w) {
      if (w.id == widgetId) {
        return w.copyWith(enabled: enabled);
      }
      return w;
    }).toList();

    // If widget doesn't exist, add it
    if (!state.widgets.any((w) => w.id == widgetId)) {
      newWidgets.add(DashboardWidgetConfig(
        id: widgetId,
        enabled: enabled,
        order: state.widgets.length,
      ));
    }

    state = state.copyWith(widgets: newWidgets);
    await _saveConfig();
  }

  /// Reorder widgets.
  Future<void> reorderWidgets(int oldIndex, int newIndex) async {
    final sortedWidgets = state.sortedWidgets;
    
    // Adjust newIndex for removal
    if (newIndex > oldIndex) {
      newIndex--;
    }

    // Reorder
    final widget = sortedWidgets.removeAt(oldIndex);
    sortedWidgets.insert(newIndex, widget);

    // Update order values
    final newWidgets = sortedWidgets.asMap().entries.map((entry) {
      return entry.value.copyWith(order: entry.key);
    }).toList();

    state = state.copyWith(widgets: newWidgets);
    await _saveConfig();
  }

  /// Reset to default configuration.
  Future<void> resetToDefault() async {
    state = DashboardConfig(widgets: _getDefaultWidgets());
    await _saveConfig();
  }

  /// Add a new widget.
  Future<void> addWidget(String widgetId) async {
    if (state.widgets.any((w) => w.id == widgetId)) {
      // Widget exists, just enable it
      await setWidgetEnabled(widgetId, true);
    } else {
      // Add new widget
      final newWidgets = [
        ...state.widgets,
        DashboardWidgetConfig(
          id: widgetId,
          enabled: true,
          order: state.widgets.length,
        ),
      ];
      state = state.copyWith(widgets: newWidgets);
      await _saveConfig();
    }
  }

  /// Remove a widget (disable it).
  Future<void> removeWidget(String widgetId) async {
    await setWidgetEnabled(widgetId, false);
  }
}

/// Provider for dashboard configuration state.
final dashboardConfigProvider =
    StateNotifierProvider<DashboardConfigNotifier, DashboardConfig>((ref) {
  return DashboardConfigNotifier();
});
