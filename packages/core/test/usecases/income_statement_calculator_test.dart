import 'package:test/test.dart';
import 'package:core/core.dart';
import 'package:decimal/decimal.dart';

void main() {
  late IncomeStatementCalculator calculator;

  setUp(() {
    calculator = IncomeStatementCalculator();
  });

  group('IncomeStatementCalculator', () {
    test('calculates income statement for empty accounts', () async {
      final startDate = DateTime(2024, 1, 1);
      final endDate = DateTime(2024, 12, 31);

      final result = await calculator.calculate(
        accounts: [],
        balances: [],
        startDate: startDate,
        endDate: endDate,
      );

      expect(result.revenues.items, isEmpty);
      expect(result.expenses.items, isEmpty);
      expect(result.revenues.totalNum, equals(0));
      expect(result.expenses.totalNum, equals(0));
      expect(result.netIncomeNum, equals(0));
      expect(result.startDate, equals(startDate));
      expect(result.endDate, equals(endDate));
      expect(result.isBreakEven, isTrue);
    });

    test('calculates revenue accounts with credit balance', () {
      final accounts = [
        Account(
          id: 'revenue-1',
          name: 'Sales Revenue',
          accountType: AccountType.income,
          commodityId: 'CNY',
        ),
        Account(
          id: 'revenue-2',
          name: 'Service Revenue',
          accountType: AccountType.income,
          commodityId: 'CNY',
        ),
      ];

      final balances = [
        AccountBalanceRaw(
          accountId: 'revenue-1',
          debitNum: 0,
          creditNum: 10000, // 100.00
          denom: 100,
        ),
        AccountBalanceRaw(
          accountId: 'revenue-2',
          debitNum: 0,
          creditNum: 5000, // 50.00
          denom: 100,
        ),
      ];

      final result = calculator.calculateRevenues(accounts, balances);

      expect(result.items.length, equals(2));
      expect(result.title, equals('营业收入'));
      
      // Revenue = Credit - Debit
      // Total: 10000 + 5000 = 15000 (numerator), denom = 100
      expect(result.totalNum, equals(15000));
      expect(result.denom, equals(100));
      expect(result.totalDecimal, equals(Decimal.fromInt(150)));
    });

    test('calculates expense accounts with debit balance', () {
      final accounts = [
        Account(
          id: 'expense-1',
          name: 'Rent Expense',
          accountType: AccountType.expense,
          commodityId: 'CNY',
        ),
        Account(
          id: 'expense-2',
          name: 'Utilities Expense',
          accountType: AccountType.expense,
          commodityId: 'CNY',
        ),
      ];

      final balances = [
        AccountBalanceRaw(
          accountId: 'expense-1',
          debitNum: 3000, // 30.00
          creditNum: 0,
          denom: 100,
        ),
        AccountBalanceRaw(
          accountId: 'expense-2',
          debitNum: 1500, // 15.00
          creditNum: 0,
          denom: 100,
        ),
      ];

      final result = calculator.calculateExpenses(accounts, balances);

      expect(result.items.length, equals(2));
      expect(result.title, equals('营业成本'));
      
      // Expense = Debit - Credit
      // Total: 3000 + 1500 = 4500 (numerator), denom = 100
      expect(result.totalNum, equals(4500));
      expect(result.denom, equals(100));
      expect(result.totalDecimal, equals(Decimal.fromInt(45)));
    });

    test('calculates net income correctly', () async {
      final accounts = [
        Account(
          id: 'revenue-1',
          name: 'Sales Revenue',
          accountType: AccountType.income,
          commodityId: 'CNY',
        ),
        Account(
          id: 'expense-1',
          name: 'Cost of Goods Sold',
          accountType: AccountType.expense,
          commodityId: 'CNY',
        ),
      ];

      final balances = [
        AccountBalanceRaw(
          accountId: 'revenue-1',
          debitNum: 0,
          creditNum: 10000, // 100.00 revenue
          denom: 100,
        ),
        AccountBalanceRaw(
          accountId: 'expense-1',
          debitNum: 6000, // 60.00 expense
          creditNum: 0,
          denom: 100,
        ),
      ];

      final result = await calculator.calculate(
        accounts: accounts,
        balances: balances,
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 12, 31),
      );

      // Net Income = Revenue - Expense = 10000 - 6000 = 4000 (numerator)
      expect(result.netIncomeNum, equals(4000));
      expect(result.denom, equals(100));
      expect(result.netIncomeDecimal, equals(Decimal.fromInt(40)));
      expect(result.isProfit, isTrue);
      expect(result.isLoss, isFalse);
      expect(result.isBreakEven, isFalse);
    });

    test('calculates hierarchical revenue aggregation', () {
      final accounts = [
        Account(
          id: 'revenue-root',
          name: 'Total Revenue',
          accountType: AccountType.income,
          commodityId: 'CNY',
          parentId: null,
        ),
        Account(
          id: 'revenue-product',
          name: 'Product Revenue',
          accountType: AccountType.income,
          commodityId: 'CNY',
          parentId: 'revenue-root',
        ),
        Account(
          id: 'revenue-service',
          name: 'Service Revenue',
          accountType: AccountType.income,
          commodityId: 'CNY',
          parentId: 'revenue-root',
        ),
      ];

      final balances = [
        AccountBalanceRaw(
          accountId: 'revenue-root',
          debitNum: 0,
          creditNum: 0, // Parent has no direct balance
          denom: 100,
        ),
        AccountBalanceRaw(
          accountId: 'revenue-product',
          debitNum: 0,
          creditNum: 8000, // 80.00
          denom: 100,
        ),
        AccountBalanceRaw(
          accountId: 'revenue-service',
          debitNum: 0,
          creditNum: 4000, // 40.00
          denom: 100,
        ),
      ];

      final result = calculator.calculateRevenues(accounts, balances);

      // Should aggregate child balances into parent
      expect(result.items.length, equals(1));
      expect(result.items.first.accountId, equals('revenue-root'));
      expect(result.items.first.children?.length, equals(2));
      
      // Total: 8000 + 4000 = 12000
      expect(result.totalNum, equals(12000));
      expect(result.denom, equals(100));
    });

    test('calculates hierarchical expense aggregation', () {
      final accounts = [
        Account(
          id: 'expense-root',
          name: 'Total Expenses',
          accountType: AccountType.expense,
          commodityId: 'CNY',
          parentId: null,
        ),
        Account(
          id: 'expense-rent',
          name: 'Rent Expense',
          accountType: AccountType.expense,
          commodityId: 'CNY',
          parentId: 'expense-root',
        ),
        Account(
          id: 'expense-utilities',
          name: 'Utilities',
          accountType: AccountType.expense,
          commodityId: 'CNY',
          parentId: 'expense-root',
        ),
      ];

      final balances = [
        AccountBalanceRaw(
          accountId: 'expense-root',
          debitNum: 0,
          creditNum: 0,
          denom: 100,
        ),
        AccountBalanceRaw(
          accountId: 'expense-rent',
          debitNum: 5000, // 50.00
          creditNum: 0,
          denom: 100,
        ),
        AccountBalanceRaw(
          accountId: 'expense-utilities',
          debitNum: 2000, // 20.00
          creditNum: 0,
          denom: 100,
        ),
      ];

      final result = calculator.calculateExpenses(accounts, balances);

      expect(result.items.length, equals(1));
      expect(result.items.first.accountId, equals('expense-root'));
      expect(result.items.first.children?.length, equals(2));
      
      // Total: 5000 + 2000 = 7000
      expect(result.totalNum, equals(7000));
      expect(result.denom, equals(100));
    });

    test('uses fraction arithmetic precision', () async {
      final accounts = [
        Account(
          id: 'revenue-1',
          name: 'Revenue A',
          accountType: AccountType.income,
          commodityId: 'CNY',
        ),
        Account(
          id: 'revenue-2',
          name: 'Revenue B',
          accountType: AccountType.income,
          commodityId: 'CNY',
        ),
        Account(
          id: 'expense-1',
          name: 'Expense A',
          accountType: AccountType.expense,
          commodityId: 'CNY',
        ),
      ];

      final balances = [
        AccountBalanceRaw(
          accountId: 'revenue-1',
          debitNum: 0,
          creditNum: 1, // 1/3
          denom: 3,
        ),
        AccountBalanceRaw(
          accountId: 'revenue-2',
          debitNum: 0,
          creditNum: 1, // 1/6
          denom: 6,
        ),
        AccountBalanceRaw(
          accountId: 'expense-1',
          debitNum: 1, // 1/4
          creditNum: 0,
          denom: 4,
        ),
      ];

      final result = await calculator.calculate(
        accounts: accounts,
        balances: balances,
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 12, 31),
      );

      // Revenue total: LCM(3, 6) = 6
      // Revenue A: 1/3 = 2/6
      // Revenue B: 1/6 = 1/6
      // Total revenue: 2/6 + 1/6 = 3/6 = 1/2
      
      // Net income: Revenue - Expense
      // Revenue: 1/3 + 1/6 = 1/2
      // Expense: 1/4
      // LCM(2, 4) = 4
      // Net Income = 2/4 - 1/4 = 1/4
      
      expect(result.netIncomeNum, equals(1));
      expect(result.denom, equals(4));
      expect(result.netIncomeDecimal, equals(Decimal.parse('0.25')));
    });

    test('identifies profit status correctly', () async {
      final accounts = [
        Account(
          id: 'revenue-1',
          name: 'Revenue',
          accountType: AccountType.income,
          commodityId: 'CNY',
        ),
        Account(
          id: 'expense-1',
          name: 'Expense',
          accountType: AccountType.expense,
          commodityId: 'CNY',
        ),
      ];

      final balances = [
        AccountBalanceRaw(
          accountId: 'revenue-1',
          debitNum: 0,
          creditNum: 10000,
          denom: 100,
        ),
        AccountBalanceRaw(
          accountId: 'expense-1',
          debitNum: 6000,
          creditNum: 0,
          denom: 100,
        ),
      ];

      final result = await calculator.calculate(
        accounts: accounts,
        balances: balances,
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 12, 31),
      );

      expect(result.isProfit, isTrue);
      expect(result.isLoss, isFalse);
      expect(result.isBreakEven, isFalse);
      expect(result.netIncomeNum, greaterThan(0));
    });

    test('identifies loss status correctly', () async {
      final accounts = [
        Account(
          id: 'revenue-1',
          name: 'Revenue',
          accountType: AccountType.income,
          commodityId: 'CNY',
        ),
        Account(
          id: 'expense-1',
          name: 'Expense',
          accountType: AccountType.expense,
          commodityId: 'CNY',
        ),
      ];

      final balances = [
        AccountBalanceRaw(
          accountId: 'revenue-1',
          debitNum: 0,
          creditNum: 5000,
          denom: 100,
        ),
        AccountBalanceRaw(
          accountId: 'expense-1',
          debitNum: 10000,
          creditNum: 0,
          denom: 100,
        ),
      ];

      final result = await calculator.calculate(
        accounts: accounts,
        balances: balances,
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 12, 31),
      );

      expect(result.isProfit, isFalse);
      expect(result.isLoss, isTrue);
      expect(result.isBreakEven, isFalse);
      expect(result.netIncomeNum, lessThan(0));
    });

    test('identifies break-even status correctly', () async {
      final accounts = [
        Account(
          id: 'revenue-1',
          name: 'Revenue',
          accountType: AccountType.income,
          commodityId: 'CNY',
        ),
        Account(
          id: 'expense-1',
          name: 'Expense',
          accountType: AccountType.expense,
          commodityId: 'CNY',
        ),
      ];

      final balances = [
        AccountBalanceRaw(
          accountId: 'revenue-1',
          debitNum: 0,
          creditNum: 8000,
          denom: 100,
        ),
        AccountBalanceRaw(
          accountId: 'expense-1',
          debitNum: 8000,
          creditNum: 0,
          denom: 100,
        ),
      ];

      final result = await calculator.calculate(
        accounts: accounts,
        balances: balances,
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 12, 31),
      );

      expect(result.isProfit, isFalse);
      expect(result.isLoss, isFalse);
      expect(result.isBreakEven, isTrue);
      expect(result.netIncomeNum, equals(0));
    });

    test('filters hidden accounts', () {
      final accounts = [
        Account(
          id: 'revenue-1',
          name: 'Visible Revenue',
          accountType: AccountType.income,
          commodityId: 'CNY',
          isHidden: false,
        ),
        Account(
          id: 'revenue-2',
          name: 'Hidden Revenue',
          accountType: AccountType.income,
          commodityId: 'CNY',
          isHidden: true,
        ),
      ];

      final balances = [
        AccountBalanceRaw(
          accountId: 'revenue-1',
          debitNum: 0,
          creditNum: 5000,
          denom: 100,
        ),
        AccountBalanceRaw(
          accountId: 'revenue-2',
          debitNum: 0,
          creditNum: 3000,
          denom: 100,
        ),
      ];

      final result = calculator.calculateRevenues(accounts, balances);

      // Should only include visible account
      expect(result.items.length, equals(1));
      expect(result.items.first.accountName, equals('Visible Revenue'));
      expect(result.totalNum, equals(5000));
    });

    test('handles mixed revenue with debits and credits', () {
      // Revenue can have debits (returns, discounts)
      final accounts = [
        Account(
          id: 'revenue-1',
          name: 'Sales Revenue',
          accountType: AccountType.income,
          commodityId: 'CNY',
        ),
      ];

      final balances = [
        AccountBalanceRaw(
          accountId: 'revenue-1',
          debitNum: 2000, // Returns/discounts
          creditNum: 10000, // Gross sales
          denom: 100,
        ),
      ];

      final result = calculator.calculateRevenues(accounts, balances);

      // Net revenue = Credit - Debit = 10000 - 2000 = 8000
      expect(result.items.length, equals(1));
      expect(result.items.first.amountNum, equals(8000));
      expect(result.totalNum, equals(8000));
    });

    test('handles mixed expenses with debits and credits', () {
      // Expenses can have credits (refunds, adjustments)
      final accounts = [
        Account(
          id: 'expense-1',
          name: 'Operating Expense',
          accountType: AccountType.expense,
          commodityId: 'CNY',
        ),
      ];

      final balances = [
        AccountBalanceRaw(
          accountId: 'expense-1',
          debitNum: 8000, // Expenses
          creditNum: 1000, // Refunds/adjustments
          denom: 100,
        ),
      ];

      final result = calculator.calculateExpenses(accounts, balances);

      // Net expense = Debit - Credit = 8000 - 1000 = 7000
      expect(result.items.length, equals(1));
      expect(result.items.first.amountNum, equals(7000));
      expect(result.totalNum, equals(7000));
    });

    test('calculatesNetIncome method works correctly', () {
      // Test the standalone calculateNetIncome method
      final (num1, denom1) = calculator.calculateNetIncome(
        100, // revenue numerator
        10,  // revenue denominator (10.0)
        60,  // expense numerator
        10,  // expense denominator (6.0)
      );

      expect(num1, equals(40)); // 100 - 60 = 40
      expect(denom1, equals(10)); // Net income: 4.0

      // Test with different denominators
      final (num2, denom2) = calculator.calculateNetIncome(
        100, // revenue numerator (1/2 = 0.5)
        2,   // revenue denominator
        50,  // expense numerator (1/4 = 0.25)
        4,   // expense denominator
      );

      // LCM(2, 4) = 4
      // Revenue: 100 * 2 = 200 (numerator at denom 4)
      // Expense: 50 * 1 = 50 (numerator at denom 4)
      // Net: 200 - 50 = 150
      // Simplified: GCD(150, 4) = 2, so 150/2 = 75, 4/2 = 2
      expect(num2, equals(75));
      expect(denom2, equals(2)); // Net income: 37.5
    });

    test('handles zero balances for all accounts', () async {
      final accounts = [
        Account(
          id: 'revenue-1',
          name: 'Revenue',
          accountType: AccountType.income,
          commodityId: 'CNY',
        ),
        Account(
          id: 'expense-1',
          name: 'Expense',
          accountType: AccountType.expense,
          commodityId: 'CNY',
        ),
      ];

      final balances = [
        AccountBalanceRaw(
          accountId: 'revenue-1',
          debitNum: 0,
          creditNum: 0,
          denom: 100,
        ),
        AccountBalanceRaw(
          accountId: 'expense-1',
          debitNum: 0,
          creditNum: 0,
          denom: 100,
        ),
      ];

      final result = await calculator.calculate(
        accounts: accounts,
        balances: balances,
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 12, 31),
      );

      expect(result.revenues.totalNum, equals(0));
      expect(result.expenses.totalNum, equals(0));
      expect(result.netIncomeNum, equals(0));
      expect(result.isBreakEven, isTrue);
    });

    test('calculates complex income statement with multiple account types', () async {
      final accounts = [
        // Revenue accounts
        Account(
          id: 'rev-sales',
          name: 'Sales Revenue',
          accountType: AccountType.income,
          commodityId: 'CNY',
        ),
        Account(
          id: 'rev-service',
          name: 'Service Revenue',
          accountType: AccountType.income,
          commodityId: 'CNY',
        ),
        // Expense accounts
        Account(
          id: 'exp-cogs',
          name: 'Cost of Goods Sold',
          accountType: AccountType.expense,
          commodityId: 'CNY',
        ),
        Account(
          id: 'exp-rent',
          name: 'Rent Expense',
          accountType: AccountType.expense,
          commodityId: 'CNY',
        ),
        Account(
          id: 'exp-utilities',
          name: 'Utilities Expense',
          accountType: AccountType.expense,
          commodityId: 'CNY',
        ),
        // Non-income/expense accounts (should be ignored)
        Account(
          id: 'asset-cash',
          name: 'Cash',
          accountType: AccountType.asset,
          commodityId: 'CNY',
        ),
        Account(
          id: 'liability-payable',
          name: 'Accounts Payable',
          accountType: AccountType.liability,
          commodityId: 'CNY',
        ),
      ];

      final balances = [
        AccountBalanceRaw(accountId: 'rev-sales', debitNum: 0, creditNum: 15000, denom: 100),
        AccountBalanceRaw(accountId: 'rev-service', debitNum: 0, creditNum: 5000, denom: 100),
        AccountBalanceRaw(accountId: 'exp-cogs', debitNum: 8000, creditNum: 0, denom: 100),
        AccountBalanceRaw(accountId: 'exp-rent', debitNum: 3000, creditNum: 0, denom: 100),
        AccountBalanceRaw(accountId: 'exp-utilities', debitNum: 1000, creditNum: 0, denom: 100),
        // Non-income/expense balances (should be ignored)
        AccountBalanceRaw(accountId: 'asset-cash', debitNum: 20000, creditNum: 0, denom: 100),
        AccountBalanceRaw(accountId: 'liability-payable', debitNum: 0, creditNum: 5000, denom: 100),
      ];

      final result = await calculator.calculate(
        accounts: accounts,
        balances: balances,
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 12, 31),
      );

      // Revenue: 15000 + 5000 = 20000
      expect(result.revenues.totalNum, equals(20000));
      expect(result.revenues.items.length, equals(2));

      // Expenses: 8000 + 3000 + 1000 = 12000
      expect(result.expenses.totalNum, equals(12000));
      expect(result.expenses.items.length, equals(3));

      // Net Income: 20000 - 12000 = 8000 (numerator)
      expect(result.netIncomeNum, equals(8000));
      expect(result.isProfit, isTrue);
    });

    test('preserves date range in result', () async {
      final startDate = DateTime(2024, 1, 1);
      final endDate = DateTime(2024, 12, 31);

      final result = await calculator.calculate(
        accounts: [],
        balances: [],
        startDate: startDate,
        endDate: endDate,
      );

      expect(result.startDate, equals(startDate));
      expect(result.endDate, equals(endDate));
    });
  });
}
