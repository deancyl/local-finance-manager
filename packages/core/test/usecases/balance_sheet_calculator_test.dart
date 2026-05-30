import 'package:test/test.dart';
import 'package:core/core.dart';
import 'package:decimal/decimal.dart';

void main() {
  late BalanceSheetCalculator calculator;

  setUp(() {
    calculator = BalanceSheetCalculator();
  });

  group('BalanceSheetCalculator', () {
    test('empty accounts returns empty balance sheet', () async {
      final asOfDate = DateTime(2024, 12, 31);
      final result = await calculator.calculate(
        accounts: [],
        balances: [],
        asOfDate: asOfDate,
      );

      expect(result.asOfDate, equals(asOfDate));
      expect(result.assets.items, isEmpty);
      expect(result.liabilities.items, isEmpty);
      expect(result.equity.items, isEmpty);
      expect(result.assets.totalNum, equals(0));
      expect(result.liabilities.totalNum, equals(0));
      expect(result.equity.totalNum, equals(0));
      expect(result.isBalanced, isTrue);
    });

    test('single asset account balance calculation', () async {
      final accounts = [
        Account(
          id: 'cash',
          name: 'Cash',
          accountType: AccountType.asset,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
      ];

      final balances = [
        AccountBalanceRaw(
          accountId: 'cash',
          debitNum: 10000, // ¥100.00
          creditNum: 2000, // ¥20.00
          denom: 100,
        ),
      ];

      final result = await calculator.calculate(
        accounts: accounts,
        balances: balances,
        asOfDate: DateTime(2024, 12, 31),
      );

      // Asset balance = debit - credit = 10000 - 2000 = 8000 (¥80.00)
      expect(result.assets.items.length, equals(1));
      expect(result.assets.items.first.accountName, equals('Cash'));
      expect(result.assets.items.first.balanceNum, equals(8000));
      expect(result.assets.items.first.denom, equals(100));
      expect(result.assets.totalNum, equals(8000));
    });

    test('multiple accounts with different types', () async {
      final accounts = [
        Account(
          id: 'cash',
          name: 'Cash',
          accountType: AccountType.asset,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
        Account(
          id: 'payable',
          name: 'Accounts Payable',
          accountType: AccountType.liability,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
        Account(
          id: 'capital',
          name: 'Owner Capital',
          accountType: AccountType.equity,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
      ];

      final balances = [
        AccountBalanceRaw(accountId: 'cash', debitNum: 50000, creditNum: 0, denom: 100),
        AccountBalanceRaw(accountId: 'payable', debitNum: 0, creditNum: 20000, denom: 100),
        AccountBalanceRaw(accountId: 'capital', debitNum: 0, creditNum: 30000, denom: 100),
      ];

      final result = await calculator.calculate(
        accounts: accounts,
        balances: balances,
        asOfDate: DateTime(2024, 12, 31),
      );

      // Assets: 50000 (debit balance)
      expect(result.assets.totalNum, equals(50000));
      // Liabilities: 20000 (credit balance)
      expect(result.liabilities.totalNum, equals(20000));
      // Equity: 30000 (credit balance)
      expect(result.equity.totalNum, equals(30000));
      // Balance check: 50000 = 20000 + 30000
      expect(result.isBalanced, isTrue);
    });

    test('hierarchical aggregation (parent + children accounts)', () async {
      final accounts = [
        Account(
          id: 'assets',
          name: 'Assets',
          accountType: AccountType.asset,
          commodityId: 'CNY',
          isPlaceholder: true,
          liquidityType: LiquidityType.current,
        ),
        Account(
          id: 'current-assets',
          name: 'Current Assets',
          accountType: AccountType.asset,
          parentId: 'assets',
          commodityId: 'CNY',
          isPlaceholder: true,
          liquidityType: LiquidityType.current,
        ),
        Account(
          id: 'cash',
          name: 'Cash',
          accountType: AccountType.asset,
          parentId: 'current-assets',
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
        Account(
          id: 'bank',
          name: 'Bank',
          accountType: AccountType.asset,
          parentId: 'current-assets',
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
      ];

      final balances = [
        AccountBalanceRaw(accountId: 'cash', debitNum: 5000, creditNum: 1000, denom: 100),
        AccountBalanceRaw(accountId: 'bank', debitNum: 10000, creditNum: 2000, denom: 100),
      ];

      final result = await calculator.calculate(
        accounts: accounts,
        balances: balances,
        asOfDate: DateTime(2024, 12, 31),
      );

      // Total asset balance = (5000-1000) + (10000-2000) = 12000
      expect(result.assets.items.length, equals(1)); // Only root 'assets'
      expect(result.assets.items.first.children, isNotNull);
      expect(result.assets.items.first.children!.length, equals(1)); // current-assets
      expect(result.assets.totalNum, equals(12000));
    });

    test('retained earnings calculation (Income - Expense)', () async {
      final accounts = [
        Account(
          id: 'cash',
          name: 'Cash',
          accountType: AccountType.asset,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
        Account(
          id: 'capital',
          name: 'Owner Capital',
          accountType: AccountType.equity,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
        Account(
          id: 'sales',
          name: 'Sales Revenue',
          accountType: AccountType.income,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
        Account(
          id: 'expense',
          name: 'Operating Expense',
          accountType: AccountType.expense,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
      ];

      final balances = [
        AccountBalanceRaw(accountId: 'cash', debitNum: 15000, creditNum: 0, denom: 100),
        AccountBalanceRaw(accountId: 'capital', debitNum: 0, creditNum: 10000, denom: 100),
        AccountBalanceRaw(accountId: 'sales', debitNum: 0, creditNum: 8000, denom: 100),
        AccountBalanceRaw(accountId: 'expense', debitNum: 3000, creditNum: 0, denom: 100),
      ];

      final result = await calculator.calculate(
        accounts: accounts,
        balances: balances,
        asOfDate: DateTime(2024, 12, 31),
      );

      // Retained earnings = Income - Expense = 8000 - 3000 = 5000
      // Total equity = 10000 + 5000 = 15000
      // Assets = 15000
      // Balance: 15000 = 0 + 15000
      expect(result.isBalanced, isTrue);
      
      // Check retained earnings item exists
      final retainedEarningsItem = result.equity.items.where(
        (item) => item.accountId == 'retained_earnings'
      ).firstOrNull;
      expect(retainedEarningsItem, isNotNull);
      expect(retainedEarningsItem!.balanceNum, equals(5000));
      expect(retainedEarningsItem.accountName, equals('本期利润'));
    });

    test('balance verification: Assets = Liabilities + Equity', () async {
      final accounts = [
        Account(
          id: 'cash',
          name: 'Cash',
          accountType: AccountType.asset,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
        Account(
          id: 'equipment',
          name: 'Equipment',
          accountType: AccountType.asset,
          commodityId: 'CNY',
          liquidityType: LiquidityType.nonCurrent,
        ),
        Account(
          id: 'loan',
          name: 'Bank Loan',
          accountType: AccountType.liability,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
        Account(
          id: 'capital',
          name: 'Owner Capital',
          accountType: AccountType.equity,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
      ];

      final balances = [
        AccountBalanceRaw(accountId: 'cash', debitNum: 30000, creditNum: 0, denom: 100),
        AccountBalanceRaw(accountId: 'equipment', debitNum: 70000, creditNum: 0, denom: 100),
        AccountBalanceRaw(accountId: 'loan', debitNum: 0, creditNum: 40000, denom: 100),
        AccountBalanceRaw(accountId: 'capital', debitNum: 0, creditNum: 60000, denom: 100),
      ];

      final result = await calculator.calculate(
        accounts: accounts,
        balances: balances,
        asOfDate: DateTime(2024, 12, 31),
      );

      // Assets = 30000 + 70000 = 100000
      // Liabilities = 40000
      // Equity = 60000
      // 100000 = 40000 + 60000 ✓
      expect(result.isBalanced, isTrue);
      expect(calculator.verifyBalance(result), isTrue);
    });

    test('fraction arithmetic precision (LCM/GCD)', () async {
      final accounts = [
        Account(
          id: 'account-1',
          name: 'Account 1',
          accountType: AccountType.asset,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
        Account(
          id: 'account-2',
          name: 'Account 2',
          accountType: AccountType.asset,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
        Account(
          id: 'account-3',
          name: 'Account 3',
          accountType: AccountType.liability,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
      ];

      final balances = [
        AccountBalanceRaw(accountId: 'account-1', debitNum: 1, creditNum: 0, denom: 3), // 1/3
        AccountBalanceRaw(accountId: 'account-2', debitNum: 1, creditNum: 0, denom: 6), // 1/6
        AccountBalanceRaw(accountId: 'account-3', debitNum: 0, creditNum: 1, denom: 2), // 1/2
      ];

      final result = await calculator.calculate(
        accounts: accounts,
        balances: balances,
        asOfDate: DateTime(2024, 12, 31),
      );

      // LCM(3, 6) = 6 for assets
      // Assets: 1/3 + 1/6 = 2/6 + 1/6 = 3/6
      expect(result.assets.totalNum, equals(3));
      expect(result.assets.denom, equals(6));
      
      // Liability: 1/2 = 3/6
      expect(result.liabilities.totalNum, equals(3));
      expect(result.liabilities.denom, equals(6));
      
      // No equity, so not balanced
      expect(result.isBalanced, isFalse);
    });

    test('liquidity grouping (current/non-current)', () async {
      final accounts = [
        Account(
          id: 'cash',
          name: 'Cash',
          accountType: AccountType.asset,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
        Account(
          id: 'equipment',
          name: 'Equipment',
          accountType: AccountType.asset,
          commodityId: 'CNY',
          liquidityType: LiquidityType.nonCurrent,
        ),
        Account(
          id: 'loan-short',
          name: 'Short-term Loan',
          accountType: AccountType.liability,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
        Account(
          id: 'loan-long',
          name: 'Long-term Loan',
          accountType: AccountType.liability,
          commodityId: 'CNY',
          liquidityType: LiquidityType.nonCurrent,
        ),
      ];

      final balances = [
        AccountBalanceRaw(accountId: 'cash', debitNum: 10000, creditNum: 0, denom: 100),
        AccountBalanceRaw(accountId: 'equipment', debitNum: 50000, creditNum: 0, denom: 100),
        AccountBalanceRaw(accountId: 'loan-short', debitNum: 0, creditNum: 5000, denom: 100),
        AccountBalanceRaw(accountId: 'loan-long', debitNum: 0, creditNum: 20000, denom: 100),
      ];

      final result = await calculator.calculate(
        accounts: accounts,
        balances: balances,
        asOfDate: DateTime(2024, 12, 31),
      );

      // Test groupByLiquidity method
      final assetGroups = calculator.groupByLiquidity(result.assets.items);
      expect(assetGroups[LiquidityType.current]?.length, equals(1));
      expect(assetGroups[LiquidityType.nonCurrent]?.length, equals(1));
      
      final liabilityGroups = calculator.groupByLiquidity(result.liabilities.items);
      expect(liabilityGroups[LiquidityType.current]?.length, equals(1));
      expect(liabilityGroups[LiquidityType.nonCurrent]?.length, equals(1));
    });

    test('date range filtering', () async {
      final asOfDate = DateTime(2024, 12, 31);
      
      final accounts = [
        Account(
          id: 'cash',
          name: 'Cash',
          accountType: AccountType.asset,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
      ];

      final balances = [
        AccountBalanceRaw(accountId: 'cash', debitNum: 5000, creditNum: 0, denom: 100),
      ];

      final result = await calculator.calculate(
        accounts: accounts,
        balances: balances,
        asOfDate: asOfDate,
      );

      expect(result.asOfDate, equals(asOfDate));
      expect(result.generatedAt, isNotNull);
    });

    test('different account type sign conventions', () async {
      // Test that:
      // - Assets have debit balance (positive when debit > credit)
      // - Liabilities have credit balance (positive when credit > debit)
      // - Equity has credit balance (positive when credit > debit)
      
      final accounts = [
        Account(
          id: 'asset-1',
          name: 'Asset Account',
          accountType: AccountType.asset,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
        Account(
          id: 'liability-1',
          name: 'Liability Account',
          accountType: AccountType.liability,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
        Account(
          id: 'equity-1',
          name: 'Equity Account',
          accountType: AccountType.equity,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
      ];

      final balances = [
        // Asset: debit > credit, should show positive balance
        AccountBalanceRaw(accountId: 'asset-1', debitNum: 10000, creditNum: 2000, denom: 100),
        // Liability: credit > debit, should show positive balance
        AccountBalanceRaw(accountId: 'liability-1', debitNum: 1000, creditNum: 5000, denom: 100),
        // Equity: credit > debit, should show positive balance
        AccountBalanceRaw(accountId: 'equity-1', debitNum: 500, creditNum: 3500, denom: 100),
      ];

      final result = await calculator.calculate(
        accounts: accounts,
        balances: balances,
        asOfDate: DateTime(2024, 12, 31),
      );

      // Asset: 10000 - 2000 = 8000 (positive)
      expect(result.assets.items.first.balanceNum, equals(8000));
      expect(result.assets.items.first.isDebitBalance, isTrue);
      
      // Liability: 5000 - 1000 = 4000 (positive)
      expect(result.liabilities.items.first.balanceNum, equals(4000));
      
      // Equity: 3500 - 500 = 3000 (positive)
      expect(result.equity.items.first.balanceNum, equals(3000));
      
      // Balance: 8000 = 4000 + 3000 = 7000 (not balanced due to different signs)
      // Note: The balance sheet calculates based on the actual values
    });

    test('handles zero balances correctly', () async {
      final accounts = [
        Account(
          id: 'empty-asset',
          name: 'Empty Asset',
          accountType: AccountType.asset,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
        Account(
          id: 'empty-liability',
          name: 'Empty Liability',
          accountType: AccountType.liability,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
        Account(
          id: 'empty-equity',
          name: 'Empty Equity',
          accountType: AccountType.equity,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
      ];

      final balances = [
        AccountBalanceRaw(accountId: 'empty-asset', debitNum: 0, creditNum: 0, denom: 100),
        AccountBalanceRaw(accountId: 'empty-liability', debitNum: 0, creditNum: 0, denom: 100),
        AccountBalanceRaw(accountId: 'empty-equity', debitNum: 0, creditNum: 0, denom: 100),
      ];

      final result = await calculator.calculate(
        accounts: accounts,
        balances: balances,
        asOfDate: DateTime(2024, 12, 31),
      );

      expect(result.assets.items.length, equals(1));
      expect(result.assets.items.first.balanceNum, equals(0));
      expect(result.liabilities.items.length, equals(1));
      expect(result.liabilities.items.first.balanceNum, equals(0));
      expect(result.equity.items.length, equals(1));
      expect(result.equity.items.first.balanceNum, equals(0));
      expect(result.isBalanced, isTrue);
    });

    test('calculates section for specific account type', () {
      final accounts = [
        Account(
          id: 'cash',
          name: 'Cash',
          accountType: AccountType.asset,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
        Account(
          id: 'bank',
          name: 'Bank',
          accountType: AccountType.asset,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
        Account(
          id: 'payable',
          name: 'Accounts Payable',
          accountType: AccountType.liability,
          commodityId: 'CNY',
          liquidityType: LiquidityType.current,
        ),
      ];

      final balances = [
        AccountBalanceRaw(accountId: 'cash', debitNum: 5000, creditNum: 1000, denom: 100),
        AccountBalanceRaw(accountId: 'bank', debitNum: 10000, creditNum: 2000, denom: 100),
        AccountBalanceRaw(accountId: 'payable', debitNum: 0, creditNum: 8000, denom: 100),
      ];

      final assetSection = calculator.calculateSection(accounts, balances, AccountType.asset);
      
      expect(assetSection.title, equals('资产'));
      expect(assetSection.items.length, equals(2));
      // Total: (5000-1000) + (10000-2000) = 12000
      expect(assetSection.totalNum, equals(12000));
    });

    test('handles hidden accounts correctly', () async {
      final accounts = [
        Account(
          id: 'visible-asset',
          name: 'Visible Asset',
          accountType: AccountType.asset,
          commodityId: 'CNY',
          isHidden: false,
          liquidityType: LiquidityType.current,
        ),
        Account(
          id: 'hidden-asset',
          name: 'Hidden Asset',
          accountType: AccountType.asset,
          commodityId: 'CNY',
          isHidden: true,
          liquidityType: LiquidityType.current,
        ),
      ];

      final balances = [
        AccountBalanceRaw(accountId: 'visible-asset', debitNum: 10000, creditNum: 0, denom: 100),
        AccountBalanceRaw(accountId: 'hidden-asset', debitNum: 5000, creditNum: 0, denom: 100),
      ];

      final result = await calculator.calculate(
        accounts: accounts,
        balances: balances,
        asOfDate: DateTime(2024, 12, 31),
      );

      // Hidden account should not appear in items
      expect(result.assets.items.length, equals(1));
      expect(result.assets.items.first.accountName, equals('Visible Asset'));
      expect(result.assets.totalNum, equals(10000));
    });

    test('balance sheet item properties', () {
      final item = BalanceSheetItem(
        accountId: 'test',
        accountName: 'Test Account',
        accountType: AccountType.asset,
        liquidityType: LiquidityType.current,
        balanceNum: 5000,
        denom: 100,
      );

      expect(item.toDecimal, equals(Decimal.fromInt(50)));
      expect(item.isDebitBalance, isTrue);
      expect(item.isCreditBalance, isFalse);
      expect(item.absoluteBalance, equals(Decimal.fromInt(50)));
      expect(item.isCurrent, isTrue);
      expect(item.isNonCurrent, isFalse);
    });

    test('balance sheet section properties', () {
      final section = BalanceSheetSection(
        title: '资产',
        items: [],
        totalNum: 10000,
        denom: 100,
      );

      expect(section.totalDecimal, equals(Decimal.fromInt(100)));
      expect(section.absoluteTotal, equals(Decimal.fromInt(100)));
    });
  });
}
