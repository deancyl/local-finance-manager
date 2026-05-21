import 'package:flutter/material.dart';
import 'package:database/database.dart';

/// Widget that displays running totals and validation status for journal entries.
///
/// Shows:
/// - Total debits
/// - Total credits
/// - Difference (imbalance amount)
/// - Color-coded status (green = balanced, red = unbalanced)
class BalanceIndicatorWidget extends StatelessWidget {
  /// List of splits to calculate balance for.
  final List<Split> splits;

  const BalanceIndicatorWidget({
    super.key,
    required this.splits,
  });

  /// Calculate total debits (negative values).
  double _calculateTotalDebits() {
    return splits
        .where((s) => s.valueNum < 0)
        .fold(0.0, (sum, s) => sum + (s.valueNum / s.valueDenom).abs());
  }

  /// Calculate total credits (positive values).
  double _calculateTotalCredits() {
    return splits
        .where((s) => s.valueNum > 0)
        .fold(0.0, (sum, s) => sum + (s.valueNum / s.valueDenom).abs());
  }

  /// Calculate the balance (difference between debits and credits).
  /// Returns 0 if balanced, non-zero if unbalanced.
  double _calculateBalance() {
    return splits.fold(0.0, (sum, s) => sum + (s.valueNum / s.valueDenom));
  }

  /// Check if the entry is balanced.
  bool _isBalanced() {
    if (splits.length < 2) return false;
    final balance = _calculateBalance();
    return balance.abs() < 0.001; // Use tolerance for floating point comparison
  }

  @override
  Widget build(BuildContext context) {
    final totalDebits = _calculateTotalDebits();
    final totalCredits = _calculateTotalCredits();
    final difference = _calculateBalance().abs();
    final isBalanced = _isBalanced();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isBalanced
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBalanced ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status indicator
          Row(
            children: [
              Icon(
                isBalanced ? Icons.check_circle : Icons.error,
                color: isBalanced ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isBalanced ? '已平衡' : '未平衡',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isBalanced ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Totals row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Debits column
              _buildAmountColumn(
                label: '借方总额',
                amount: totalDebits,
                color: Colors.red.shade700,
              ),
              // Credits column
              _buildAmountColumn(
                label: '贷方总额',
                amount: totalCredits,
                color: Colors.green.shade700,
              ),
              // Difference column
              _buildAmountColumn(
                label: '差额',
                amount: difference,
                color: isBalanced ? Colors.green : Colors.red,
                highlight: !isBalanced,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountColumn({
    required String label,
    required double amount,
    required Color color,
    bool highlight = false,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '¥${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
