import 'package:test/test.dart';
import 'package:sync/sync.dart';

void main() {
  group('ConflictResolutionStrategy', () {
    test('has all required strategies', () {
      expect(
        ConflictResolutionStrategy.values,
        containsAll([
          ConflictResolutionStrategy.serverWins,
          ConflictResolutionStrategy.clientWins,
          ConflictResolutionStrategy.merge,
          ConflictResolutionStrategy.manual,
        ]),
      );
    });
  });

  group('Conflict', () {
    test('creates conflict with all required fields', () {
      final now = DateTime.now();
      final conflict = Conflict(
        id: 'conflict-1',
        tableName: 'transactions',
        recordId: 'tx-123',
        clientData: {'amount': 100},
        serverData: {'amount': 200},
        detectedAt: now,
      );

      expect(conflict.id, equals('conflict-1'));
      expect(conflict.tableName, equals('transactions'));
      expect(conflict.recordId, equals('tx-123'));
      expect(conflict.clientData, equals({'amount': 100}));
      expect(conflict.serverData, equals({'amount': 200}));
      expect(conflict.detectedAt, equals(now));
    });
  });

  group('ConflictResolution', () {
    test('creates serverWins resolution', () {
      final data = {'id': '1', 'value': 100};
      final resolution = ConflictResolution.serverWins(data, reason: 'Test reason');

      expect(resolution.strategy, equals(ConflictResolutionStrategy.serverWins));
      expect(resolution.resolvedData, equals(data));
      expect(resolution.reason, equals('Test reason'));
    });

    test('creates clientWins resolution', () {
      final data = {'id': '1', 'value': 200};
      final resolution = ConflictResolution.clientWins(data, reason: 'Client is newer');

      expect(resolution.strategy, equals(ConflictResolutionStrategy.clientWins));
      expect(resolution.resolvedData, equals(data));
      expect(resolution.reason, equals('Client is newer'));
    });

    test('creates merged resolution', () {
      final data = {'id': '1', 'client_field': 'a', 'server_field': 'b'};
      final resolution = ConflictResolution.merged(data);

      expect(resolution.strategy, equals(ConflictResolutionStrategy.merge));
      expect(resolution.resolvedData, equals(data));
      expect(resolution.reason, equals('Data merged'));
    });

    test('creates manual resolution', () {
      final resolution = ConflictResolution.manual(reason: 'Sensitive data');

      expect(resolution.strategy, equals(ConflictResolutionStrategy.manual));
      expect(resolution.resolvedData, isNull);
      expect(resolution.reason, equals('Sensitive data'));
    });
  });

  group('FinanceConflictResolver', () {
    late FinanceConflictResolver resolver;

    setUp(() {
      resolver = FinanceConflictResolver();
    });

    group('Delete conflict resolution', () {
      test('client deleted - delete wins (server version preserved)', () async {
        final conflict = Conflict(
          id: 'c1',
          tableName: 'accounts',
          recordId: 'acc-1',
          clientData: {'_deleted': true},
          serverData: {'id': 'acc-1', 'name': 'Bank Account'},
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        expect(resolution.strategy, equals(ConflictResolutionStrategy.serverWins));
        expect(resolution.reason, contains('Client deleted'));
      });

      test('server deleted - delete wins', () async {
        final conflict = Conflict(
          id: 'c2',
          tableName: 'accounts',
          recordId: 'acc-2',
          clientData: {'id': 'acc-2', 'name': 'My Account'},
          serverData: {'_deleted': true},
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        expect(resolution.strategy, equals(ConflictResolutionStrategy.serverWins));
        expect(resolution.reason, contains('Server deleted'));
      });

      test('both deleted - no conflict', () async {
        final conflict = Conflict(
          id: 'c3',
          tableName: 'accounts',
          recordId: 'acc-3',
          clientData: {'_deleted': true},
          serverData: {'_deleted': true},
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        expect(resolution.strategy, equals(ConflictResolutionStrategy.serverWins));
        expect(resolution.reason, contains('Both sides deleted'));
      });
    });

    group('Reconciled transaction detection', () {
      test('reconciled transaction requires manual resolution', () async {
        final conflict = Conflict(
          id: 'c4',
          tableName: 'transactions',
          recordId: 'tx-1',
          clientData: {
            'id': 'tx-1',
            'amount': 100,
            'reconciled': true,
          },
          serverData: {
            'id': 'tx-1',
            'amount': 150,
            'reconciled': false,
          },
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        expect(resolution.strategy, equals(ConflictResolutionStrategy.manual));
        expect(resolution.reason, contains('reconciled'));
      });

      test('transaction with reconcile_date requires manual resolution', () async {
        final conflict = Conflict(
          id: 'c5',
          tableName: 'transactions',
          recordId: 'tx-2',
          clientData: {
            'id': 'tx-2',
            'amount': 200,
          },
          serverData: {
            'id': 'tx-2',
            'amount': 250,
            'reconcile_date': '2024-01-15',
          },
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        expect(resolution.strategy, equals(ConflictResolutionStrategy.manual));
        expect(resolution.reason, contains('reconciled'));
      });

      test('non-reconciled transaction does not trigger manual resolution', () async {
        final conflict = Conflict(
          id: 'c6',
          tableName: 'transactions',
          recordId: 'tx-3',
          clientData: {
            'id': 'tx-3',
            'amount': 100,
            'description': 'Client desc',
            'updated_at': DateTime.now().toIso8601String(),
          },
          serverData: {
            'id': 'tx-3',
            'amount': 100,
            'description': 'Server desc',
            'updated_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
          },
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        // Should not be manual - will be resolved by timestamp or merge
        expect(resolution.strategy, isNot(equals(ConflictResolutionStrategy.manual)));
      });
    });

    group('Sensitive field detection', () {
      test('amount_num change in transactions requires manual resolution', () async {
        final conflict = Conflict(
          id: 'c7',
          tableName: 'transactions',
          recordId: 'tx-4',
          clientData: {
            'id': 'tx-4',
            'amount_num': 1000,
            'amount_denom': 100,
          },
          serverData: {
            'id': 'tx-4',
            'amount_num': 2000,
            'amount_denom': 100,
          },
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        expect(resolution.strategy, equals(ConflictResolutionStrategy.manual));
        expect(resolution.reason, contains('Sensitive field'));
      });

      test('value_num change in splits requires manual resolution', () async {
        final conflict = Conflict(
          id: 'c8',
          tableName: 'splits',
          recordId: 'split-1',
          clientData: {
            'id': 'split-1',
            'value_num': 500,
            'value_denom': 100,
          },
          serverData: {
            'id': 'split-1',
            'value_num': 600,
            'value_denom': 100,
          },
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        expect(resolution.strategy, equals(ConflictResolutionStrategy.manual));
        expect(resolution.reason, contains('Sensitive field'));
      });

      test('quantity change in budgets requires manual resolution', () async {
        final conflict = Conflict(
          id: 'c9',
          tableName: 'budgets',
          recordId: 'budget-1',
          clientData: {
            'id': 'budget-1',
            'quantity_num': 10,
            'quantity_denom': 1,
          },
          serverData: {
            'id': 'budget-1',
            'quantity_num': 15,
            'quantity_denom': 1,
          },
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        expect(resolution.strategy, equals(ConflictResolutionStrategy.manual));
        expect(resolution.reason, contains('Sensitive field'));
      });

      test('non-amount table does not trigger sensitive field check', () async {
        final conflict = Conflict(
          id: 'c10',
          tableName: 'categories',
          recordId: 'cat-1',
          clientData: {
            'id': 'cat-1',
            'name': 'Food',
            'amount_num': 100,
          },
          serverData: {
            'id': 'cat-1',
            'name': 'Dining',
            'amount_num': 200,
          },
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        // Categories is not in _amountTables, so should not trigger manual
        expect(resolution.strategy, isNot(equals(ConflictResolutionStrategy.manual)));
      });

      test('same sensitive field values do not trigger manual resolution', () async {
        final conflict = Conflict(
          id: 'c11',
          tableName: 'transactions',
          recordId: 'tx-5',
          clientData: {
            'id': 'tx-5',
            'amount_num': 1000,
            'amount_denom': 100,
            'description': 'Client',
          },
          serverData: {
            'id': 'tx-5',
            'amount_num': 1000,
            'amount_denom': 100,
            'description': 'Server',
          },
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        // Amounts are same, only description differs - should not be manual
        expect(resolution.strategy, isNot(equals(ConflictResolutionStrategy.manual)));
      });
    });

    group('Timestamp-based resolution', () {
      test('client newer wins', () async {
        final now = DateTime.now();
        final conflict = Conflict(
          id: 'c12',
          tableName: 'accounts',
          recordId: 'acc-4',
          clientData: {
            'id': 'acc-4',
            'name': 'Updated Name',
            'updated_at': now.toIso8601String(),
          },
          serverData: {
            'id': 'acc-4',
            'name': 'Old Name',
            'updated_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
          },
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        expect(resolution.strategy, equals(ConflictResolutionStrategy.clientWins));
        expect(resolution.resolvedData?['name'], equals('Updated Name'));
        expect(resolution.reason, contains('Client version is newer'));
      });

      test('server newer wins', () async {
        final now = DateTime.now();
        final conflict = Conflict(
          id: 'c13',
          tableName: 'accounts',
          recordId: 'acc-5',
          clientData: {
            'id': 'acc-5',
            'name': 'Old Name',
            'updated_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
          },
          serverData: {
            'id': 'acc-5',
            'name': 'Updated Name',
            'updated_at': now.toIso8601String(),
          },
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        expect(resolution.strategy, equals(ConflictResolutionStrategy.serverWins));
        expect(resolution.resolvedData?['name'], equals('Updated Name'));
        expect(resolution.reason, contains('Server version is newer'));
      });

      test('same timestamp falls through to merge', () async {
        final timestamp = DateTime.now();
        final conflict = Conflict(
          id: 'c14',
          tableName: 'accounts',
          recordId: 'acc-6',
          clientData: {
            'id': 'acc-6',
            'name': 'Client Name',
            'description': 'Client desc',
            'updated_at': timestamp.toIso8601String(),
          },
          serverData: {
            'id': 'acc-6',
            'name': 'Server Name',
            'notes': 'Server notes',
            'updated_at': timestamp.toIso8601String(),
          },
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        expect(resolution.strategy, equals(ConflictResolutionStrategy.merge));
      });

      test('supports modified_at timestamp field', () async {
        final now = DateTime.now();
        final conflict = Conflict(
          id: 'c15',
          tableName: 'accounts',
          recordId: 'acc-7',
          clientData: {
            'id': 'acc-7',
            'name': 'Client',
            'modified_at': now.toIso8601String(),
          },
          serverData: {
            'id': 'acc-7',
            'name': 'Server',
            'modified_at': now.subtract(const Duration(minutes: 30)).toIso8601String(),
          },
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        expect(resolution.strategy, equals(ConflictResolutionStrategy.clientWins));
      });

      test('supports Unix timestamp (milliseconds)', () async {
        final now = DateTime.now();
        final conflict = Conflict(
          id: 'c16',
          tableName: 'accounts',
          recordId: 'acc-8',
          clientData: {
            'id': 'acc-8',
            'name': 'Client',
            'updated_at': now.millisecondsSinceEpoch,
          },
          serverData: {
            'id': 'acc-8',
            'name': 'Server',
            'updated_at': now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
          },
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        expect(resolution.strategy, equals(ConflictResolutionStrategy.clientWins));
      });
    });

    group('Field merge', () {
      test('merges non-conflicting fields', () async {
        final conflict = Conflict(
          id: 'c17',
          tableName: 'accounts',
          recordId: 'acc-9',
          clientData: {
            'id': 'acc-9',
            'name': 'My Account',
          },
          serverData: {
            'id': 'acc-9',
            'description': 'Account description',
          },
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        expect(resolution.strategy, equals(ConflictResolutionStrategy.merge));
        expect(resolution.resolvedData?['name'], equals('My Account'));
        expect(resolution.resolvedData?['description'], equals('Account description'));
      });

      test('preserves same values', () async {
        final conflict = Conflict(
          id: 'c18',
          tableName: 'accounts',
          recordId: 'acc-10',
          clientData: {
            'id': 'acc-10',
            'name': 'Same Name',
            'type': 'checking',
          },
          serverData: {
            'id': 'acc-10',
            'name': 'Same Name',
            'currency': 'USD',
          },
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        expect(resolution.strategy, equals(ConflictResolutionStrategy.merge));
        expect(resolution.resolvedData?['name'], equals('Same Name'));
        expect(resolution.resolvedData?['type'], equals('checking'));
        expect(resolution.resolvedData?['currency'], equals('USD'));
      });

      test('skips internal fields starting with underscore', () async {
        final conflict = Conflict(
          id: 'c19',
          tableName: 'accounts',
          recordId: 'acc-11',
          clientData: {
            'id': 'acc-11',
            'name': 'Account',
            '_internal': 'client_internal',
          },
          serverData: {
            'id': 'acc-11',
            'name': 'Account',
            '_internal': 'server_internal',
          },
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        expect(resolution.resolvedData?.containsKey('_internal'), isFalse);
      });

      test('conflicting fields without timestamps prefer server', () async {
        final conflict = Conflict(
          id: 'c20',
          tableName: 'accounts',
          recordId: 'acc-12',
          clientData: {
            'id': 'acc-12',
            'name': 'Client Name',
          },
          serverData: {
            'id': 'acc-12',
            'name': 'Server Name',
          },
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        expect(resolution.strategy, equals(ConflictResolutionStrategy.merge));
        expect(resolution.resolvedData?['name'], equals('Server Name'));
      });
    });

    group('Business rules priority', () {
      test('delete rule takes priority over reconciled check', () async {
        final conflict = Conflict(
          id: 'c21',
          tableName: 'transactions',
          recordId: 'tx-6',
          clientData: {'_deleted': true},
          serverData: {
            'id': 'tx-6',
            'amount': 100,
            'reconciled': true,
          },
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        // Delete rule should apply first
        expect(resolution.strategy, equals(ConflictResolutionStrategy.serverWins));
        expect(resolution.reason, contains('deleted'));
      });

      test('reconciled rule takes priority over timestamp', () async {
        final now = DateTime.now();
        final conflict = Conflict(
          id: 'c22',
          tableName: 'transactions',
          recordId: 'tx-7',
          clientData: {
            'id': 'tx-7',
            'amount': 100,
            'reconciled': true,
            'updated_at': now.toIso8601String(),
          },
          serverData: {
            'id': 'tx-7',
            'amount': 200,
            'updated_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
          },
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        // Reconciled check should trigger before timestamp resolution
        expect(resolution.strategy, equals(ConflictResolutionStrategy.manual));
        expect(resolution.reason, contains('reconciled'));
      });

      test('sensitive field rule takes priority over timestamp', () async {
        final now = DateTime.now();
        final conflict = Conflict(
          id: 'c23',
          tableName: 'transactions',
          recordId: 'tx-8',
          clientData: {
            'id': 'tx-8',
            'amount_num': 1000,
            'amount_denom': 100,
            'updated_at': now.toIso8601String(),
          },
          serverData: {
            'id': 'tx-8',
            'amount_num': 2000,
            'amount_denom': 100,
            'updated_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
          },
          detectedAt: DateTime.now(),
        );

        final resolution = await resolver.resolve(conflict);

        // Sensitive field check should trigger before timestamp resolution
        expect(resolution.strategy, equals(ConflictResolutionStrategy.manual));
        expect(resolution.reason, contains('Sensitive field'));
      });
    });
  });
}
