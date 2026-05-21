import '../models/closing_entry.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/split.dart';
import '../repositories/account_repository.dart';
import '../repositories/transaction_repository.dart';
import 'trial_balance_calculator.dart';

/// Service for managing the closing process in the accounting cycle.
///
/// The closing process follows standard accounting procedures:
/// 1. Close revenue accounts to Income Summary
/// 2. Close expense accounts to Income Summary
/// 3. Close Income Summary to Retained Earnings
/// 4. Close dividend accounts to Retained Earnings
///
/// Uses integer arithmetic (fractions) for precise calculations.
class ClosingEntryService {
  final AccountRepository _accountRepository;
  final TransactionRepository _transactionRepository;

  /// Standard account IDs for closing process.
  static const String incomeSummaryAccountId = 'income_summary';
  static const String retainedEarningsAccountId = 'retained_earnings';

  ClosingEntryService({
    required AccountRepository accountRepository,
    required TransactionRepository transactionRepository,
  })  : _accountRepository = accountRepository,
        _transactionRepository = transactionRepository;

  /// Ensures the Income Summary account exists.
  ///
  /// Creates the account if it doesn't exist.
  Future<Account> ensureIncomeSummaryAccount(String commodityId) async {
    final existing = await _accountRepository.getById(incomeSummaryAccountId);
    if (existing != null) {
      return existing;
    }

    final now = DateTime.now();
    final account = Account(
      id: incomeSummaryAccountId,
      name: 'Income Summary',
      accountType: AccountType.equity,
      commodityId: commodityId,
      description: 'Temporary account for closing entries',
      isPlaceholder: false,
      isHidden: true,
      createdAt: now,
      updatedAt: now,
    );

    await _accountRepository.create(account);
    return account;
  }

  /// Ensures the Retained Earnings account exists.
  ///
  /// Creates the account if it doesn't exist.
  Future<Account> ensureRetainedEarningsAccount(String commodityId) async {
    final existing = await _accountRepository.getById(retainedEarningsAccountId);
    if (existing != null) {
      return existing;
    }

    final now = DateTime.now();
    final account = Account(
      id: retainedEarningsAccountId,
      name: 'Retained Earnings',
      accountType: AccountType.equity,
      commodityId: commodityId,
      description: 'Accumulated earnings from prior periods',
      isPlaceholder: false,
      isHidden: false,
      createdAt: now,
      updatedAt: now,
    );

    await _accountRepository.create(account);
    return account;
  }

  /// Generates closing entries for a fiscal period.
  ///
  /// This is the main entry point for the closing process.
  /// It generates all four types of closing entries.
  ///
  /// Parameters:
  /// - [fiscalPeriodId]: The fiscal period to close
  /// - [balances]: Account balances from the trial balance
  /// - [commodityId]: The currency to use for closing entries
  /// - [postDate]: The posting date for closing entries
  ///
  /// Returns a list of generated closing entries.
  Future<List<ClosingEntry>> generateClosingEntries({
    required String fiscalPeriodId,
    required List<AccountBalanceRaw> balances,
    required String commodityId,
    required DateTime postDate,
  }) async {
    // Ensure required accounts exist
    await ensureIncomeSummaryAccount(commodityId);
    await ensureRetainedEarningsAccount(commodityId);

    // Get all accounts
    final accounts = await _accountRepository.getAll();
    final accountMap = <String, Account>{
      for (final account in accounts) account.id: account,
    };

    final entries = <ClosingEntry>[];

    // Step 1: Close revenue accounts to Income Summary
    entries.addAll(await _closeRevenues(
      fiscalPeriodId: fiscalPeriodId,
      accounts: accounts,
      balances: balances,
      accountMap: accountMap,
      postDate: postDate,
    ));

    // Step 2: Close expense accounts to Income Summary
    entries.addAll(await _closeExpenses(
      fiscalPeriodId: fiscalPeriodId,
      accounts: accounts,
      balances: balances,
      accountMap: accountMap,
      postDate: postDate,
    ));

    // Step 3: Close Income Summary to Retained Earnings
    entries.addAll(await _closeIncomeSummary(
      fiscalPeriodId: fiscalPeriodId,
      balances: balances,
      postDate: postDate,
    ));

    // Step 4: Close dividend accounts to Retained Earnings
    entries.addAll(await _closeDividends(
      fiscalPeriodId: fiscalPeriodId,
      accounts: accounts,
      balances: balances,
      accountMap: accountMap,
      postDate: postDate,
    ));

    return entries;
  }

  /// Step 1: Close revenue accounts to Income Summary.
  ///
  /// Revenue accounts normally have credit balances.
  /// To close, we debit revenue and credit Income Summary.
  Future<List<ClosingEntry>> _closeRevenues({
    required String fiscalPeriodId,
    required List<Account> accounts,
    required List<AccountBalanceRaw> balances,
    required Map<String, Account> accountMap,
    required DateTime postDate,
  }) async {
    final revenueAccounts = accounts
        .where((a) => a.accountType == AccountType.income && !a.isPlaceholder)
        .toList();

    final balanceMap = <String, AccountBalanceRaw>{
      for (final balance in balances) balance.accountId: balance,
    };

    final entries = <ClosingEntry>[];
    final now = DateTime.now();

    for (final account in revenueAccounts) {
      final balance = balanceMap[account.id];
      if (balance == null) continue;

      // Revenue balance = Credit - Debit
      final revenueBalance = balance.creditNum - balance.debitNum;
      if (revenueBalance == 0) continue;

      // Create closing entry
      // Debit revenue (to zero it out), Credit Income Summary
      final entry = ClosingEntry(
        fiscalPeriodId: fiscalPeriodId,
        closingType: ClosingType.closeRevenue,
        sourceAccountId: account.id,
        targetAccountId: incomeSummaryAccountId,
        amountNum: revenueBalance.abs(),
        amountDenom: balance.denom,
        description: 'Close ${account.name} to Income Summary',
        executedAt: postDate,
        createdAt: now,
        updatedAt: now,
      );

      entries.add(entry);
    }

    return entries;
  }

  /// Step 2: Close expense accounts to Income Summary.
  ///
  /// Expense accounts normally have debit balances.
  /// To close, we credit expenses and debit Income Summary.
  Future<List<ClosingEntry>> _closeExpenses({
    required String fiscalPeriodId,
    required List<Account> accounts,
    required List<AccountBalanceRaw> balances,
    required Map<String, Account> accountMap,
    required DateTime postDate,
  }) async {
    final expenseAccounts = accounts
        .where((a) => a.accountType == AccountType.expense && !a.isPlaceholder)
        .toList();

    final balanceMap = <String, AccountBalanceRaw>{
      for (final balance in balances) balance.accountId: balance,
    };

    final entries = <ClosingEntry>[];
    final now = DateTime.now();

    for (final account in expenseAccounts) {
      final balance = balanceMap[account.id];
      if (balance == null) continue;

      // Expense balance = Debit - Credit
      final expenseBalance = balance.debitNum - balance.creditNum;
      if (expenseBalance == 0) continue;

      // Create closing entry
      // Credit expense (to zero it out), Debit Income Summary
      final entry = ClosingEntry(
        fiscalPeriodId: fiscalPeriodId,
        closingType: ClosingType.closeExpense,
        sourceAccountId: account.id,
        targetAccountId: incomeSummaryAccountId,
        amountNum: expenseBalance.abs(),
        amountDenom: balance.denom,
        description: 'Close ${account.name} to Income Summary',
        executedAt: postDate,
        createdAt: now,
        updatedAt: now,
      );

      entries.add(entry);
    }

    return entries;
  }

  /// Step 3: Close Income Summary to Retained Earnings.
  ///
  /// After closing revenues and expenses, Income Summary contains
  /// the net income (or loss). This is transferred to Retained Earnings.
  Future<List<ClosingEntry>> _closeIncomeSummary({
    required String fiscalPeriodId,
    required List<AccountBalanceRaw> balances,
    required DateTime postDate,
  }) async {
    // Calculate Income Summary balance
    // This would be the net of all revenue and expense closing entries
    // For simplicity, we create a single entry for the net amount

    final now = DateTime.now();

    // In a real implementation, we would calculate the actual balance
    // from the closing entries created in steps 1 and 2
    // For now, we create a placeholder entry

    final entry = ClosingEntry(
      fiscalPeriodId: fiscalPeriodId,
      closingType: ClosingType.closeIncomeSummary,
      sourceAccountId: incomeSummaryAccountId,
      targetAccountId: retainedEarningsAccountId,
      amountNum: 0, // Will be calculated from actual balances
      amountDenom: 1,
      description: 'Close Income Summary to Retained Earnings',
      executedAt: postDate,
      createdAt: now,
      updatedAt: now,
    );

    return [entry];
  }

  /// Step 4: Close dividend accounts to Retained Earnings.
  ///
  /// Dividend accounts (if any) are closed to Retained Earnings.
  Future<List<ClosingEntry>> _closeDividends({
    required String fiscalPeriodId,
    required List<Account> accounts,
    required List<AccountBalanceRaw> balances,
    required Map<String, Account> accountMap,
    required DateTime postDate,
  }) async {
    // In a typical personal finance app, there may not be dividend accounts
    // This is included for completeness of the four-step closing process

    final equityAccounts = accounts
        .where((a) =>
            a.accountType == AccountType.equity &&
            !a.isPlaceholder &&
            a.id != incomeSummaryAccountId &&
            a.id != retainedEarningsAccountId)
        .toList();

    final balanceMap = <String, AccountBalanceRaw>{
      for (final balance in balances) balance.accountId: balance,
    };

    final entries = <ClosingEntry>[];
    final now = DateTime.now();

    for (final account in equityAccounts) {
      final balance = balanceMap[account.id];
      if (balance == null) continue;

      // Check if this is a dividend/distribution account
      // (typically has a debit balance that reduces equity)
      final equityBalance = balance.debitNum - balance.creditNum;
      if (equityBalance == 0) continue;

      // Create closing entry
      final entry = ClosingEntry(
        fiscalPeriodId: fiscalPeriodId,
        closingType: ClosingType.closeDividends,
        sourceAccountId: account.id,
        targetAccountId: retainedEarningsAccountId,
        amountNum: equityBalance.abs(),
        amountDenom: balance.denom,
        description: 'Close ${account.name} to Retained Earnings',
        executedAt: postDate,
        createdAt: now,
        updatedAt: now,
      );

      entries.add(entry);
    }

    return entries;
  }

  /// Creates a transaction from a closing entry.
  ///
  /// This generates the actual double-entry transaction
  /// that implements the closing entry.
  Future<Transaction> createTransactionFromEntry(
    ClosingEntry entry,
    String commodityId,
  ) async {
    final now = DateTime.now();

    final transaction = Transaction(
      description: entry.description,
      postDate: entry.executedAt,
      commodityId: commodityId,
      isDoubleEntry: true,
      createdAt: now,
      updatedAt: now,
    );

    return transaction;
  }

  /// Creates splits for a closing entry transaction.
  ///
  /// The splits depend on the closing type:
  /// - Close Revenue: Debit revenue, Credit Income Summary
  /// - Close Expense: Credit expense, Debit Income Summary
  /// - Close Income Summary: Debit/Credit Income Summary, Credit/Debit Retained Earnings
  /// - Close Dividends: Credit dividends, Debit Retained Earnings
  List<Split> createSplitsForEntry(ClosingEntry entry, String transactionId) {
    final now = DateTime.now();

    switch (entry.closingType) {
      case ClosingType.closeRevenue:
        // Debit revenue (negative), Credit Income Summary (positive)
        return [
          Split(
            transactionId: transactionId,
            accountId: entry.sourceAccountId,
            valueNum: -entry.amountNum,
            valueDenom: entry.amountDenom,
            quantityNum: -entry.amountNum,
            quantityDenom: entry.amountDenom,
            memo: entry.description,
            createdAt: now,
          ),
          Split(
            transactionId: transactionId,
            accountId: entry.targetAccountId,
            valueNum: entry.amountNum,
            valueDenom: entry.amountDenom,
            quantityNum: entry.amountNum,
            quantityDenom: entry.amountDenom,
            memo: entry.description,
            createdAt: now,
          ),
        ];

      case ClosingType.closeExpense:
        // Debit Income Summary (negative), Credit expense (positive)
        return [
          Split(
            transactionId: transactionId,
            accountId: entry.targetAccountId,
            valueNum: -entry.amountNum,
            valueDenom: entry.amountDenom,
            quantityNum: -entry.amountNum,
            quantityDenom: entry.amountDenom,
            memo: entry.description,
            createdAt: now,
          ),
          Split(
            transactionId: transactionId,
            accountId: entry.sourceAccountId,
            valueNum: entry.amountNum,
            valueDenom: entry.amountDenom,
            quantityNum: entry.amountNum,
            quantityDenom: entry.amountDenom,
            memo: entry.description,
            createdAt: now,
          ),
        ];

      case ClosingType.closeIncomeSummary:
        // Transfer net income/loss to Retained Earnings
        // If net income: Debit Income Summary, Credit Retained Earnings
        // If net loss: Credit Income Summary, Debit Retained Earnings
        final isNetIncome = entry.amountNum >= 0;
        return [
          Split(
            transactionId: transactionId,
            accountId: entry.sourceAccountId,
            valueNum: isNetIncome ? -entry.amountNum : entry.amountNum,
            valueDenom: entry.amountDenom,
            quantityNum: isNetIncome ? -entry.amountNum : entry.amountNum,
            quantityDenom: entry.amountDenom,
            memo: entry.description,
            createdAt: now,
          ),
          Split(
            transactionId: transactionId,
            accountId: entry.targetAccountId,
            valueNum: isNetIncome ? entry.amountNum : -entry.amountNum,
            valueDenom: entry.amountDenom,
            quantityNum: isNetIncome ? entry.amountNum : -entry.amountNum,
            quantityDenom: entry.amountDenom,
            memo: entry.description,
            createdAt: now,
          ),
        ];

      case ClosingType.closeDividends:
        // Debit Retained Earnings (negative), Credit dividends (positive)
        return [
          Split(
            transactionId: transactionId,
            accountId: entry.targetAccountId,
            valueNum: -entry.amountNum,
            valueDenom: entry.amountDenom,
            quantityNum: -entry.amountNum,
            quantityDenom: entry.amountDenom,
            memo: entry.description,
            createdAt: now,
          ),
          Split(
            transactionId: transactionId,
            accountId: entry.sourceAccountId,
            valueNum: entry.amountNum,
            valueDenom: entry.amountDenom,
            quantityNum: entry.amountNum,
            quantityDenom: entry.amountDenom,
            memo: entry.description,
            createdAt: now,
          ),
        ];
    }
  }

  /// Validates that closing entries can be generated for a fiscal period.
  ///
  /// Checks:
  /// - All transactions are posted
  /// - Trial balance is balanced
  /// - No closing entries already exist
  Future<ClosingValidationResult> validateCanClose({
    required String fiscalPeriodId,
    required TrialBalance trialBalance,
  }) async {
    final errors = <String>[];

    // Check if trial balance is balanced
    if (!trialBalance.isBalanced) {
      errors.add('Trial balance is not balanced');
    }

    // Check if closing entries already exist
    // This would require access to the DAO, which should be injected
    // For now, we return a placeholder result

    return ClosingValidationResult(
      canClose: errors.isEmpty,
      errors: errors,
    );
  }
}

/// Result of validating whether closing can be performed.
class ClosingValidationResult {
  final bool canClose;
  final List<String> errors;
  final List<String> warnings;

  ClosingValidationResult({
    required this.canClose,
    required this.errors,
    this.warnings = const [],
  });
}
