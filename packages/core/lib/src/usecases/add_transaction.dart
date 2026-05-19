import '../models/transaction.dart';
import '../models/split.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/account_repository.dart';

/// Use case for adding a new transaction.
///
/// Supports both single-entry and double-entry modes.
/// In single-entry mode, creates one split for the account.
/// In double-entry mode, requires balanced splits (sum = 0).
class AddTransaction {
  final TransactionRepository _transactionRepository;
  final AccountRepository _accountRepository;

  AddTransaction(this._transactionRepository, this._accountRepository);

  /// Adds a single-entry transaction.
  ///
  /// Creates a transaction with one split for the given account.
  Future<Transaction> addSingleEntry({
    required String accountId,
    required double amount,
    required DateTime date,
    String? description,
    String? categoryId,
    String? notes,
    String? externalId,
  }) async {
    final account = await _accountRepository.getById(accountId);
    if (account == null) {
      throw ArgumentError('Account not found: $accountId');
    }

    final transaction = Transaction(
      postDate: date,
      commodityId: account.commodityId,
      description: description,
      notes: notes,
      externalId: externalId,
      isDoubleEntry: false,
    );

    final split = Split.fromValue(
      transactionId: transaction.id,
      accountId: accountId,
      value: amount,
      fraction: 100,
    );

    return _transactionRepository.create(transaction, [split]);
  }

  /// Adds a double-entry transaction.
  ///
  /// Validates that splits balance (sum = 0) before creating.
  Future<Transaction> addDoubleEntry({
    required String description,
    required DateTime date,
    required String currencyId,
    required List<SplitInput> splitInputs,
    String? notes,
    String? externalId,
  }) async {
    // Validate splits balance
    final totalValue = splitInputs.fold<double>(
      0,
      (sum, input) => sum + input.amount,
    );

    if (totalValue.abs() > 0.001) {
      throw ArgumentError(
        'Double-entry transaction must balance. Total: $totalValue',
      );
    }

    if (splitInputs.length < 2) {
      throw ArgumentError(
        'Double-entry transaction must have at least 2 splits.',
      );
    }

    final transaction = Transaction(
      postDate: date,
      commodityId: currencyId,
      description: description,
      notes: notes,
      externalId: externalId,
      isDoubleEntry: true,
    );

    final splits = splitInputs.map((input) {
      return Split.fromValue(
        transactionId: transaction.id,
        accountId: input.accountId,
        value: input.amount,
        memo: input.memo,
        fraction: 100,
      );
    }).toList();

    return _transactionRepository.create(transaction, splits);
  }
}

/// Input for creating a split in a double-entry transaction.
class SplitInput {
  final String accountId;
  final double amount;
  final String? memo;

  SplitInput({
    required this.accountId,
    required this.amount,
    this.memo,
  });
}