import 'package:test/test.dart';
import 'package:core/src/models/trial_balance.dart';
import 'package:core/src/models/account.dart';
import 'package:decimal/decimal.dart';

// Mock data class to simulate AccountBalanceRaw from SplitsDao
class MockAccountBalanceRaw {
  final int accountId;
  final String accountName;
  final String accountTypeCode;
  final int? parentId;
  final int debitTotal;   // numerator for debit total
  final int creditTotal;  // numerator for credit total
  final int denom;        // denominator

  MockAccountBalanceRaw({
    required this.accountId,
    required this.accountName,
    required this.accountTypeCode,
    this.parentId,
    required this.debitTotal,
    required this.creditTotal,
    required this.denom,
  });
}

// Mock TrialBalanceCalculator for testing
// This simulates the behavior until the actual implementation is created
class MockTrialBalanceCalculator {
  /// Calculates trial balance from raw account balance data
  TrialBalance calculate(
    List<MockAccountBalanceRaw> rawBalances, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (rawBalances.isEmpty) {
      return TrialBalance(
        accounts: [],
        totalDebits: 0,
        totalCredits: 0,
        commonDenom: 1,
        isBalanced: true,
        generatedAt: DateTime.now(),
        startDate: startDate,
        endDate: endDate,
      );
    }

    // Find common denominator (LCM of all denominators)
    int commonDenom = _findCommonDenominator(rawBalances);

    // Convert all balances to AccountBalance with common denominator
    final accounts = rawBalances.map((raw) {
      final multiplier = commonDenom ~/ raw.denom;
      return AccountBalance(
        accountId: raw.accountId.toString(),
        accountName: raw.accountName,
        accountType: _parseAccountType(raw.accountTypeCode),
        debitNum: raw.debitTotal * multiplier,
        creditNum: raw.creditTotal * multiplier,
        denom: commonDenom,
        parentId: raw.parentId?.toString(),
      );
    }).toList();

    // Calculate totals
    int totalDebits = accounts.fold(0, (sum, acc) => sum + acc.debitNum);
    int totalCredits = accounts.fold(0, (sum, acc) => sum + acc.creditNum);

    return TrialBalance(
      accounts: accounts,
      totalDebits: totalDebits,
      totalCredits: totalCredits,
      commonDenom: commonDenom,
      isBalanced: totalDebits == totalCredits,
      generatedAt: DateTime.now(),
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Groups accounts by type
  Map<AccountType, List<AccountBalance>> groupByType(List<AccountBalance> accounts) {
    final grouped = <AccountType, List<AccountBalance>>{};
    for (final account in accounts) {
      grouped.putIfAbsent(account.accountType, () => []).add(account);
    }
    return grouped;
  }

  /// Calculates hierarchical balances (sums child balances into parent)
  List<AccountBalance> calculateHierarchicalBalances(List<AccountBalance> accounts) {
    final accountMap = <String, AccountBalance>{
      for (final acc in accounts) acc.accountId: acc,
    };

    // Create a copy with children populated
    final result = <AccountBalance>[];
    final processedIds = <String>{};

    void processAccount(AccountBalance account) {
      if (processedIds.contains(account.accountId)) return;
      processedIds.add(account.accountId);

      // Find children
      final children = accounts
          .where((acc) => acc.parentId == account.accountId)
          .toList();

      // Process children first
      for (final child in children) {
        processAccount(child);
      }

      // Calculate total including children
      int totalDebit = account.debitNum;
      int totalCredit = account.creditNum;

      for (final child in children) {
        totalDebit += child.debitNum;
        totalCredit += child.creditNum;
      }

      result.add(account.copyWith(
        debitNum: totalDebit,
        creditNum: totalCredit,
        children: children.isEmpty ? null : children,
      ));
    }

    // Process root accounts (no parent)
    for (final account in accounts) {
      if (account.parentId == null) {
        processAccount(account);
      }
    }

    return result;
  }

  int _findCommonDenominator(List<MockAccountBalanceRaw> balances) {
    if (balances.isEmpty) return 1;
    
    int commonDenom = balances.first.denom;
    for (final balance in balances.skip(1)) {
      commonDenom = _lcm(commonDenom, balance.denom);
    }
    return commonDenom;
  }

  int _lcm(int a, int b) {
    return (a * b) ~/ _gcd(a, b);
  }

  int _gcd(int a, int b) {
    while (b != 0) {
      final temp = b;
      b = a % b;
      a = temp;
    }
    return a;
  }

  AccountType _parseAccountType(String code) {
    return AccountType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => AccountType.asset,
    );
  }
}

void main() {
  late MockTrialBalanceCalculator calculator;

  setUp(() {
    calculator = MockTrialBalanceCalculator();
  });

  group('TrialBalanceCalculator', () {
    test('calculates trial balance for empty accounts', () {
      final result = calculator.calculate([]);

      expect(result.accounts, isEmpty);
      expect(result.totalDebits, equals(0));
      expect(result.totalCredits, equals(0));
      expect(result.commonDenom, equals(1));
      expect(result.isBalanced, isTrue);
    });

    test('calculates trial balance for single account', () {
      final rawBalances = [
        MockAccountBalanceRaw(
          accountId: 1,
          accountName: 'Cash',
          accountTypeCode: 'ASSET',
          debitTotal: 1000,
          creditTotal: 200,
          denom: 100,
        ),
      ];

      final result = calculator.calculate(rawBalances);

      expect(result.accounts.length, equals(1));
      expect(result.accounts.first.accountName, equals('Cash'));
      expect(result.accounts.first.debitNum, equals(1000));
      expect(result.accounts.first.creditNum, equals(200));
      expect(result.totalDebits, equals(1000));
      expect(result.totalCredits, equals(200));
      expect(result.isBalanced, isFalse);
    });

    test('calculates trial balance for multiple accounts', () {
      final rawBalances = [
        MockAccountBalanceRaw(
          accountId: 1,
          accountName: 'Cash',
          accountTypeCode: 'ASSET',
          debitTotal: 5000,
          creditTotal: 1000,
          denom: 100,
        ),
        MockAccountBalanceRaw(
          accountId: 2,
          accountName: 'Accounts Payable',
          accountTypeCode: 'LIABILITY',
          debitTotal: 500,
          creditTotal: 4500,
          denom: 100,
        ),
        MockAccountBalanceRaw(
          accountId: 3,
          accountName: 'Sales Revenue',
          accountTypeCode: 'INCOME',
          debitTotal: 0,
          creditTotal: 5000,
          denom: 100,
        ),
        MockAccountBalanceRaw(
          accountId: 4,
          accountName: 'Rent Expense',
          accountTypeCode: 'EXPENSE',
          debitTotal: 5000,
          creditTotal: 0,
          denom: 100,
        ),
      ];

      final result = calculator.calculate(rawBalances);

      expect(result.accounts.length, equals(4));
      // Total debits: 5000 + 500 + 0 + 5000 = 10500
      expect(result.totalDebits, equals(10500));
      // Total credits: 1000 + 4500 + 5000 + 0 = 10500
      expect(result.totalCredits, equals(10500));
      expect(result.isBalanced, isTrue);
    });

    test('groups accounts by type correctly', () {
      final accounts = [
        AccountBalance(
          accountId: '1',
          accountName: 'Cash',
          accountType: AccountType.asset,
          debitNum: 1000,
          creditNum: 0,
          denom: 100,
        ),
        AccountBalance(
          accountId: '2',
          accountName: 'Bank',
          accountType: AccountType.asset,
          debitNum: 5000,
          creditNum: 0,
          denom: 100,
        ),
        AccountBalance(
          accountId: '3',
          accountName: 'Accounts Payable',
          accountType: AccountType.liability,
          debitNum: 0,
          creditNum: 3000,
          denom: 100,
        ),
        AccountBalance(
          accountId: '4',
          accountName: 'Sales',
          accountType: AccountType.income,
          debitNum: 0,
          creditNum: 2000,
          denom: 100,
        ),
      ];

      final grouped = calculator.groupByType(accounts);

      expect(grouped[AccountType.asset]?.length, equals(2));
      expect(grouped[AccountType.liability]?.length, equals(1));
      expect(grouped[AccountType.income]?.length, equals(1));
      expect(grouped[AccountType.expense], isNull);
      expect(grouped[AccountType.equity], isNull);
    });

    test('calculates hierarchical account balances', () {
      final accounts = [
        AccountBalance(
          accountId: '1',
          accountName: 'Assets',
          accountType: AccountType.asset,
          debitNum: 0,
          creditNum: 0,
          denom: 100,
          parentId: null,
        ),
        AccountBalance(
          accountId: '2',
          accountName: 'Current Assets',
          accountType: AccountType.asset,
          debitNum: 0,
          creditNum: 0,
          denom: 100,
          parentId: '1',
        ),
        AccountBalance(
          accountId: '3',
          accountName: 'Cash',
          accountType: AccountType.asset,
          debitNum: 5000,
          creditNum: 500,
          denom: 100,
          parentId: '2',
        ),
        AccountBalance(
          accountId: '4',
          accountName: 'Bank',
          accountType: AccountType.asset,
          debitNum: 10000,
          creditNum: 1000,
          denom: 100,
          parentId: '2',
        ),
      ];

      final result = calculator.calculateHierarchicalBalances(accounts);

      // Should have root account with aggregated totals
      expect(result.length, equals(1));
      expect(result.first.accountId, equals(1));
      // Total debit: 0 + 0 + 5000 + 10000 = 15000
      expect(result.first.debitNum, equals(15000));
      // Total credit: 0 + 0 + 500 + 1000 = 1500
      expect(result.first.creditNum, equals(1500));
    });

    test('verifies balanced trial balance', () {
      final rawBalances = [
        MockAccountBalanceRaw(
          accountId: 1,
          accountName: 'Cash',
          accountTypeCode: 'ASSET',
          debitTotal: 10000,
          creditTotal: 0,
          denom: 100,
        ),
        MockAccountBalanceRaw(
          accountId: 2,
          accountName: 'Capital',
          accountTypeCode: 'EQUITY',
          debitTotal: 0,
          creditTotal: 10000,
          denom: 100,
        ),
      ];

      final result = calculator.calculate(rawBalances);

      expect(result.isBalanced, isTrue);
      expect(result.totalDebits, equals(result.totalCredits));
      expect(result.difference, equals(Decimal.zero));
    });

    test('detects unbalanced trial balance', () {
      final rawBalances = [
        MockAccountBalanceRaw(
          accountId: 1,
          accountName: 'Cash',
          accountTypeCode: 'ASSET',
          debitTotal: 10000,
          creditTotal: 0,
          denom: 100,
        ),
        MockAccountBalanceRaw(
          accountId: 2,
          accountName: 'Capital',
          accountTypeCode: 'EQUITY',
          debitTotal: 0,
          creditTotal: 8000, // Unbalanced!
          denom: 100,
        ),
      ];

      final result = calculator.calculate(rawBalances);

      expect(result.isBalanced, isFalse);
      expect(result.totalDebits, equals(10000));
      expect(result.totalCredits, equals(8000));
      expect(result.difference, equals(Decimal.fromInt(20)));
    });

    test('handles date range filtering', () {
      final startDate = DateTime(2024, 1, 1);
      final endDate = DateTime(2024, 12, 31);

      final rawBalances = [
        MockAccountBalanceRaw(
          accountId: 1,
          accountName: 'Cash',
          accountTypeCode: 'ASSET',
          debitTotal: 5000,
          creditTotal: 0,
          denom: 100,
        ),
      ];

      final result = calculator.calculate(
        rawBalances,
        startDate: startDate,
        endDate: endDate,
      );

      expect(result.startDate, equals(startDate));
      expect(result.endDate, equals(endDate));
      expect(result.accounts.length, equals(1));
    });

    test('uses fraction arithmetic correctly', () {
      // Test with different denominators
      final rawBalances = [
        MockAccountBalanceRaw(
          accountId: 1,
          accountName: 'Account A',
          accountTypeCode: 'ASSET',
          debitTotal: 1,  // 1/3
          creditTotal: 0,
          denom: 3,
        ),
        MockAccountBalanceRaw(
          accountId: 2,
          accountName: 'Account B',
          accountTypeCode: 'LIABILITY',
          debitTotal: 0,
          creditTotal: 1,  // 1/3
          denom: 3,
        ),
        MockAccountBalanceRaw(
          accountId: 3,
          accountName: 'Account C',
          accountTypeCode: 'EQUITY',
          debitTotal: 1,  // 1/6
          creditTotal: 1,  // 1/6
          denom: 6,
        ),
      ];

      final result = calculator.calculate(rawBalances);

      // Common denominator should be LCM(3, 3, 6) = 6
      expect(result.commonDenom, equals(6));
      
      // Account A: 1/3 = 2/6
      expect(result.accounts[0].debitNum, equals(2));
      expect(result.accounts[0].creditNum, equals(0));
      
      // Account B: 1/3 = 2/6
      expect(result.accounts[1].debitNum, equals(0));
      expect(result.accounts[1].creditNum, equals(2));
      
      // Account C: 1/6 = 1/6
      expect(result.accounts[2].debitNum, equals(1));
      expect(result.accounts[2].creditNum, equals(1));
      
      // Total: debits = 2 + 0 + 1 = 3, credits = 0 + 2 + 1 = 3
      expect(result.totalDebits, equals(3));
      expect(result.totalCredits, equals(3));
      expect(result.isBalanced, isTrue);
    });

    test('handles zero balances', () {
      final rawBalances = [
        MockAccountBalanceRaw(
          accountId: 1,
          accountName: 'Empty Account',
          accountTypeCode: 'ASSET',
          debitTotal: 0,
          creditTotal: 0,
          denom: 100,
        ),
        MockAccountBalanceRaw(
          accountId: 2,
          accountName: 'Active Account',
          accountTypeCode: 'LIABILITY',
          debitTotal: 0,
          creditTotal: 0,
          denom: 100,
        ),
      ];

      final result = calculator.calculate(rawBalances);

      expect(result.accounts.length, equals(2));
      expect(result.totalDebits, equals(0));
      expect(result.totalCredits, equals(0));
      expect(result.isBalanced, isTrue);
      
      // Verify zero balances are preserved
      expect(result.accounts[0].debitDecimal, equals(Decimal.zero));
      expect(result.accounts[0].creditDecimal, equals(Decimal.zero));
      expect(result.accounts[1].debitDecimal, equals(Decimal.zero));
      expect(result.accounts[1].creditDecimal, equals(Decimal.zero));
    });
  });
}
