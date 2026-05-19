import 'package:core/core.dart';

/// Detects duplicate transactions during import.
///
/// Duplicate detection strategies:
/// 1. Exact match: Same external ID
/// 2. Fuzzy match: Same amount, date, and description
/// 3. Near match: Similar amount and date within tolerance
class DuplicateDetector {
  /// External IDs that have been seen.
  final Set<String> _seenExternalIds = {};

  /// Transaction signatures for fuzzy matching.
  final Set<String> _seenSignatures = {};

  /// Tolerance for amount matching (in currency units).
  final double amountTolerance;

  /// Tolerance for date matching (in days).
  final int dateToleranceDays;

  DuplicateDetector({
    this.amountTolerance = 0.01,
    this.dateToleranceDays = 1,
  });

  /// Check if a transaction is a duplicate.
  ///
  /// Returns a DuplicateResult with:
  /// - isDuplicate: Whether this is a duplicate
  /// - matchType: How the duplicate was detected
  /// - existingId: ID of the existing transaction (if known)
  DuplicateResult check(ParsedTransaction transaction) {
    // Check exact match by external ID
    if (transaction.externalId != null) {
      if (_seenExternalIds.contains(transaction.externalId)) {
        return DuplicateResult(
          isDuplicate: true,
          matchType: DuplicateMatchType.externalId,
          externalId: transaction.externalId,
        );
      }
      _seenExternalIds.add(transaction.externalId!);
    }

    // Check fuzzy match by signature
    final signature = _createSignature(transaction);
    if (_seenSignatures.contains(signature)) {
      return DuplicateResult(
        isDuplicate: true,
        matchType: DuplicateMatchType.fuzzy,
        signature: signature,
      );
    }
    _seenSignatures.add(signature);

    // Not a duplicate
    return const DuplicateResult(isDuplicate: false);
  }

  /// Check multiple transactions and return duplicate indices.
  ///
  /// Returns a set of indices that are duplicates.
  Set<int> findDuplicates(List<ParsedTransaction> transactions) {
    final duplicates = <int>{};

    for (var i = 0; i < transactions.length; i++) {
      final result = check(transactions[i]);
      if (result.isDuplicate) {
        duplicates.add(i);
      }
    }

    return duplicates;
  }

  /// Create a signature for fuzzy matching.
  String _createSignature(ParsedTransaction transaction) {
    // Normalize amount (round to 2 decimal places)
    final normalizedAmount = (transaction.amount * 100).round() / 100;

    // Normalize date (remove time component)
    final normalizedDate = DateTime(
      transaction.date.year,
      transaction.date.month,
      transaction.date.day,
    );

    // Create signature from amount, date, and description
    final description = transaction.description?.toLowerCase().trim() ?? '';
    final signature = '${normalizedAmount}_${normalizedDate.toIso8601String()}_$description';

    return signature;
  }

  /// Clear all cached data.
  void clear() {
    _seenExternalIds.clear();
    _seenSignatures.clear();
  }

  /// Add existing transactions to the detector.
  ///
  /// This is used to check against transactions already in the database.
  void addExistingTransactions(List<ParsedTransaction> transactions) {
    for (final transaction in transactions) {
      if (transaction.externalId != null) {
        _seenExternalIds.add(transaction.externalId!);
      }
      _seenSignatures.add(_createSignature(transaction));
    }
  }
}

/// Result of duplicate detection.
class DuplicateResult {
  /// Whether this is a duplicate.
  final bool isDuplicate;

  /// How the duplicate was detected.
  final DuplicateMatchType? matchType;

  /// External ID that matched.
  final String? externalId;

  /// Signature that matched.
  final String? signature;

  /// ID of the existing transaction (if known).
  final String? existingId;

  const DuplicateResult({
    required this.isDuplicate,
    this.matchType,
    this.externalId,
    this.signature,
    this.existingId,
  });
}

/// Types of duplicate matches.
enum DuplicateMatchType {
  /// Exact match by external ID.
  externalId,

  /// Fuzzy match by amount, date, and description.
  fuzzy,

  /// Near match within tolerance.
  nearMatch,
}