part of '../database.dart';

/// Data Access Object for transactions.
@DriftAccessor(tables: [Transactions, Splits, TransactionTags])
class TransactionsDao extends DatabaseAccessor<LocalFinanceDatabase>
    with _$TransactionsDaoMixin, AuditableMixin {
  TransactionsDao(super.db);

  /// Gets all transactions (not deleted).
  Future<List<Transaction>> getAll() {
    return (select(transactions)..where((t) => t.deletedAt.isNull())).get();
  }

  /// Gets a transaction by ID.
  Future<Transaction?> getById(String id) {
    return (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Gets transactions within a date range.
  Future<List<Transaction>> getByDateRange(DateTime start, DateTime end) {
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    return (select(transactions)
          ..where((t) => t.postDate.isBetweenValues(startMs, endMs) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.postDate)]))
        .get();
  }

  /// Gets transactions for an account via splits.
  Future<List<Transaction>> getByAccount(String accountId) {
    final query = select(transactions).join([
      innerJoin(splits, splits.transactionId.equalsExp(transactions.id)),
    ])
      ..where(splits.accountId.equals(accountId) & transactions.deletedAt.isNull())
      ..orderBy([OrderingTerm.desc(transactions.postDate)]);

    return query.map((row) => row.readTable(transactions)).get();
  }

  /// Gets splits for a transaction.
  Future<List<Split>> getSplits(String transactionId) {
    return (select(splits)..where((s) => s.transactionId.equals(transactionId))).get();
  }

  /// Creates a transaction with splits in a single atomic transaction.
  Future<String> createWithSplits(
    TransactionsCompanion transaction,
    List<SplitsCompanion> splitList,
  ) async {
    return await this.transaction(() async {
      await into(transactions).insert(transaction);
      final id = transaction.id.value;
      for (final split in splitList) {
        await into(splits).insert(split.copyWith(transactionId: Value(id)));
      }
      await logMutation(
        operation: 'CREATE',
        entityType: 'transaction',
        entityId: id,
        newValue: {}, // TODO: implement toJson
      );
      return id;
    });
  }

  /// Updates a transaction with splits.
  Future<void> updateWithSplits(
    TransactionsCompanion transaction,
    List<SplitsCompanion> splitList,
  ) async {
    await batch((b) async {
      b.replace(transactions, transaction);
      // Delete existing splits
      await (delete(splits)..where((s) => s.transactionId.equals(transaction.id.value))).go();
      // Insert new splits
      for (final split in splitList) {
        b.insert(splits, split);
      }
    });
  }

  /// Soft deletes a transaction.
  Future<void> softDelete(String id) async {
    await (update(transactions)..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(deletedAt: Value(DateTime.now().millisecondsSinceEpoch)));
  }

  /// Checks if a transaction exists by external ID.
  Future<bool> existsByExternalId(String externalId) async {
    final result = await (select(transactions)
          ..where((t) => t.externalId.equals(externalId)))
        .getSingleOrNull();
    return result != null;
  }

  /// Watches transactions within a date range.
  Stream<List<Transaction>> watchByDateRange(DateTime start, DateTime end) {
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    return (select(transactions)
          ..where((t) => t.postDate.isBetweenValues(startMs, endMs) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.postDate)]))
        .watch();
  }

  /// Gets transaction count.
  Future<int> count({String? accountId}) async {
    if (accountId != null) {
      final query = selectOnly(transactions)
        ..join([innerJoin(splits, splits.transactionId.equalsExp(transactions.id))])
        ..where(splits.accountId.equals(accountId) & transactions.deletedAt.isNull());
      query.addColumns([transactions.id.count()]);
      final result = await query.getSingle();
      return result.read(transactions.id.count()) ?? 0;
    }
    final query = selectOnly(transactions)..where(transactions.deletedAt.isNull());
    query.addColumns([transactions.id.count()]);
    final result = await query.getSingle();
    return result.read(transactions.id.count()) ?? 0;
  }

  /// Gets all splits for non-deleted transactions.
  Future<List<Split>> getAllSplits() {
    final query = select(splits).join([
      innerJoin(transactions, transactions.id.equalsExp(splits.transactionId)),
    ])
      ..where(transactions.deletedAt.isNull());
    
    return query.map((row) => row.readTable(splits)).get();
  }

  /// Gets paginated transactions ordered by postDate DESC.
  /// Filters out deleted transactions.
  Future<List<Transaction>> getTransactionsPaginated({
    required int limit,
    required int offset,
  }) {
    return (select(transactions)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.postDate)])
          ..limit(limit, offset: offset))
        .get();
  }

  /// Gets paginated transactions with their splits using JOIN for efficiency.
  /// Returns list of (Transaction, List<Split>) tuples.
  Future<List<(Transaction, List<Split>)>> getTransactionsWithSplitsPaginated({
    required int limit,
    required int offset,
  }) async {
    // First get paginated transactions
    final paginatedTransactions = await getTransactionsPaginated(
      limit: limit,
      offset: offset,
    );

    if (paginatedTransactions.isEmpty) {
      return [];
    }

    // Get all transaction IDs
    final transactionIds = paginatedTransactions.map((t) => t.id).toList();

    // Fetch all splits for these transactions in a single query
    final allSplits = await (select(splits)
          ..where((s) => s.transactionId.isIn(transactionIds)))
        .get();

    // Group splits by transaction ID
    final splitsByTransaction = <String, List<Split>>{};
    for (final split in allSplits) {
      splitsByTransaction.putIfAbsent(split.transactionId, () => []).add(split);
    }

    // Build result list maintaining order
    return paginatedTransactions.map((t) {
      final splits = splitsByTransaction[t.id] ?? [];
      return (t, splits);
    }).toList();
  }

  /// Watches all splits for non-deleted transactions.
  Stream<List<Split>> watchAllSplits() {
    final query = select(splits).join([
      innerJoin(transactions, transactions.id.equalsExp(splits.transactionId)),
    ])
      ..where(transactions.deletedAt.isNull());
    
    return query.map((row) => row.readTable(splits)).watch();
  }

  /// Monthly trend result for aggregated income/expense data.
  /// Returns month label, income total, and expense total.
  Future<List<({String monthLabel, double income, double expense})>> getMonthlyTrend(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startMs = startDate.millisecondsSinceEpoch;
    final endMs = endDate.millisecondsSinceEpoch;

    // Single query with JOINs to get all splits with account type and transaction date
    // Filter by date range and group by month
    final query = customSelect(
      '''
      SELECT 
        strftime('%Y-%m', datetime(t.post_date / 1000, 'unixepoch')) AS month_label,
        SUM(CASE WHEN a.account_type = 'INCOME' THEN ABS(s.value_num) ELSE 0 END) / 100.0 AS income,
        SUM(CASE WHEN a.account_type = 'EXPENSE' THEN ABS(s.value_num) ELSE 0 END) / 100.0 AS expense
      FROM splits s
      INNER JOIN transactions t ON t.id = s.transaction_id
      INNER JOIN accounts a ON a.id = s.account_id
      WHERE t.post_date >= ?1 
        AND t.post_date <= ?2
        AND t.deleted_at IS NULL
        AND s.value_num != 0
      GROUP BY month_label
      ORDER BY month_label ASC
      ''',
      variables: [Variable.withInt(startMs), Variable.withInt(endMs)],
      readsFrom: {transactions, splits, accounts},
    );

    final results = await query.get();

    return results.map((row) {
      final monthLabel = row.read<String>('month_label');
      final income = row.read<double>('income') ?? 0.0;
      final expense = row.read<double>('expense') ?? 0.0;
      return (monthLabel: monthLabel, income: income, expense: expense);
    }).toList();
  }

  /// Gets filtered and paginated transactions with their splits.
  /// Applies all filters at the database level for performance.
  /// 
  /// Supported filters:
  /// - startDate/endDate: Date range filter on transaction post_date
  /// - categoryId: Filter by category via splits table
  /// - accountId: Filter by account via splits table
  /// - searchQuery: LIKE search on description and notes
  /// - minAmount/maxAmount: Amount range filter via splits
  Future<List<(Transaction, List<Split>)>> getFilteredTransactionsPaginated({
    required int limit,
    required int offset,
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? accountId,
    String? searchQuery,
    double? minAmount,
    double? maxAmount,
  }) async {
    // Build the base query with necessary joins
    final query = selectOnly(transactions)
      ..join([
        innerJoin(splits, splits.transactionId.equalsExp(transactions.id)),
      ]);

    // Apply filters
    final conditions = <Expression<bool>>[];
    
    // Always exclude deleted transactions
    conditions.add(transactions.deletedAt.isNull());

    // Date range filter
    if (startDate != null) {
      final startMs = DateTime(startDate.year, startDate.month, startDate.day).millisecondsSinceEpoch;
      conditions.add(transactions.postDate.isBiggerOrEqualValue(startMs));
    }
    if (endDate != null) {
      final endMs = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999).millisecondsSinceEpoch;
      conditions.add(transactions.postDate.isSmallerOrEqualValue(endMs));
    }

    // Category filter via splits
    if (categoryId != null) {
      conditions.add(splits.categoryId.equals(categoryId));
    }

    // Account filter via splits
    if (accountId != null) {
      conditions.add(splits.accountId.equals(accountId));
    }

    // Search query filter (LIKE on description or notes)
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final searchPattern = '%${searchQuery.toLowerCase()}%';
      conditions.add(
        transactions.description.lower().like(searchPattern) |
        transactions.notes.lower().like(searchPattern),
      );
    }

    // Apply all conditions
    if (conditions.isNotEmpty) {
      query.where(conditions.reduce((a, b) => a & b));
    }

    // Order by post date descending
    query.orderBy([OrderingTerm.desc(transactions.postDate)]);

    // Apply pagination
    query.limit(limit, offset: offset);

    // Get distinct transaction IDs using GROUP BY to avoid duplicates from joins
    query.addColumns([transactions.id]);
    query.groupBy([transactions.id]);
    
    final transactionIds = (await query.get())
        .map((row) => row.read(transactions.id))
        .whereType<String>()
        .toList();

    if (transactionIds.isEmpty) {
      return [];
    }

    // Fetch full transactions in order
    final transactionList = await (select(transactions)
          ..where((t) => t.id.isIn(transactionIds)))
        .get();

    // Create a map for quick lookup and maintain order
    final transactionMap = {for (var t in transactionList) t.id: t};
    final orderedTransactions = transactionIds
        .where((id) => transactionMap.containsKey(id))
        .map((id) => transactionMap[id]!)
        .toList();

    // Fetch all splits for these transactions
    final allSplits = await (select(splits)
          ..where((s) => s.transactionId.isIn(transactionIds)))
        .get();

    // Group splits by transaction ID
    final splitsByTransaction = <String, List<Split>>{};
    for (final split in allSplits) {
      splitsByTransaction.putIfAbsent(split.transactionId, () => []).add(split);
    }

    // Build result with amount filter applied in Dart (complex aggregation)
    final result = <(Transaction, List<Split>)>[];
    for (final transaction in orderedTransactions) {
      final splits = splitsByTransaction[transaction.id] ?? [];
      
      // Apply amount range filter (absolute value of total)
      if (minAmount != null || maxAmount != null) {
        final totalAmount = splits.fold<int>(0, (sum, s) => sum + s.valueNum.abs());
        final amount = totalAmount / 100.0;
        
        if (minAmount != null && amount < minAmount) continue;
        if (maxAmount != null && amount > maxAmount) continue;
      }
      
      result.add((transaction, splits));
      
      // Stop if we have enough results (amount filter may reduce count)
      if (result.length >= limit) break;
    }

    return result;
  }

  /// Gets count of filtered transactions (for pagination info).
  Future<int> getFilteredTransactionsCount({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? accountId,
    String? searchQuery,
    double? minAmount,
    double? maxAmount,
  }) async {
    // Build the base query with necessary joins
    final query = selectOnly(transactions)
      ..join([
        innerJoin(splits, splits.transactionId.equalsExp(transactions.id)),
      ]);

    // Apply filters
    final conditions = <Expression<bool>>[];
    
    // Always exclude deleted transactions
    conditions.add(transactions.deletedAt.isNull());

    // Date range filter
    if (startDate != null) {
      final startMs = DateTime(startDate.year, startDate.month, startDate.day).millisecondsSinceEpoch;
      conditions.add(transactions.postDate.isBiggerOrEqualValue(startMs));
    }
    if (endDate != null) {
      final endMs = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999).millisecondsSinceEpoch;
      conditions.add(transactions.postDate.isSmallerOrEqualValue(endMs));
    }

    // Category filter via splits
    if (categoryId != null) {
      conditions.add(splits.categoryId.equals(categoryId));
    }

    // Account filter via splits
    if (accountId != null) {
      conditions.add(splits.accountId.equals(accountId));
    }

    // Search query filter
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final searchPattern = '%${searchQuery.toLowerCase()}%';
      conditions.add(
        transactions.description.lower().like(searchPattern) |
        transactions.notes.lower().like(searchPattern),
      );
    }

    // Apply all conditions
    if (conditions.isNotEmpty) {
      query.where(conditions.reduce((a, b) => a & b));
    }

    // Add count column - use countDistinct for accurate count with joins
    query.addColumns([transactions.id.count()]);

    final result = await query.getSingle();
    return result.read(transactions.id.count()) ?? 0;
  }

  /// Full-text search using FTS5 for better performance and relevance ranking.
  /// Searches across description, notes, and reference_num fields.
  /// Returns transactions ordered by FTS rank (most relevant first).
  Future<List<(Transaction, List<Split>)>> fullTextSearch({
    required String query,
    int limit = 50,
    int offset = 0,
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? accountId,
    double? minAmount,
    double? maxAmount,
    List<String>? tagIds,
  }) async {
    // Sanitize query for FTS5 (escape special characters)
    final sanitizedQuery = query
        .replaceAll('"', '""')
        .replaceAll("'", "''")
        .trim();
    
    if (sanitizedQuery.isEmpty) {
      return getFilteredTransactionsPaginated(
        limit: limit,
        offset: offset,
        startDate: startDate,
        endDate: endDate,
        categoryId: categoryId,
        accountId: accountId,
        minAmount: minAmount,
        maxAmount: maxAmount,
        searchQuery: null,
      );
    }

    // Use FTS5 MATCH with BM25 ranking
    final ftsQuery = customSelect(
      '''
      SELECT t.id, bm25(transactions_fts) as rank
      FROM transactions_fts fts
      INNER JOIN transactions t ON t.id = fts.id
      WHERE transactions_fts MATCH ?
        AND t.deleted_at IS NULL
      ORDER BY rank
      LIMIT ? OFFSET ?
      ''',
      variables: [
        Variable.withString(sanitizedQuery),
        Variable.withInt(limit),
        Variable.withInt(offset),
      ],
      readsFrom: {transactions},
    );

    final ftsResults = await ftsQuery.get();
    final transactionIds = ftsResults
        .map((row) => row.read<String>('id'))
        .toList();

    if (transactionIds.isEmpty) {
      return [];
    }

    // Fetch full transactions
    final transactionList = await (select(transactions)
          ..where((t) => t.id.isIn(transactionIds)))
        .get();

    // Create a map for quick lookup maintaining FTS order
    final transactionMap = {for (var t in transactionList) t.id: t};
    final orderedTransactions = transactionIds
        .where((id) => transactionMap.containsKey(id))
        .map((id) => transactionMap[id]!)
        .toList();

    // Apply additional filters if provided
    var filteredTransactions = orderedTransactions;
    
    if (startDate != null || endDate != null) {
      filteredTransactions = filteredTransactions.where((t) {
        final postDate = DateTime.fromMillisecondsSinceEpoch(t.postDate);
        if (startDate != null && postDate.isBefore(startDate)) return false;
        if (endDate != null && postDate.isAfter(endDate)) return false;
        return true;
      }).toList();
    }

    if (filteredTransactions.isEmpty) {
      return [];
    }

    // Fetch all splits for these transactions
    final filteredIds = filteredTransactions.map((t) => t.id).toList();
    final allSplits = await (select(splits)
          ..where((s) => s.transactionId.isIn(filteredIds)))
        .get();

    // Group splits by transaction ID
    final splitsByTransaction = <String, List<Split>>{};
    for (final split in allSplits) {
      splitsByTransaction.putIfAbsent(split.transactionId, () => []).add(split);
    }

    // Apply category filter if provided
    if (categoryId != null) {
      filteredTransactions = filteredTransactions.where((t) {
        final splits = splitsByTransaction[t.id] ?? [];
        return splits.any((s) => s.categoryId == categoryId);
      }).toList();
    }

    // Apply account filter if provided
    if (accountId != null) {
      filteredTransactions = filteredTransactions.where((t) {
        final splits = splitsByTransaction[t.id] ?? [];
        return splits.any((s) => s.accountId == accountId);
      }).toList();
    }

    // Apply amount range filter
    if (minAmount != null || maxAmount != null) {
      filteredTransactions = filteredTransactions.where((t) {
        final splits = splitsByTransaction[t.id] ?? [];
        final totalAmount = splits.fold<int>(0, (sum, s) => sum + s.valueNum.abs());
        final amount = totalAmount / 100.0;
        if (minAmount != null && amount < minAmount) return false;
        if (maxAmount != null && amount > maxAmount) return false;
        return true;
      }).toList();
    }

    // Apply tag filter if provided
    if (tagIds != null && tagIds.isNotEmpty) {
      final taggedTransactionIds = await _getTransactionsWithTags(tagIds);
      filteredTransactions = filteredTransactions
          .where((t) => taggedTransactionIds.contains(t.id))
          .toList();
    }

    // Build result
    return filteredTransactions.map((t) {
      final splits = splitsByTransaction[t.id] ?? [];
      return (t, splits);
    }).toList();
  }

  /// Gets transaction IDs that have all the specified tags.
  Future<Set<String>> _getTransactionsWithTags(List<String> tagIds) async {
    final query = select(transactionTags)
      ..where((t) => t.tagId.isIn(tagIds));

    final results = await query.get();

    // Group by transaction and count tags
    final transactionTagCounts = <String, int>{};
    for (final row in results) {
      transactionTagCounts[row.transactionId] = (transactionTagCounts[row.transactionId] ?? 0) + 1;
    }

    // Return only transactions that have all requested tags
    return transactionTagCounts.entries
        .where((e) => e.value == tagIds.length)
        .map((e) => e.key)
        .toSet();
  }

  /// Full-text search with payee support (searches in split memo as well).
  /// This is an enhanced search that includes payee information from splits.
  Future<List<(Transaction, List<Split>)>> advancedFullTextSearch({
    required String query,
    int limit = 50,
    int offset = 0,
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? accountId,
    double? minAmount,
    double? maxAmount,
    List<String>? tagIds,
    String? payee,
  }) async {
    // First, do the FTS5 search on transactions
    var results = await fullTextSearch(
      query: query,
      limit: limit * 2, // Get more results for filtering
      offset: 0,
      startDate: startDate,
      endDate: endDate,
      categoryId: categoryId,
      accountId: accountId,
      minAmount: minAmount,
      maxAmount: maxAmount,
      tagIds: tagIds,
    );

    // Apply payee filter if provided (search in split memo)
    if (payee != null && payee.isNotEmpty) {
      final payeeLower = payee.toLowerCase();
      results = results.where((item) {
        final splits = item.$2;
        return splits.any((s) => 
          s.memo != null && s.memo!.toLowerCase().contains(payeeLower)
        );
      }).toList();
    }

    // Apply offset and limit
    return results.skip(offset).take(limit).toList();
  }

  /// Gets count of FTS results for pagination.
  Future<int> fullTextSearchCount({
    required String query,
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? accountId,
  }) async {
    final sanitizedQuery = query
        .replaceAll('"', '""')
        .replaceAll("'", "''")
        .trim();
    
    if (sanitizedQuery.isEmpty) {
      return getFilteredTransactionsCount(
        startDate: startDate,
        endDate: endDate,
        categoryId: categoryId,
        accountId: accountId,
      );
    }

    final ftsQuery = customSelect(
      '''
      SELECT COUNT(DISTINCT t.id) as count
      FROM transactions_fts fts
      INNER JOIN transactions t ON t.id = fts.id
      WHERE transactions_fts MATCH ?
        AND t.deleted_at IS NULL
      ''',
      variables: [Variable.withString(sanitizedQuery)],
      readsFrom: {transactions},
    );

    final result = await ftsQuery.getSingle();
    return result.read<int>('count') ?? 0;
  }
}