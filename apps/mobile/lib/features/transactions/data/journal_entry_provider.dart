import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import 'package:core/core.dart';
import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';
import 'package:finance_app/features/currency/data/currency_provider.dart';

/// Represents a single split line in the journal entry editor.
class SplitLine {
  final String id;
  final String? accountId;
  final String? accountName;
  final String? accountType;
  final double debit;
  final double credit;
  final String? memo;

  const SplitLine({
    required this.id,
    this.accountId,
    this.accountName,
    this.accountType,
    this.debit = 0,
    this.credit = 0,
    this.memo,
  });

  /// Returns true if this split has an account selected.
  bool get hasAccount => accountId != null;

  /// Returns true if this split has a non-zero amount.
  bool get hasAmount => debit != 0 || credit != 0;

  /// Returns the net value (positive = credit, negative = debit).
  double get netValue => credit - debit;

  SplitLine copyWith({
    String? id,
    String? accountId,
    String? accountName,
    String? accountType,
    double? debit,
    double? credit,
    String? memo,
  }) {
    return SplitLine(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      accountType: accountType ?? this.accountType,
      debit: debit ?? this.debit,
      credit: credit ?? this.credit,
      memo: memo ?? this.memo,
    );
  }
}

/// State for the journal entry editor.
class JournalEntryState {
  final DateTime date;
  final String description;
  final String? referenceNumber;
  final String currencyId; // Transaction currency
  final List<SplitLine> splits;
  final bool isValid;
  final String? errorMessage;
  final double totalDebits;
  final double totalCredits;
  final bool isSaving;

  const JournalEntryState({
    this.date = DateTime.now,
    this.description = '',
    this.referenceNumber,
    this.currencyId = 'CNY', // Default to CNY
    this.splits = const [],
    this.isValid = false,
    this.errorMessage,
    this.totalDebits = 0,
    this.totalCredits = 0,
    this.isSaving = false,
  });

  /// Returns the balance difference (should be 0 for valid entry).
  double get balance => totalDebits - totalCredits;

  /// Returns true if the entry is balanced.
  bool get isBalanced => (balance.abs() < 0.01) && splits.length >= 2;

  JournalEntryState copyWith({
    DateTime? date,
    String? description,
    String? referenceNumber,
    String? currencyId,
    List<SplitLine>? splits,
    bool? isValid,
    String? errorMessage,
    double? totalDebits,
    double? totalCredits,
    bool? isSaving,
  }) {
    return JournalEntryState(
      date: date ?? this.date,
      description: description ?? this.description,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      currencyId: currencyId ?? this.currencyId,
      splits: splits ?? this.splits,
      isValid: isValid ?? this.isValid,
      errorMessage: errorMessage,
      totalDebits: totalDebits ?? this.totalDebits,
      totalCredits: totalCredits ?? this.totalCredits,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

/// Notifier for managing journal entry state.
class JournalEntryNotifier extends StateNotifier<JournalEntryState> {
  final Ref _ref;
  final JournalEntryValidator _validator;
  final Uuid _uuid;

  JournalEntryNotifier(this._ref)
      : _validator = JournalEntryValidator(),
        _uuid = const Uuid(),
        super(const JournalEntryState()) {
    // Initialize with two empty splits
    _initializeSplits();
  }

  void _initializeSplits() {
    state = state.copyWith(
      splits: [
        SplitLine(id: _uuid.v4()),
        SplitLine(id: _uuid.v4()),
      ],
    );
  }

  /// Updates the transaction date.
  void setDate(DateTime date) {
    state = state.copyWith(date: date);
  }

  /// Updates the description.
  void setDescription(String description) {
    state = state.copyWith(description: description);
  }

  /// Updates the reference number.
  void setReferenceNumber(String? referenceNumber) {
    state = state.copyWith(referenceNumber: referenceNumber);
  }

  /// Updates the transaction currency.
  void setCurrency(String currencyId) {
    state = state.copyWith(currencyId: currencyId);
  }

  /// Adds a new split line.
  void addSplit() {
    final newSplits = [
      ...state.splits,
      SplitLine(id: _uuid.v4()),
    ];
    _updateSplits(newSplits);
  }

  /// Removes a split line by ID.
  void removeSplit(String splitId) {
    if (state.splits.length <= 2) {
      // Minimum 2 splits required
      return;
    }
    final newSplits = state.splits.where((s) => s.id != splitId).toList();
    _updateSplits(newSplits);
  }

  /// Updates a specific split's account.
  void updateSplitAccount(String splitId, Account account) {
    final newSplits = state.splits.map((s) {
      if (s.id == splitId) {
        return s.copyWith(
          accountId: account.id,
          accountName: account.name,
          accountType: account.accountType.code,
        );
      }
      return s;
    }).toList();
    _updateSplits(newSplits);
  }

  /// Updates a specific split's debit amount.
  void updateSplitDebit(String splitId, double debit) {
    final newSplits = state.splits.map((s) {
      if (s.id == splitId) {
        return s.copyWith(
          debit: debit,
          credit: 0, // Clear credit when setting debit
        );
      }
      return s;
    }).toList();
    _updateSplits(newSplits);
  }

  /// Updates a specific split's credit amount.
  void updateSplitCredit(String splitId, double credit) {
    final newSplits = state.splits.map((s) {
      if (s.id == splitId) {
        return s.copyWith(
          credit: credit,
          debit: 0, // Clear debit when setting credit
        );
      }
      return s;
    }).toList();
    _updateSplits(newSplits);
  }

  /// Updates a specific split's memo.
  void updateSplitMemo(String splitId, String? memo) {
    final newSplits = state.splits.map((s) {
      if (s.id == splitId) {
        return s.copyWith(memo: memo);
      }
      return s;
    }).toList();
    _updateSplits(newSplits);
  }

  /// Clears a split's account selection.
  void clearSplitAccount(String splitId) {
    final newSplits = state.splits.map((s) {
      if (s.id == splitId) {
        return const SplitLine(id: '');
      }
      return s;
    }).toList();
    _updateSplits(newSplits);
  }

  void _updateSplits(List<SplitLine> splits) {
    // Calculate totals
    final totalDebits = splits.fold<double>(0, (sum, s) => sum + s.debit);
    final totalCredits = splits.fold<double>(0, (sum, s) => sum + s.credit);

    // Validate
    final validationResult = _validateSplits(splits);

    state = state.copyWith(
      splits: splits,
      totalDebits: totalDebits,
      totalCredits: totalCredits,
      isValid: validationResult.isValid,
      errorMessage: validationResult.errorMessage,
    );
  }

  ValidationResult _validateSplits(List<SplitLine> splits) {
    // Check minimum splits
    if (splits.length < 2) {
      return const ValidationResult.failure(
        'Journal entry must have at least 2 splits.',
      );
    }

    // Check all splits have accounts
    final emptySplits = splits.where((s) => !s.hasAccount).toList();
    if (emptySplits.isNotEmpty) {
      return const ValidationResult.failure(
        'All splits must have an account selected.',
      );
    }

    // Check for duplicate accounts
    final accountIds = <String>{};
    for (final split in splits) {
      if (split.accountId != null) {
        if (accountIds.contains(split.accountId)) {
          return const ValidationResult.failure(
            'Duplicate account in journal entry.',
          );
        }
        accountIds.add(split.accountId!);
      }
    }

    // Check all splits have amounts
    final zeroSplits = splits.where((s) => !s.hasAmount).toList();
    if (zeroSplits.isNotEmpty) {
      return const ValidationResult.failure(
        'All splits must have a non-zero amount.',
      );
    }

    // Check balance
    final totalDebits = splits.fold<double>(0, (sum, s) => sum + s.debit);
    final totalCredits = splits.fold<double>(0, (sum, s) => sum + s.credit);
    final balance = totalDebits - totalCredits;

    if (balance.abs() > 0.01) {
      return ValidationResult.failure(
        'Entry is not balanced. Difference: ¥${balance.abs().toStringAsFixed(2)}',
      );
    }

    return const ValidationResult.success();
  }

  /// Saves the journal entry to the database.
  Future<bool> save() async {
    if (!state.isValid) return false;

    state = state.copyWith(isSaving: true);

    try {
      final db = _ref.read(databaseProvider);
      final transactionId = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final postDate = state.date.millisecondsSinceEpoch;

      // Create splits for the transaction
      final splitsData = <SplitsCompanion>[];
      for (final line in state.splits) {
        if (line.accountId == null) continue;

        // Value is negative for debit, positive for credit
        final value = line.debit > 0 ? -line.debit : line.credit;
        final valueNum = (value * 100).round();

        splitsData.add(SplitsCompanion.insert(
          id: _uuid.v4(),
          transactionId: transactionId,
          accountId: line.accountId!,
          memo: drift.Value(line.memo),
          valueNum: valueNum,
          valueDenom: const drift.Value(100),
          quantityNum: valueNum,
          quantityDenom: const drift.Value(100),
          createdAt: now,
        ));
      }

      // Create the transaction
      await db.transaction(() async {
        await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: transactionId,
            postDate: postDate,
            enterDate: now,
            currencyId: state.currencyId, // Use selected currency
            description: drift.Value(state.description.isEmpty ? null : state.description),
            notes: drift.Value(state.referenceNumber),
            isDoubleEntry: const drift.Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );

        for (final splitData in splitsData) {
          await db.into(db.splits).insert(splitData);
        }
      });

      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to save: $e',
      );
      return false;
    }
  }

  /// Resets the form to initial state.
  void reset() {
    _initializeSplits();
    state = const JournalEntryState();
  }
}

/// Provider for the journal entry state.
final journalEntryProvider =
    StateNotifierProvider<JournalEntryNotifier, JournalEntryState>(
  (ref) => JournalEntryNotifier(ref),
);
