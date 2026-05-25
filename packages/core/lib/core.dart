/// Core package for the finance application.
///
/// This package contains:
/// - Domain models (Account, Transaction, Category, etc.)
/// - Repository interfaces
/// - Business logic use cases
library core;

export 'models.dart';
export 'src/repositories/account_repository.dart';
export 'src/repositories/transaction_repository.dart';
export 'src/repositories/category_repository.dart';
export 'src/repositories/budget_repository.dart';
export 'src/data/repositories/account_repository_impl.dart';
export 'src/usecases/add_transaction.dart';
export 'src/usecases/get_balance.dart' hide AccountBalance;
export 'src/usecases/import_transactions.dart';
export 'src/usecases/journal_entry_validator.dart';
export 'src/usecases/trial_balance_calculator.dart';
export 'src/usecases/balance_sheet_calculator.dart';
export 'src/usecases/income_statement_calculator.dart';
export 'src/usecases/cash_flow_calculator.dart';
export 'src/usecases/general_ledger_calculator.dart';
export 'src/usecases/reconciliation_service.dart';
export 'src/usecases/closing_entry_service.dart';
export 'src/usecases/recurring_processor.dart';
export 'src/utils/budget_period_calculator.dart';
export 'src/validation/validation_service.dart';