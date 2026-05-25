import 'package:drift/drift.dart';
import 'accounts.dart';
import 'commodities.dart';
import 'investment_holdings.dart';

/// Investment transactions table - records buy/sell/dividend operations.
/// 
/// Tracks all investment-related transactions including:
/// - Buy: Purchase of securities
/// - Sell: Sale of securities
/// - Dividend: Dividend income
/// - Split: Stock splits
/// - Transfer: Transfer between accounts
class InvestmentTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get holdingId => text().nullable().references(InvestmentHoldings, #id)();
  TextColumn get transactionType => text().withLength(min: 1, max: 20)();
  IntColumn get transactionDate => integer()();
  TextColumn get symbol => text().withLength(min: 1, max: 20)();
  TextColumn get securityName => text().nullable()();
  IntColumn get quantityNum => integer().nullable()();
  IntColumn get quantityDenom => integer().nullable().withDefault(const Constant(10000))();
  IntColumn get priceNum => integer().nullable()();
  IntColumn get priceDenom => integer().nullable().withDefault(const Constant(100))();
  IntColumn get amountNum => integer()();
  IntColumn get amountDenom => integer().withDefault(const Constant(100))();
  IntColumn get feeNum => integer().withDefault(const Constant(0))();
  IntColumn get feeDenom => integer().withDefault(const Constant(100))();
  IntColumn get taxNum => integer().withDefault(const Constant(0))();
  IntColumn get taxDenom => integer().withDefault(const Constant(100))();
  TextColumn get currencyId => text().references(Commodities, #id)();
  TextColumn get notes => text().nullable()();
  TextColumn get referenceNum => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Investment transaction types.
enum InvestmentTransactionType {
  buy('buy', '买入'),
  sell('sell', '卖出'),
  dividend('dividend', '股息'),
  dividendReinvest('dividend_reinvest', '股息再投资'),
  split('split', '拆股'),
  transferIn('transfer_in', '转入'),
  transferOut('transfer_out', '转出'),
  fee('fee', '费用'),
  other('other', '其他');

  final String code;
  final String labelZh;

  const InvestmentTransactionType(this.code, this.labelZh);
}
