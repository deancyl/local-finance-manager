import '../models/account.dart';
import '../repositories/account_repository.dart';
import '../repositories/transaction_repository.dart';

/// Use case for calculating account balances.
class GetBalance {
  final AccountRepository _accountRepository;
  final TransactionRepository _transactionRepository;

  GetBalance(this._accountRepository, this._transactionRepository);

  /// Gets the current balance of an account.
  Future<AccountBalance> getAccountBalance(String accountId) async {
    final account = await _accountRepository.getById(accountId);
    if (account == null) {
      throw ArgumentError('Account not found: $accountId');
    }

    final balance = await _accountRepository.getBalance(accountId);
    return AccountBalance(
      accountId: accountId,
      accountName: account.name,
      balance: balance,
      currency: account.commodityId,
      asOf: DateTime.now(),
    );
  }

  /// Gets the balance of all accounts.
  Future<List<AccountBalance>> getAllBalances() async {
    final accounts = await _accountRepository.getAll();
    final balances = await Future.wait(
      accounts.map((account) => getAccountBalance(account.id)),
    );
    return balances;
  }

  /// Gets the total balance for accounts of a specific type.
  Future<double> getTotalBalanceByType(String accountType) async {
    final balances = await getAllBalances();
    return balances.fold<double>(
      0,
      (sum, balance) => sum + balance.balance,
    );
  }

  /// Gets the net worth (total assets minus total liabilities).
  Future<double> getNetWorth() async {
    final assetAccounts = await _accountRepository.getByType(
      AccountType.asset,
    );
    final liabilityAccounts = await _accountRepository.getByType(
      AccountType.liability,
    );

    final assetTotal = await Future.wait(
      assetAccounts.map((a) => _accountRepository.getBalance(a.id)),
    ).then((balances) => balances.fold<double>(0, (sum, b) => sum + b));

    final liabilityTotal = await Future.wait(
      liabilityAccounts.map((a) => _accountRepository.getBalance(a.id)),
    ).then((balances) => balances.fold<double>(0, (sum, b) => sum + b));

    return assetTotal - liabilityTotal;
  }
}

/// Represents the balance of an account at a specific point in time.
class AccountBalance {
  final String accountId;
  final String accountName;
  final double balance;
  final String currency;
  final DateTime asOf;

  AccountBalance({
    required this.accountId,
    required this.accountName,
    required this.balance,
    required this.currency,
    required this.asOf,
  });

  /// Returns true if the balance is positive.
  bool get isPositive => balance > 0;

  /// Returns true if the balance is negative.
  bool get isNegative => balance < 0;

  /// Returns the balance formatted as a string.
  String format({String symbol = '¥'}) {
    return '$symbol${balance.abs().toStringAsFixed(2)}';
  }
}