import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../transactions/data/transaction_filter.dart';
import '../../../../core/router/app_router.dart' show DrillDownArgs;

/// Mixin that provides drill-down navigation from reports to transactions.
///
/// Allows users to tap on account balances in reports to see the
/// underlying transactions for that account within a specified date range.
mixin DrillDownMixin {
  /// Navigate to transactions page filtered by account.
  ///
  /// Parameters:
  /// - [accountId]: The account ID to filter transactions by
  /// - [accountName]: The account name to display in the app bar subtitle
  /// - [startDate]: Optional start date for the filter range
  /// - [endDate]: Optional end date for the filter range
  ///
  /// Shows a snackbar with the account name before navigating.
  void navigateToTransactions(
    BuildContext context, {
    required String accountId,
    required String accountName,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    // Show snackbar with account name
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('查看账户: $accountName'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Create filter with account and date range
    final filter = TransactionFilter(
      accountId: accountId,
      startDate: startDate,
      endDate: endDate,
    );

    // Navigate to transactions page with filter and account name
    context.push('/transactions', extra: DrillDownArgs(
      filter: filter,
      accountName: accountName,
    ));
  }
}

/// Extension on BuildContext for drill-down navigation without mixin.
///
/// Useful when you need drill-down functionality but can't use the mixin.
extension DrillDownNavigation on BuildContext {
  /// Navigate to transactions page filtered by account.
  ///
  /// Parameters:
  /// - [accountId]: The account ID to filter transactions by
  /// - [accountName]: The account name to display in the app bar subtitle
  /// - [startDate]: Optional start date for the filter range
  /// - [endDate]: Optional end date for the filter range
  void drillDownToTransactions({
    required String accountId,
    required String accountName,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    // Show snackbar with account name
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text('查看账户: $accountName'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Create filter with account and date range
    final filter = TransactionFilter(
      accountId: accountId,
      startDate: startDate,
      endDate: endDate,
    );

    // Navigate to transactions page with filter and account name
    push('/transactions', extra: DrillDownArgs(
      filter: filter,
      accountName: accountName,
    ));
  }
}