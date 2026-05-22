import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import 'package:database/database.dart';
import '../../accounts/data/account_provider.dart';

/// Provider for all cost centers
final costCentersProvider = StreamProvider<List<CostCenter>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.costCentersDao.watchAll();
});

/// Provider for active cost centers only
final activeCostCentersProvider = Provider<List<CostCenter>>((ref) {
  final costCenters = ref.watch(costCentersProvider);
  return costCenters.when(
    data: (list) => list.where((c) => c.isActive).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider for cost centers by type
final costCentersByTypeProvider = Provider.family<List<CostCenter>, String>((ref, type) {
  final costCenters = ref.watch(costCentersProvider);
  return costCenters.when(
    data: (list) => list.where((c) => c.costCenterType == type).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider for root cost centers (no parent)
final rootCostCentersProvider = Provider<List<CostCenter>>((ref) {
  final costCenters = ref.watch(costCentersProvider);
  return costCenters.when(
    data: (list) => list.where((c) => c.parentId == null).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Cost center type enum
enum CostCenterType {
  department('部门', 'DEPARTMENT'),
  project('项目', 'PROJECT'),
  activity('活动', 'ACTIVITY'),
  location('地点', 'LOCATION');

  final String label;
  final String code;

  const CostCenterType(this.label, this.code);

  static CostCenterType fromCode(String code) {
    return values.firstWhere(
      (t) => t.code == code,
      orElse: () => CostCenterType.department,
    );
  }
}

/// Notifier for managing cost centers
class CostCenterNotifier extends StateNotifier<AsyncValue<void>> {
  final LocalFinanceDatabase _db;

  CostCenterNotifier(this._db) : super(const AsyncValue.data(null));

  Future<void> create({
    required String id,
    required String name,
    String? code,
    String? parentId,
    CostCenterType type = CostCenterType.department,
    String? description,
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    state = const AsyncValue.loading();
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.costCentersDao.create(
        CostCentersCompanion.insert(
          id: id,
          name: name,
          code: drift.Value(code),
          parentId: drift.Value(parentId),
          costCenterType: drift.Value(type.code),
          description: drift.Value(description),
          isActive: drift.Value(isActive),
          sortOrder: drift.Value(sortOrder),
          createdAt: now,
          updatedAt: now,
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> update(CostCenter center) async {
    state = const AsyncValue.loading();
    try {
      await _db.costCentersDao.update(
        center.id,
        CostCentersCompanion(
          name: drift.Value(center.name),
          code: drift.Value(center.code),
          parentId: drift.Value(center.parentId),
          costCenterType: drift.Value(center.costCenterType),
          description: drift.Value(center.description),
          isActive: drift.Value(center.isActive),
          sortOrder: drift.Value(center.sortOrder),
          updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> delete(String id) async {
    state = const AsyncValue.loading();
    try {
      await _db.costCentersDao.softDelete(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setActive(String id, bool active) async {
    try {
      await _db.costCentersDao.setActive(id, active);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final costCenterNotifierProvider =
    StateNotifierProvider<CostCenterNotifier, AsyncValue<void>>((ref) {
  final db = ref.watch(databaseProvider);
  return CostCenterNotifier(db);
});
