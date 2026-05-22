import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

// ============================================================
// REPORT MODELS
// ============================================================

/// Report type
enum ReportType {
  balanceSheet,
  incomeStatement,
  cashFlow,
  trialBalance,
  accountHistory,
  categorySpending,
  custom,
}

/// Report configuration
class ReportConfig {
  final String id;
  final String name;
  final ReportType type;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> accountIds;
  final List<String> categoryIds;
  final bool includeSubtotals;
  final bool includeComparisons;
  final String groupBy; // 'day', 'week', 'month', 'quarter', 'year'

  const ReportConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.startDate,
    required this.endDate,
    this.accountIds = const [],
    this.categoryIds = const [],
    this.includeSubtotals = true,
    this.includeComparisons = false,
    this.groupBy = 'month',
  });
}

/// Report data
class ReportData {
  final ReportConfig config;
  final Map<String, dynamic> data;
  final DateTime generatedAt;

  const ReportData({
    required this.config,
    required this.data,
    required this.generatedAt,
  });
}

// ============================================================
// REPORT SERVICE
// ============================================================

class ReportService {
  final LocalFinanceDatabase _db;

  ReportService(this._db);

  /// Generate balance sheet
  Future<ReportData> generateBalanceSheet(ReportConfig config) async {
    final accounts = await (db.select(db.accounts)).get();
    final balances = <String, double>{};

    for (final account in accounts) {
      final splits = await (db.select(db.splits)
        ..where((s) => s.accountId.equals(account.id)))
        .get();

      final balance = splits.fold<int>(0, (sum, s) => sum + s.valueNum) / 100.0;
      balances[account.id] = balance;
    }

    return ReportData(
      config: config,
      data: {
        'accounts': accounts.map((a) => {
          'id': a.id,
          'name': a.name,
          'type': a.accountType,
          'balance': balances[a.id] ?? 0,
        }).toList(),
        'generatedAt': DateTime.now().toIso8601String(),
      },
      generatedAt: DateTime.now(),
    );
  }

  /// Generate income statement
  Future<ReportData> generateIncomeStatement(ReportConfig config) async {
    final startMs = config.startDate.millisecondsSinceEpoch;
    final endMs = config.endDate.millisecondsSinceEpoch;

    final transactions = await (db.select(db.transactions)
      ..where((t) =>
          t.postDate.isBiggerOrEqualValue(startMs) &
          t.postDate.isSmallerOrEqualValue(endMs)))
      .get();

    double totalIncome = 0;
    double totalExpense = 0;

    for (final txn in transactions) {
      final splits = await (db.select(db.splits)
        ..where((s) => s.transactionId.equals(txn.id)))
        .get();

      for (final split in splits) {
        final account = await (db.select(db.accounts)
          ..where((a) => a.id.equals(split.accountId)))
          .getSingleOrNull();

        if (account == null) continue;

        final value = split.valueNum / 100.0;

        if (account.accountType == 'INCOME') {
          totalIncome += value.abs();
        } else if (account.accountType == 'EXPENSE') {
          totalExpense += value.abs();
        }
      }
    }

    return ReportData(
      config: config,
      data: {
        'totalIncome': totalIncome,
        'totalExpense': totalExpense,
        'netIncome': totalIncome - totalExpense,
        'period': {
          'start': config.startDate.toIso8601String(),
          'end': config.endDate.toIso8601String(),
        },
      },
      generatedAt: DateTime.now(),
    );
  }

  /// Generate trial balance
  Future<ReportData> generateTrialBalance(ReportConfig config) async {
    final accounts = await (db.select(db.accounts)).get();
    final trialBalance = <Map<String, dynamic>>[];
    double totalDebits = 0;
    double totalCredits = 0;

    for (final account in accounts) {
      final splits = await (db.select(db.splits)
        ..where((s) => s.accountId.equals(account.id)))
        .get();

      double debit = 0;
      double credit = 0;

      for (final split in splits) {
        final value = split.valueNum / 100.0;
        if (value > 0) {
          debit += value;
        } else {
          credit += value.abs();
        }
      }

      if (debit != 0 || credit != 0) {
        trialBalance.add({
          'accountId': account.id,
          'accountName': account.name,
          'accountType': account.accountType,
          'debit': debit,
          'credit': credit,
        });
        totalDebits += debit;
        totalCredits += credit;
      }
    }

    return ReportData(
      config: config,
      data: {
        'accounts': trialBalance,
        'totalDebits': totalDebits,
        'totalCredits': totalCredits,
        'isBalanced': (totalDebits - totalCredits).abs() < 0.01,
      },
      generatedAt: DateTime.now(),
    );
  }

  LocalFinanceDatabase get db => _db;
}

// ============================================================
// PROVIDERS
// ============================================================

final reportServiceProvider = Provider<ReportService>((ref) {
  final db = ref.watch(databaseProvider);
  return ReportService(db);
});

/// Provider for balance sheet report
final balanceSheetReportProvider =
    FutureProvider.family<ReportData, ReportConfig>((ref, config) async {
  final service = ref.watch(reportServiceProvider);
  return service.generateBalanceSheet(config);
});

/// Provider for income statement report
final incomeStatementReportProvider =
    FutureProvider.family<ReportData, ReportConfig>((ref, config) async {
  final service = ref.watch(reportServiceProvider);
  return service.generateIncomeStatement(config);
});

/// Provider for trial balance report
final trialBalanceReportProvider =
    FutureProvider.family<ReportData, ReportConfig>((ref, config) async {
  final service = ref.watch(reportServiceProvider);
  return service.generateTrialBalance(config);
});
