import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart' as uuid_pkg;

import 'package:core/core.dart';
import 'package:database/database.dart' hide Account;
import 'package:finance_app/features/accounts/data/account_provider.dart';

/// Represents a single journal entry line in the editor.
class JournalLine {
  final String id;
  final String? accountId;
  final String? accountName;
  final String? accountType;
  final double debit;
  final double credit;
  final String? memo;

  const JournalLine({
    required this.id,
    this.accountId,
    this.accountName,
    this.accountType,
    this.debit = 0,
    this.credit = 0,
    this.memo,
  });

  bool get hasAccount => accountId != null;
  bool get hasAmount => debit != 0 || credit != 0;

  JournalLine copyWith({
    String? id,
    String? accountId,
    String? accountName,
    String? accountType,
    double? debit,
    double? credit,
    String? memo,
  }) {
    return JournalLine(
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
class JournalEntryEditorState {
  final String? entryId;
  final String? entryNumber;
  final String description;
  final DateTime postDate;
  final DateTime? enterDate;
  final String? reference;
  final String? notes;
  final List<JournalLine> lines;
  final bool isPosted;
  final bool isValid;
  final String? errorMessage;
  final double totalDebits;
  final double totalCredits;
  final bool isSaving;
  final bool isLoading;

  const JournalEntryEditorState({
    this.entryId,
    this.entryNumber,
    this.description = '',
    required this.postDate,
    this.enterDate,
    this.reference,
    this.notes,
    this.lines = const [],
    this.isPosted = false,
    this.isValid = false,
    this.errorMessage,
    this.totalDebits = 0,
    this.totalCredits = 0,
    this.isSaving = false,
    this.isLoading = false,
  });

  double get balance => totalDebits - totalCredits;
  bool get isBalanced => (balance.abs() < 0.01) && lines.length >= 2;
  bool get isEditing => entryId != null;

  JournalEntryEditorState copyWith({
    String? entryId,
    String? entryNumber,
    String? description,
    DateTime? postDate,
    DateTime? enterDate,
    String? reference,
    String? notes,
    List<JournalLine>? lines,
    bool? isPosted,
    bool? isValid,
    String? errorMessage,
    double? totalDebits,
    double? totalCredits,
    bool? isSaving,
    bool? isLoading,
  }) {
    return JournalEntryEditorState(
      entryId: entryId ?? this.entryId,
      entryNumber: entryNumber ?? this.entryNumber,
      description: description ?? this.description,
      postDate: postDate ?? this.postDate,
      enterDate: enterDate ?? this.enterDate,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      lines: lines ?? this.lines,
      isPosted: isPosted ?? this.isPosted,
      isValid: isValid ?? this.isValid,
      errorMessage: errorMessage,
      totalDebits: totalDebits ?? this.totalDebits,
      totalCredits: totalCredits ?? this.totalCredits,
      isSaving: isSaving ?? this.isSaving,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Notifier for managing journal entry editor state.
class JournalEntryEditorNotifier extends StateNotifier<JournalEntryEditorState> {
  final Ref _ref;
  final uuid_pkg.Uuid _uuid;

  JournalEntryEditorNotifier(this._ref)
      : _uuid = const uuid_pkg.Uuid(),
        super(JournalEntryEditorState(postDate: DateTime.now())) {
    _initializeLines();
  }

  void _initializeLines() {
    state = state.copyWith(
      lines: [
        JournalLine(id: _uuid.v4()),
        JournalLine(id: _uuid.v4()),
      ],
    );
  }

  /// Load an existing journal entry for editing.
  Future<void> loadEntry(String entryId) async {
    state = state.copyWith(isLoading: true);

    try {
      final db = _ref.read(databaseProvider);
      final entryWithLines = await db.journalEntriesDao.getJournalEntryWithLines(entryId);

      if (entryWithLines == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Journal entry not found',
        );
        return;
      }

      final lines = entryWithLines.lines.map((line) {
        final debit = line.debitDenom != 0 ? line.debitNum / line.debitDenom : line.debitNum.toDouble();
        final credit = line.creditDenom != 0 ? line.creditNum / line.creditDenom : line.creditNum.toDouble();
        
        return JournalLine(
          id: line.id,
          accountId: line.accountId,
          debit: debit,
          credit: credit,
          memo: line.memo,
        );
      }).toList();

      state = state.copyWith(
        entryId: entryWithLines.entry.id,
        entryNumber: entryWithLines.entry.entryNumber,
        description: entryWithLines.entry.description ?? '',
        postDate: DateTime.fromMillisecondsSinceEpoch(entryWithLines.entry.postDate),
        enterDate: DateTime.fromMillisecondsSinceEpoch(entryWithLines.entry.enterDate),
        reference: entryWithLines.entry.reference,
        notes: entryWithLines.entry.notes,
        lines: lines,
        isPosted: entryWithLines.entry.isPosted,
        isLoading: false,
      );

      _recalculateTotals();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load entry: $e',
      );
    }
  }

  /// Set the entry number.
  void setEntryNumber(String? entryNumber) {
    state = state.copyWith(entryNumber: entryNumber);
  }

  /// Set the description.
  void setDescription(String description) {
    state = state.copyWith(description: description);
  }

  /// Set the post date.
  void setPostDate(DateTime postDate) {
    state = state.copyWith(postDate: postDate);
  }

  /// Set the reference.
  void setReference(String? reference) {
    state = state.copyWith(reference: reference);
  }

  /// Set the notes.
  void setNotes(String? notes) {
    state = state.copyWith(notes: notes);
  }

  /// Add a new line.
  void addLine() {
    final newLines = [...state.lines, JournalLine(id: _uuid.v4())];
    _updateLines(newLines);
  }

  /// Remove a line by ID.
  void removeLine(String lineId) {
    if (state.lines.length <= 2) return;
    final newLines = state.lines.where((l) => l.id != lineId).toList();
    _updateLines(newLines);
  }

  /// Update a line's account.
  void updateLineAccount(String lineId, Account account) {
    final newLines = state.lines.map((l) {
      if (l.id == lineId) {
        return l.copyWith(
          accountId: account.id,
          accountName: account.name,
          accountType: account.accountType.code,
        );
      }
      return l;
    }).toList();
    _updateLines(newLines);
  }

  /// Update a line's debit amount.
  void updateLineDebit(String lineId, double debit) {
    final newLines = state.lines.map((l) {
      if (l.id == lineId) {
        return l.copyWith(debit: debit, credit: 0);
      }
      return l;
    }).toList();
    _updateLines(newLines);
  }

  /// Update a line's credit amount.
  void updateLineCredit(String lineId, double credit) {
    final newLines = state.lines.map((l) {
      if (l.id == lineId) {
        return l.copyWith(credit: credit, debit: 0);
      }
      return l;
    }).toList();
    _updateLines(newLines);
  }

  /// Update a line's memo.
  void updateLineMemo(String lineId, String? memo) {
    final newLines = state.lines.map((l) {
      if (l.id == lineId) {
        return l.copyWith(memo: memo);
      }
      return l;
    }).toList();
    _updateLines(newLines);
  }

  void _updateLines(List<JournalLine> lines) {
    state = state.copyWith(lines: lines);
    _recalculateTotals();
  }

  void _recalculateTotals() {
    final totalDebits = state.lines.fold<double>(0, (sum, l) => sum + l.debit);
    final totalCredits = state.lines.fold<double>(0, (sum, l) => sum + l.credit);
    final validationResult = _validate();

    state = state.copyWith(
      totalDebits: totalDebits,
      totalCredits: totalCredits,
      isValid: validationResult.isValid,
      errorMessage: validationResult.errorMessage,
    );
  }

  ValidationResult _validate() {
    if (state.lines.length < 2) {
      return const ValidationResult.invalid('At least 2 lines required');
    }

    final emptyLines = state.lines.where((l) => !l.hasAccount).toList();
    if (emptyLines.isNotEmpty) {
      return const ValidationResult.invalid('All lines must have an account');
    }

    final zeroLines = state.lines.where((l) => !l.hasAmount).toList();
    if (zeroLines.isNotEmpty) {
      return const ValidationResult.invalid('All lines must have a non-zero amount');
    }

    final balance = state.totalDebits - state.totalCredits;
    if (balance.abs() > 0.01) {
      return ValidationResult.invalid(
        'Entry not balanced. Difference: ¥${balance.abs().toStringAsFixed(2)}',
      );
    }

    return const ValidationResult.valid();
  }

  /// Save the journal entry.
  Future<bool> save() async {
    if (!state.isValid) return false;

    state = state.copyWith(isSaving: true);

    try {
      final db = _ref.read(databaseProvider);

      // Convert lines to DAO input format
      final linesInput = state.lines.map((line) {
        return JournalEntryLineInput(
          accountId: line.accountId!,
          debitNum: (line.debit * 100).round(),
          debitDenom: 100,
          creditNum: (line.credit * 100).round(),
          creditDenom: 100,
          memo: line.memo,
        );
      }).toList();

      if (state.isEditing) {
        // Update existing entry
        await db.journalEntriesDao.updateEntry(
          state.entryId!,
          description: state.description,
          reference: state.reference,
          postDate: state.postDate,
          notes: state.notes,
        );
        await db.journalEntriesDao.updateLines(state.entryId!, linesInput);
      } else {
        // Create new entry
        final newId = await db.journalEntriesDao.createJournalEntry(
          description: state.description,
          postDate: state.postDate,
          reference: state.reference,
          lines: linesInput,
          entryNumber: state.entryNumber,
        );
        state = state.copyWith(entryId: newId);
      }

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

  /// Post the journal entry.
  Future<bool> post() async {
    if (state.entryId == null || state.isPosted) return false;

    state = state.copyWith(isSaving: true);

    try {
      final db = _ref.read(databaseProvider);
      await db.journalEntriesDao.postEntry(state.entryId!);
      state = state.copyWith(isPosted: true, isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to post: $e',
      );
      return false;
    }
  }

  /// Reset the form.
  void reset() {
    state = JournalEntryEditorState(postDate: DateTime.now());
    _initializeLines();
  }
}

/// Validation result.
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult.valid()
      : isValid = true,
        errorMessage = null;

  const ValidationResult.invalid(this.errorMessage) : isValid = false;
}

/// Provider for the journal entry editor state.
final journalEntryEditorProvider =
    StateNotifierProvider<JournalEntryEditorNotifier, JournalEntryEditorState>(
  (ref) => JournalEntryEditorNotifier(ref),
);
