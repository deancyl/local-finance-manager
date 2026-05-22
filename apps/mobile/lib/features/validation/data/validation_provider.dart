import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';

// ============================================================
// VALIDATION RESULT TYPES
// ============================================================

/// Severity level for validation issues
enum ValidationSeverity {
  error,    // Blocking - cannot proceed
  warning,  // Non-blocking - user can override
  info,     // Informational
}

/// A single validation issue
class ValidationIssue {
  final String code;
  final String message;
  final ValidationSeverity severity;
  final String? field;
  final Map<String, dynamic> context;

  const ValidationIssue({
    required this.code,
    required this.message,
    required this.severity,
    this.field,
    this.context = const {},
  });

  bool get isBlocking => severity == ValidationSeverity.error;

  @override
  String toString() => '[$severity] $message';
}

/// Result of a validation operation
class ValidationResult {
  final List<ValidationIssue> issues;
  final bool isValid;

  const ValidationResult({
    required this.issues,
    required this.isValid,
  });

  factory ValidationResult.ok() => const ValidationResult(issues: [], isValid: true);

  factory ValidationResult.fromIssues(List<ValidationIssue> issues) {
    return ValidationResult(
      issues: issues,
      isValid: !issues.any((i) => i.isBlocking),
    );
  }

  List<ValidationIssue> get errors => issues.where((i) => i.severity == ValidationSeverity.error).toList();
  List<ValidationIssue> get warnings => issues.where((i) => i.severity == ValidationSeverity.warning).toList();
  List<ValidationIssue> get infos => issues.where((i) => i.severity == ValidationSeverity.info).toList();

  ValidationResult merge(ValidationResult other) {
    return ValidationResult(
      issues: [...issues, ...other.issues],
      isValid: isValid && other.isValid,
    );
  }
}

// ============================================================
// VALIDATORS - Business Rules
// ============================================================

/// Base class for all validators
abstract class Validator<T> {
  Future<ValidationResult> validate(T value, LocalFinanceDatabase db);
}

/// Validates a transaction before creation/update
class TransactionValidator extends Validator<TransactionValidationInput> {
  @override
  Future<ValidationResult> validate(
    TransactionValidationInput input,
    LocalFinanceDatabase db,
  ) async {
    final issues = <ValidationIssue>[];

    // 1. Validate description
    if (input.description == null || input.description!.trim().isEmpty) {
      issues.add(const ValidationIssue(
        code: 'TXN_EMPTY_DESCRIPTION',
        message: '交易描述不能为空',
        severity: ValidationSeverity.warning,
        field: 'description',
      ));
    } else if (input.description!.length > 500) {
      issues.add(const ValidationIssue(
        code: 'TXN_DESCRIPTION_TOO_LONG',
        message: '交易描述过长（最多500字符）',
        severity: ValidationSeverity.error,
        field: 'description',
      ));
    }

    // 2. Validate date
    if (input.postDate == null) {
      issues.add(const ValidationIssue(
        code: 'TXN_MISSING_DATE',
        message: '交易日期不能为空',
        severity: ValidationSeverity.error,
        field: 'postDate',
      ));
    } else {
      final now = DateTime.now();
      final txnDate = DateTime.fromMillisecondsSinceEpoch(input.postDate!);
      
      // Future date warning
      if (txnDate.isAfter(now)) {
        issues.add(const ValidationIssue(
          code: 'TXN_FUTURE_DATE',
          message: '交易日期在未来',
          severity: ValidationSeverity.warning,
          field: 'postDate',
        ));
      }
      
      // Very old date warning (more than 10 years)
      if (txnDate.isBefore(now.subtract(const Duration(days: 3650)))) {
        issues.add(const ValidationIssue(
          code: 'TXN_VERY_OLD_DATE',
          message: '交易日期过于久远（超过10年）',
          severity: ValidationSeverity.warning,
          field: 'postDate',
        ));
      }
    }

    // 3. Validate currency
    if (input.currencyId == null || input.currencyId!.isEmpty) {
      issues.add(const ValidationIssue(
        code: 'TXN_MISSING_CURRENCY',
        message: '必须指定币种',
        severity: ValidationSeverity.error,
        field: 'currencyId',
      ));
    } else {
      // Verify currency exists
      final currency = await db.commoditiesDao.getById(input.currencyId!);
      if (currency == null) {
        issues.add(ValidationIssue(
          code: 'TXN_INVALID_CURRENCY',
          message: '币种不存在: ${input.currencyId}',
          severity: ValidationSeverity.error,
          field: 'currencyId',
        ));
      }
    }

    return ValidationResult.fromIssues(issues);
  }
}

/// Validates splits (double-entry rules)
class SplitValidator extends Validator<List<SplitValidationInput>> {
  @override
  Future<ValidationResult> validate(
    List<SplitValidationInput> splits,
    LocalFinanceDatabase db,
  ) async {
    final issues = <ValidationIssue>[];

    // 1. Check minimum splits
    if (splits.isEmpty) {
      issues.add(const ValidationIssue(
        code: 'SPLIT_EMPTY',
        message: '交易必须至少有一个分录',
        severity: ValidationSeverity.error,
      ));
      return ValidationResult.fromIssues(issues);
    }

    // 2. Validate each split
    for (var i = 0; i < splits.length; i++) {
      final split = splits[i];

      // Account must exist
      if (split.accountId.isEmpty) {
        issues.add(ValidationIssue(
          code: 'SPLIT_MISSING_ACCOUNT',
          message: '分录 ${i + 1} 缺少账户',
          severity: ValidationSeverity.error,
          field: 'splits[$i].accountId',
        ));
      } else {
        final account = await db.accountsDao.getById(split.accountId);
        if (account == null) {
          issues.add(ValidationIssue(
            code: 'SPLIT_INVALID_ACCOUNT',
            message: '分录 ${i + 1} 的账户不存在: ${split.accountId}',
            severity: ValidationSeverity.error,
            field: 'splits[$i].accountId',
          ));
        } else {
          // Cannot post to placeholder account
          if (account.isPlaceholder) {
            issues.add(ValidationIssue(
              code: 'SPLIT_PLACEHOLDER_ACCOUNT',
              message: '不能向占位账户 "${account.name}" 记账',
              severity: ValidationSeverity.error,
              field: 'splits[$i].accountId',
            ));
          }
          
          // Cannot post to hidden account
          if (account.isHidden) {
            issues.add(ValidationIssue(
              code: 'SPLIT_HIDDEN_ACCOUNT',
              message: '不能向隐藏账户 "${account.name}" 记账',
              severity: ValidationSeverity.error,
              field: 'splits[$i].accountId',
            ));
          }
        }
      }

      // Amount validation
      if (split.valueNum == 0 && split.quantityNum == 0) {
        issues.add(ValidationIssue(
          code: 'SPLIT_ZERO_AMOUNT',
          message: '分录 ${i + 1} 金额为零',
          severity: ValidationSeverity.warning,
          field: 'splits[$i].valueNum',
        ));
      }
    }

    // 3. Check double-entry balance (sum of values should be zero)
    final totalValue = splits.fold<int>(0, (sum, s) => sum + s.valueNum);
    if (totalValue != 0) {
      final imbalance = totalValue / 100.0;
      issues.add(ValidationIssue(
        code: 'SPLIT_IMBALANCE',
        message: '借贷不平衡，差额: ${imbalance.toStringAsFixed(2)}',
        severity: ValidationSeverity.error,
        context: {'imbalance': totalValue},
      ));
    }

    return ValidationResult.fromIssues(issues);
  }
}

/// Validates account operations
class AccountValidator extends Validator<AccountValidationInput> {
  @override
  Future<ValidationResult> validate(
    AccountValidationInput input,
    LocalFinanceDatabase db,
  ) async {
    final issues = <ValidationIssue>[];

    // 1. Name validation
    if (input.name == null || input.name!.trim().isEmpty) {
      issues.add(const ValidationIssue(
        code: 'ACC_EMPTY_NAME',
        message: '账户名称不能为空',
        severity: ValidationSeverity.error,
        field: 'name',
      ));
    } else if (input.name!.length > 100) {
      issues.add(const ValidationIssue(
        code: 'ACC_NAME_TOO_LONG',
        message: '账户名称过长（最多100字符）',
        severity: ValidationSeverity.error,
        field: 'name',
      ));
    }

    // 2. Account type validation
    final validTypes = {'ASSET', 'LIABILITY', 'EQUITY', 'INCOME', 'EXPENSE'};
    if (input.accountType == null || !validTypes.contains(input.accountType)) {
      issues.add(ValidationIssue(
        code: 'ACC_INVALID_TYPE',
        message: '无效的账户类型: ${input.accountType}',
        severity: ValidationSeverity.error,
        field: 'accountType',
      ));
    }

    // 3. Currency validation
    if (input.commodityId == null || input.commodityId!.isEmpty) {
      issues.add(const ValidationIssue(
        code: 'ACC_MISSING_CURRENCY',
        message: '必须指定币种',
        severity: ValidationSeverity.error,
        field: 'commodityId',
      ));
    } else {
      final currency = await db.commoditiesDao.getById(input.commodityId!);
      if (currency == null) {
        issues.add(ValidationIssue(
          code: 'ACC_INVALID_CURRENCY',
          message: '币种不存在: ${input.commodityId}',
          severity: ValidationSeverity.error,
          field: 'commodityId',
        ));
      }
    }

    // 4. Parent account validation
    if (input.parentId != null) {
      final parent = await db.accountsDao.getById(input.parentId!);
      if (parent == null) {
        issues.add(ValidationIssue(
          code: 'ACC_INVALID_PARENT',
          message: '父账户不存在: ${input.parentId}',
          severity: ValidationSeverity.error,
          field: 'parentId',
        ));
      } else {
        // Parent must be same type
        if (parent.accountType != input.accountType) {
          issues.add(ValidationIssue(
            code: 'ACC_PARENT_TYPE_MISMATCH',
            message: '父账户类型不匹配（应为 ${input.accountType}）',
            severity: ValidationSeverity.error,
            field: 'parentId',
          ));
        }
        
        // Parent must not be a child of this account (circular reference)
        if (input.id != null) {
          final wouldCreateCycle = await _wouldCreateCycle(db, input.id!, input.parentId!);
          if (wouldCreateCycle) {
            issues.add(const ValidationIssue(
              code: 'ACC_CIRCULAR_REFERENCE',
              message: '不能创建循环引用',
              severity: ValidationSeverity.error,
              field: 'parentId',
            ));
          }
        }
      }
    }

    // 5. Cannot make account its own parent
    if (input.parentId == input.id) {
      issues.add(const ValidationIssue(
        code: 'ACC_SELF_PARENT',
        message: '账户不能是自己的父账户',
        severity: ValidationSeverity.error,
        field: 'parentId',
      ));
    }

    return ValidationResult.fromIssues(issues);
  }

  Future<bool> _wouldCreateCycle(
    LocalFinanceDatabase db,
    String accountId,
    String newParentId,
  ) async {
    String? currentId = newParentId;
    final visited = <String>{};

    while (currentId != null) {
      if (visited.contains(currentId)) return true;
      visited.add(currentId);

      if (currentId == accountId) return true;

      final parent = await db.accountsDao.getById(currentId);
      currentId = parent?.parentId;
    }

    return false;
  }
}

/// Validates budget operations
class BudgetValidator extends Validator<BudgetValidationInput> {
  @override
  Future<ValidationResult> validate(
    BudgetValidationInput input,
    LocalFinanceDatabase db,
  ) async {
    final issues = <ValidationIssue>[];

    // 1. Name validation
    if (input.name == null || input.name!.trim().isEmpty) {
      issues.add(const ValidationIssue(
        code: 'BUD_EMPTY_NAME',
        message: '预算名称不能为空',
        severity: ValidationSeverity.error,
        field: 'name',
      ));
    }

    // 2. Amount validation
    if (input.amountNum == null || input.amountNum! <= 0) {
      issues.add(const ValidationIssue(
        code: 'BUD_INVALID_AMOUNT',
        message: '预算金额必须大于零',
        severity: ValidationSeverity.error,
        field: 'amountNum',
      ));
    }

    // 3. Period validation
    final validPeriods = {'MONTHLY', 'YEARLY', 'CUSTOM'};
    if (input.period == null || !validPeriods.contains(input.period)) {
      issues.add(ValidationIssue(
        code: 'BUD_INVALID_PERIOD',
        message: '无效的预算周期: ${input.period}',
        severity: ValidationSeverity.error,
        field: 'period',
      ));
    }

    // 4. Category validation
    if (input.categoryId != null) {
      final category = await (db.select(db.categories)
        ..where((c) => c.id.equals(input.categoryId!))).getSingleOrNull();
      
      if (category == null) {
        issues.add(ValidationIssue(
          code: 'BUD_INVALID_CATEGORY',
          message: '分类不存在: ${input.categoryId}',
          severity: ValidationSeverity.error,
          field: 'categoryId',
        ));
      }
    }

    // 5. Date validation for CUSTOM period
    if (input.period == 'CUSTOM') {
      if (input.startDate == null || input.endDate == null) {
        issues.add(const ValidationIssue(
          code: 'BUD_CUSTOM_DATES_REQUIRED',
          message: '自定义周期必须指定开始和结束日期',
          severity: ValidationSeverity.error,
          field: 'startDate',
        ));
      } else if (input.endDate! <= input.startDate!) {
        issues.add(const ValidationIssue(
          code: 'BUD_INVALID_DATE_RANGE',
          message: '结束日期必须晚于开始日期',
          severity: ValidationSeverity.error,
          field: 'endDate',
        ));
      }
    }

    return ValidationResult.fromIssues(issues);
  }
}

// ============================================================
// INPUT TYPES
// ============================================================

class TransactionValidationInput {
  final String? id;
  final String? description;
  final int? postDate;
  final String? currencyId;
  final String? notes;

  const TransactionValidationInput({
    this.id,
    this.description,
    this.postDate,
    this.currencyId,
    this.notes,
  });
}

class SplitValidationInput {
  final String accountId;
  final int valueNum;
  final int valueDenom;
  final int quantityNum;
  final int quantityDenom;
  final String? categoryId;

  const SplitValidationInput({
    required this.accountId,
    required this.valueNum,
    this.valueDenom = 100,
    required this.quantityNum,
    this.quantityDenom = 100,
    this.categoryId,
  });
}

class AccountValidationInput {
  final String? id;
  final String? name;
  final String? accountType;
  final String? commodityId;
  final String? parentId;
  final bool isPlaceholder;

  const AccountValidationInput({
    this.id,
    this.name,
    this.accountType,
    this.commodityId,
    this.parentId,
    this.isPlaceholder = false,
  });
}

class BudgetValidationInput {
  final String? name;
  final int? amountNum;
  final int? amountDenom;
  final String? period;
  final String? categoryId;
  final int? startDate;
  final int? endDate;

  const BudgetValidationInput({
    this.name,
    this.amountNum,
    this.amountDenom,
    this.period,
    this.categoryId,
    this.startDate,
    this.endDate,
  });
}

// ============================================================
// PROVIDERS
// ============================================================

/// Provider for transaction validator
final transactionValidatorProvider = Provider<TransactionValidator>((ref) {
  return TransactionValidator();
});

/// Provider for split validator
final splitValidatorProvider = Provider<SplitValidator>((ref) {
  return SplitValidator();
});

/// Provider for account validator
final accountValidatorProvider = Provider<AccountValidator>((ref) {
  return AccountValidator();
});

/// Provider for budget validator
final budgetValidatorProvider = Provider<BudgetValidator>((ref) {
  return BudgetValidator();
});

/// Service for running all validations
class ValidationService {
  final LocalFinanceDatabase _db;
  final TransactionValidator _transactionValidator;
  final SplitValidator _splitValidator;
  final AccountValidator _accountValidator;
  final BudgetValidator _budgetValidator;

  ValidationService(
    this._db,
    this._transactionValidator,
    this._splitValidator,
    this._accountValidator,
    this._budgetValidator,
  );

  Future<ValidationResult> validateTransaction({
    required TransactionValidationInput transaction,
    required List<SplitValidationInput> splits,
  }) async {
    final txnResult = await _transactionValidator.validate(transaction, _db);
    final splitResult = await _splitValidator.validate(splits, _db);
    return txnResult.merge(splitResult);
  }

  Future<ValidationResult> validateAccount(AccountValidationInput account) async {
    return _accountValidator.validate(account, _db);
  }

  Future<ValidationResult> validateBudget(BudgetValidationInput budget) async {
    return _budgetValidator.validate(budget, _db);
  }
}

final validationServiceProvider = Provider<ValidationService>((ref) {
  final db = ref.watch(databaseProvider);
  final txnValidator = ref.watch(transactionValidatorProvider);
  final splitValidator = ref.watch(splitValidatorProvider);
  final accountValidator = ref.watch(accountValidatorProvider);
  final budgetValidator = ref.watch(budgetValidatorProvider);
  
  return ValidationService(
    db,
    txnValidator,
    splitValidator,
    accountValidator,
    budgetValidator,
  );
});
