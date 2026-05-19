import '../models/transaction.dart';
import '../models/split.dart';
import '../models/import_batch.dart';
import '../models/import_source.dart';
import '../repositories/transaction_repository.dart';

/// Use case for importing transactions from external sources.
class ImportTransactions {
  final TransactionRepository _transactionRepository;

  ImportTransactions(this._transactionRepository);

  /// Imports transactions from parsed data.
  ///
  /// Returns the import batch with statistics.
  Future<ImportBatch> import({
    required String sourceId,
    required List<ParsedTransaction> transactions,
    String? filename,
    bool skipDuplicates = true,
  }) async {
    final batch = ImportBatch(
      sourceId: sourceId,
      filename: filename,
      recordCount: transactions.length,
    );

    int successCount = 0;
    int duplicateCount = 0;
    int errorCount = 0;
    final errors = <String>[];

    for (final parsed in transactions) {
      try {
        // Check for duplicates
        if (skipDuplicates && parsed.externalId != null) {
          final exists = await _transactionRepository.existsByExternalId(
            parsed.externalId!,
          );
          if (exists) {
            duplicateCount++;
            continue;
          }
        }

        // Create the transaction
        final transaction = Transaction(
          postDate: parsed.date,
          commodityId: parsed.currencyId,
          description: parsed.description,
          notes: parsed.notes,
          externalId: parsed.externalId,
          importBatchId: batch.id,
        );

        final split = Split.fromValue(
          transactionId: transaction.id,
          accountId: parsed.accountId,
          value: parsed.amount,
          memo: parsed.memo,
          fraction: 100,
        );

        await _transactionRepository.create(transaction, [split]);
        successCount++;
      } catch (e) {
        errorCount++;
        errors.add('Row ${transactions.indexOf(parsed) + 1}: ${e.toString()}');
      }
    }

    return batch.copyWith(
      successCount: successCount,
      duplicateCount: duplicateCount,
      errorCount: errorCount,
      status: errorCount == 0
          ? ImportBatchStatus.success
          : successCount > 0
              ? ImportBatchStatus.partial
              : ImportBatchStatus.failed,
      errorDetails: errors.isNotEmpty ? errors.join('\n') : null,
    );
  }

  /// Validates parsed transactions before import.
  ///
  /// Returns a list of validation errors, or empty list if valid.
  List<String> validate(List<ParsedTransaction> transactions) {
    final errors = <String>[];

    for (var i = 0; i < transactions.length; i++) {
      final parsed = transactions[i];
      final rowNum = i + 1;

      if (parsed.accountId.isEmpty) {
        errors.add('Row $rowNum: Missing account ID');
      }

      if (parsed.amount == 0) {
        errors.add('Row $rowNum: Amount cannot be zero');
      }

      if (parsed.currencyId.isEmpty) {
        errors.add('Row $rowNum: Missing currency');
      }
    }

    return errors;
  }
}

/// Represents a parsed transaction from an external source.
class ParsedTransaction {
  final String accountId;
  final double amount;
  final DateTime date;
  final String currencyId;
  final String? description;
  final String? notes;
  final String? memo;
  final String? externalId;
  final String? category;
  final String? payee;

  ParsedTransaction({
    required this.accountId,
    required this.amount,
    required this.date,
    required this.currencyId,
    this.description,
    this.notes,
    this.memo,
    this.externalId,
    this.category,
    this.payee,
  });
}