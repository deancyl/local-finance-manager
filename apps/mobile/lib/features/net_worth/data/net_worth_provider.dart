import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

// ============================================================
// NET WORTH MODELS
// ============================================================

/// Net worth snapshot at a point in time
class NetWorthSnapshot {
  final DateTime date;
  final double assets;
  final double liabilities;
  final double netWorth;

  const NetWorthSnapshot({
    required this.date,
    required this.assets,
    required this.liabilities,
    required this.netWorth,
  });
}

/// Net worth trend over time
class NetWorthTrend {
  final List<NetWorthSnapshot> snapshots;
  final double change;
  final double changePercent;

  const NetWorthTrend({
    required this.snapshots,
    required this.change,
    required this.changePercent,
  });

  NetWorthSnapshot? get latest => snapshots.isNotEmpty ? snapshots.last : null;
  NetWorthSnapshot? get first => snapshots.isNotEmpty ? snapshots.first : null;
}

// ============================================================
// NET WORTH PROVIDERS
// ============================================================

/// Provider for current net worth
final currentNetWorthProvider = FutureProvider<NetWorthSnapshot>((ref) async {
  final db = ref.watch(databaseProvider);
  final accounts = await (db.select(db.accounts)).get();

  double assets = 0;
  double liabilities = 0;

  for (final account in accounts) {
    final splits = await (db.select(db.splits)
      ..where((s) => s.accountId.equals(account.id)))
      .get();

    final balance = splits.fold<int>(0, (sum, s) => sum + s.valueNum) / 100.0;

    if (account.accountType == 'ASSET') {
      assets += balance;
    } else if (account.accountType == 'LIABILITY') {
      liabilities += balance.abs();
    }
  }

  return NetWorthSnapshot(
    date: DateTime.now(),
    assets: assets,
    liabilities: liabilities,
    netWorth: assets - liabilities,
  );
});

/// Provider for net worth history (by month end)
final netWorthHistoryProvider = FutureProvider<List<NetWorthSnapshot>>((ref) async {
  final db = ref.watch(databaseProvider);
  final snapshots = <NetWorthSnapshot>[];

  final now = DateTime.now();

  for (var i = 0; i < 12; i++) {
    final monthEnd = DateTime(now.year, now.month - i + 1, 0);
    final monthEndMs = monthEnd.millisecondsSinceEpoch;

    final accounts = await (db.select(db.accounts)).get();

    double assets = 0;
    double liabilities = 0;

    for (final account in accounts) {
      // Get splits up to month end
      final splits = await (db.select(db.splits)
        ..where((s) => s.accountId.equals(account.id)))
        .get();

      // Filter splits by transaction date
      double balance = 0;
      for (final split in splits) {
        final txn = await (db.select(db.transactions)
          ..where((t) => t.id.equals(split.transactionId)))
          .getSingleOrNull();

        if (txn != null && txn.postDate <= monthEndMs) {
          balance += split.valueNum / 100.0;
        }
      }

      if (account.accountType == 'ASSET') {
        assets += balance;
      } else if (account.accountType == 'LIABILITY') {
        liabilities += balance.abs();
      }
    }

    snapshots.add(NetWorthSnapshot(
      date: monthEnd,
      assets: assets,
      liabilities: liabilities,
      netWorth: assets - liabilities,
    ));
  }

  return snapshots.reversed.toList();
});

/// Provider for net worth trend
final netWorthTrendProvider = FutureProvider<NetWorthTrend>((ref) async {
  final history = await ref.watch(netWorthHistoryProvider.future);

  if (history.length < 2) {
    return NetWorthTrend(
      snapshots: history,
      change: 0,
      changePercent: 0,
    );
  }

  final first = history.first;
  final latest = history.last;

  final change = latest.netWorth - first.netWorth;
  final changePercent = first.netWorth != 0
      ? (change / first.netWorth.abs()) * 100
      : 0;

  return NetWorthTrend(
    snapshots: history,
    change: change,
    changePercent: changePercent,
  );
});
