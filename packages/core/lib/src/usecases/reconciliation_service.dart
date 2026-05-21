import '../repositories/account_repository.dart';
import '../repositories/transaction_repository.dart';
import '../models/split.dart' show ReconcileState;

/// Represents a reconciliation session for an account.
class ReconciliationSession {
  final String accountId;
  final String accountName;
  final DateTime statementDate;
  final int statementBalanceNum; // Integer numerator for balance
  final int statementBalanceDenom; // Integer denominator (usually 1 or 100)
  final DateTime startDate;
  final DateTime endDate;

  ReconciliationSession({
    required this.accountId,
    required this.accountName,
    required this.statementDate,
    required this.statementBalanceNum,
    this.statementBalanceDenom = 1,
    required this.startDate,
    required this.endDate,
  });

  /// Statement balance as decimal (for display only).
  double get statementBalance => statementBalanceNum / statementBalanceDenom.toDouble();
}

/// Result of reconciliation calculation.
class ReconciliationResult {
  final int clearedBalanceNum; // Sum of cleared splits (integer)
  final int clearedBalanceDenom;
  final int differenceNum; // Statement - Cleared (integer)
  final int differenceDenom;
  final List<ReconciliationSplitData> splits;
  final bool isBalanced;

  ReconciliationResult({
    required this.clearedBalanceNum,
    this.clearedBalanceDenom = 1,
    required this.differenceNum,
    this.differenceDenom = 1,
    required this.splits,
    required this.isBalanced,
  });

  /// Cleared balance as decimal (for display only).
  double get clearedBalance => clearedBalanceNum / clearedBalanceDenom.toDouble();

  /// Difference as decimal (for display only).
  double get difference => differenceNum / differenceDenom.toDouble();
}

/// Split data for reconciliation display.
/// Contains all info needed for reconciliation UI.
class ReconciliationSplitData {
  final String splitId;
  final String transactionId;
  final DateTime postDate;
  final String? description;
  final String? memo;
  final int valueNum; // Integer numerator
  final int valueDenom; // Integer denominator
  final ReconcileState reconcileState;
  final DateTime? reconcileDate;

  ReconciliationSplitData({
    required this.splitId,
    required this.transactionId,
    required this.postDate,
    this.description,
    this.memo,
    required this.valueNum,
    this.valueDenom = 1,
    required this.reconcileState,
    this.reconcileDate,
  });

  /// Value as decimal (for display only).
  double get value => valueNum / valueDenom.toDouble();
  
  /// Returns true if this split is cleared or reconciled.
  bool get isClearedOrReconciled => 
      reconcileState == ReconcileState.cleared || 
      reconcileState == ReconcileState.reconciled;
}

/// Use case for account reconciliation.
/// 
/// Reconciliation verifies that the account balance in the system
/// matches the balance shown on an external statement (bank statement, etc).
class ReconciliationService {
  final AccountRepository _accountRepository;
  final TransactionRepository _transactionRepository;

  ReconciliationService(this._accountRepository, this._transactionRepository);

  /// Starts a new reconciliation session for an account.
  /// 
  /// Parameters:
  /// - accountId: The account to reconcile
  /// - statementDate: The date of the external statement
  /// - statementBalanceNum: The balance from the statement (integer numerator)
  /// - statementBalanceDenom: The denominator (usually 1 or 100 for cents)
  /// 
  /// Returns a ReconciliationSession with splits to reconcile.
  Future<ReconciliationResult> startReconciliation({
    required String accountId,
    required DateTime statementDate,
    required int statementBalanceNum,
    int statementBalanceDenom = 1,
  }) async {
    // Get account info
    final account = await _accountRepository.getById(accountId);
    if (account == null) {
      throw ArgumentError('Account not found: $accountId');
    }

    // Get splits for this account up to statement date
    final splits = await _transactionRepository.getSplitsForAccount(
      accountId,
      endDate: statementDate,
    );

    // Convert splits to reconciliation format
    final reconciliationSplits = splits.map((split) {
      // Parse reconcile state from database string
      final state = _parseReconcileState(split.reconcileState);
      
      return ReconciliationSplitData(
        splitId: split.splitId,
        transactionId: split.transactionId,
        postDate: split.date,
        description: split.description,
        memo: split.memo,
        valueNum: split.valueNum,
        valueDenom: split.valueDenom,
        reconcileState: state,
        reconcileDate: split.reconcileDate != null 
            ? DateTime.fromMillisecondsSinceEpoch(split.reconcileDate!)
            : null,
      );
    }).toList();

    // Calculate cleared balance (sum of splits with state 'c' or 'y')
    // Use integer arithmetic to avoid floating point errors
    int clearedNum = 0;
    int denom = 1;

    for (final split in reconciliationSplits) {
      if (split.reconcileState == ReconcileState.cleared ||
          split.reconcileState == ReconcileState.reconciled) {
        // Convert to common denominator for addition
        final commonDenom = denom * split.valueDenom;
        clearedNum = clearedNum * split.valueDenom + split.valueNum * denom;
        denom = commonDenom;
      }
    }

    // Calculate difference: Statement - Cleared
    // Convert statement balance to same denominator
    final commonDenom = denom * statementBalanceDenom;
    final statementNum = statementBalanceNum * denom;
    final clearedNumAdjusted = clearedNum * statementBalanceDenom;
    final differenceNum = statementNum - clearedNumAdjusted;

    // Check if balanced (difference is zero)
    final isBalanced = differenceNum == 0;

    return ReconciliationResult(
      clearedBalanceNum: clearedNum,
      clearedBalanceDenom: denom,
      differenceNum: differenceNum,
      differenceDenom: commonDenom,
      splits: reconciliationSplits,
      isBalanced: isBalanced,
    );
  }

  /// Marks a split as cleared ('c').
  /// 
  /// This indicates the transaction appears on the statement
  /// but hasn't been fully reconciled yet.
  Future<void> markSplitCleared(String splitId) async {
    await _transactionRepository.updateSplitReconcileState(
      splitId,
      ReconcileState.cleared.code,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Marks a split as reconciled ('y').
  /// 
  /// This indicates the transaction has been fully verified
  /// against the statement.
  Future<void> markSplitReconciled(String splitId) async {
    await _transactionRepository.updateSplitReconcileState(
      splitId,
      ReconcileState.reconciled.code,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Marks a split as not reconciled ('n').
  /// 
  /// This resets the reconciliation status.
  Future<void> markSplitNotReconciled(String splitId) async {
    await _transactionRepository.updateSplitReconcileState(
      splitId,
      ReconcileState.none.code,
      null,
    );
  }

  /// Marks all splits in a session as reconciled.
  /// 
  /// This is called when reconciliation is complete and balanced.
  Future<void> finalizeReconciliation(List<String> splitIds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final splitId in splitIds) {
      await _transactionRepository.updateSplitReconcileState(
        splitId,
        ReconcileState.reconciled.code,
        now,
      );
    }
  }

  /// Gets the opening balance for an account as of a date.
  /// 
  /// This is the balance before the reconciliation period starts.
  Future<int> getOpeningBalance({
    required String accountId,
    required DateTime startDate,
  }) async {
    final splits = await _transactionRepository.getSplitsForAccount(
      accountId,
      endDate: startDate,
    );

    // Sum all splits using integer arithmetic
    int totalNum = 0;
    int denom = 1;

    for (final split in splits) {
      final commonDenom = denom * split.valueDenom;
      totalNum = totalNum * split.valueDenom + split.valueNum * denom;
      denom = commonDenom;
    }

    return totalNum;
  }

  /// Parses reconcile state from database string code.
  ReconcileState _parseReconcileState(String code) {
    switch (code) {
      case 'n':
        return ReconcileState.none;
      case 'c':
        return ReconcileState.cleared;
      case 'y':
        return ReconcileState.reconciled;
      case 'v':
        return ReconcileState.voided;
      default:
        return ReconcileState.none;
    }
  }
}