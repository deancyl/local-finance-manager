import 'package:drift/drift.dart';
import 'accounts.dart';
import 'commodities.dart';

/// Investment holdings table - tracks securities/shares owned.
/// 
/// Each holding represents a position in a security (stock, fund, etc.)
/// within an investment account. Tracks quantity, average cost basis,
/// and current market price for performance calculations.
class InvestmentHoldings extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get symbol => text().withLength(min: 1, max: 20)();
  TextColumn get securityName => text().nullable()();
  TextColumn get securityType => text().withLength(min: 1, max: 20).withDefault(const Constant('stock'))();
  TextColumn get currencyId => text().references(Commodities, #id)();
  IntColumn get quantityNum => integer()();
  IntColumn get quantityDenom => integer().withDefault(const Constant(10000))();
  IntColumn get averageCostNum => integer()();
  IntColumn get averageCostDenom => integer().withDefault(const Constant(100))();
  IntColumn get currentPriceNum => integer().nullable()();
  IntColumn get currentPriceDenom => integer().nullable()();
  IntColumn get lastPriceUpdate => integer().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Security types for investment holdings.
enum SecurityType {
  stock('stock', '股票'),
  fund('fund', '基金'),
  bond('bond', '债券'),
  etf('etf', 'ETF'),
  other('other', '其他');

  final String code;
  final String labelZh;

  const SecurityType(this.code, this.labelZh);
}
