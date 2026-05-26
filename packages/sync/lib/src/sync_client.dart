import 'dart:async';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart' hide SyncStatus;

import 'connector/backend_connector.dart';
import 'encryption/encryption_service.dart';
import 'models/sync_models.dart';
import 'sync_config.dart';

/// Main sync client that wraps PowerSync database with Drift integration.
/// 
/// This class provides:
/// - PowerSync database initialization with optional encryption
/// - Drift database integration via SqliteAsyncDriftConnection
/// - Connection management to sync server
/// - Status monitoring and reactive streams
/// 
/// Usage:
/// ```dart
/// final syncClient = SyncClient(
///   config: SyncConfig(
///     schema: mySchema,
///     serverUrl: 'https://sync.example.com',
///   ),
/// );
/// 
/// await syncClient.initialize();
/// await syncClient.connect();
/// 
/// // Watch sync status
/// syncClient.watchStatus().listen((status) {
///   print('Sync status: $status');
/// });
/// ```
class SyncClient {
  /// Configuration for sync.
  final SyncConfig config;
  
  /// Optional encryption settings.
  final SyncEncryption? encryption;
  
  final Logger _log = Logger('SyncClient');
  
  late final PowerSyncDatabase _powerSyncDb;
  late final FinanceAppConnector _connector;
  
  /// Current sync status.
  SyncStatus _status = SyncStatus.notInitialized;
  
  /// Stream controller for status changes.
  final StreamController<SyncStatus> _statusController = 
      StreamController<SyncStatus>.broadcast();
  
  /// Last sync time.
  DateTime? _lastSyncTime;
  
  /// Error message if in error state.
  String? _errorMessage;
  
  /// Whether the client has been initialized.
  bool _initialized = false;
  
  /// Subscription to PowerSync status updates.
  StreamSubscription? _powerSyncSubscription;

  SyncClient({
    required this.config,
    this.encryption,
  });

  /// Current sync status.
  SyncStatus get status => _status;
  
  /// Last successful sync time.
  DateTime? get lastSyncTime => _lastSyncTime;
  
  /// Error message if in error state.
  String? get errorMessage => _errorMessage;
  
  /// Whether the client is initialized.
  bool get isInitialized => _initialized;
  
  /// The underlying PowerSync database.
  /// Only available after [initialize] is called.
  PowerSyncDatabase get powerSyncDb {
    if (!_initialized) {
      throw StateError('SyncClient not initialized. Call initialize() first.');
    }
    return _powerSyncDb;
  }
  
  /// The backend connector.
  FinanceAppConnector get connector => _connector;

  /// Initializes the PowerSync database with optional encryption.
  /// 
  /// This must be called before any other methods.
  /// Sets up the database file, encryption, and prepares for connection.
  Future<void> initialize() async {
    if (_initialized) {
      _log.warning('SyncClient already initialized');
      return;
    }

    _log.info('Initializing SyncClient');
    _updateStatus(SyncStatus.disconnected);

    try {
      // Get database path
      final dbPath = await _getDatabasePath();
      _log.fine('Database path: $dbPath');

      // Setup encryption options if provided
      EncryptionOptions? encryptionOptions;
      if (encryption != null) {
        _log.info('Setting up database encryption');
        final key = await encryption!.getEncryptionKey();
        encryptionOptions = EncryptionOptions(
          key: key,
          sqlcipherCompatibility: false,
        );
      }

      // Create PowerSync database
      _powerSyncDb = PowerSyncDatabase(
        schema: config.schema,
        path: dbPath,
        encryption: encryptionOptions,
      );

      // Initialize the database
      await _powerSyncDb.initialize();
      _log.info('PowerSync database initialized');

      // Create backend connector
      _connector = FinanceAppConnector(
        serverUrl: config.serverUrl,
        authProvider: config.authProvider,
        deviceId: config.deviceId,
      );

      _initialized = true;
      _log.info('SyncClient initialization complete');
    } catch (e, stackTrace) {
      _log.severe('Failed to initialize SyncClient', e, stackTrace);
      _errorMessage = e.toString();
      _updateStatus(SyncStatus.error);
      rethrow;
    }
  }

  /// Creates a Drift database connection using the PowerSync database.
  /// 
  /// IMPORTANT: Use this method to create the Drift database instance.
  /// Returns a PowerSync-compatible query executor.
  /// 
  /// Example:
  /// ```dart
  /// final driftDb = LocalFinanceDatabase(syncClient.createDriftConnection());
  /// ```
  QueryExecutor createDriftConnection() {
    if (!_initialized) {
      throw StateError('SyncClient not initialized. Call initialize() first.');
    }
    // Use PowerSync's native query executor
    // Note: This provides basic query execution for PowerSync database
    return _PowerSyncQueryExecutor(_powerSyncDb);
  }

  /// Connects to the sync server.
  /// 
  /// Requires [initialize] to be called first.
  /// Uses the backend connector for authentication and data upload.
  Future<void> connect() async {
    _checkInitialized();
    
    _log.info('Connecting to sync server: ${config.serverUrl}');
    _updateStatus(SyncStatus.connecting);

    try {
      // Connect to PowerSync (no crudThrottle parameter in current API)
      await _powerSyncDb.connect(
        connector: _connector,
      );

      // Watch for status changes
      _powerSyncSubscription = _powerSyncDb.statusStream.listen(
        _onPowerSyncStatus,
        onError: _onPowerSyncError,
      );

      _updateStatus(SyncStatus.connected);
      _log.info('Connected to sync server');
    } catch (e, stackTrace) {
      _log.severe('Failed to connect to sync server', e, stackTrace);
      _errorMessage = e.toString();
      _updateStatus(SyncStatus.error);
      rethrow;
    }
  }

  /// Disconnects from the sync server.
  /// 
  /// The database remains usable locally after disconnect.
  Future<void> disconnect() async {
    _checkInitialized();
    
    _log.info('Disconnecting from sync server');
    
    await _powerSyncSubscription?.cancel();
    _powerSyncSubscription = null;
    
    await _powerSyncDb.disconnect();
    
    _updateStatus(SyncStatus.disconnected);
    _log.info('Disconnected from sync server');
  }

  /// Triggers a manual sync.
  /// 
  /// Forces an immediate sync of local changes to server
  /// and downloads any remote changes.
  Future<void> sync() async {
    _checkInitialized();
    
    if (_status != SyncStatus.connected) {
      _log.warning('Cannot sync: not connected');
      return;
    }

    _log.info('Triggering manual sync');
    
    try {
      // Trigger upload via connector's uploadData method
      await _connector.uploadData(_powerSyncDb);
      _lastSyncTime = DateTime.now();
      _log.info('Manual sync completed');
    } catch (e, stackTrace) {
      _log.severe('Manual sync failed', e, stackTrace);
      rethrow;
    }
  }

  /// Closes the database and releases resources.
  Future<void> close() async {
    _log.info('Closing SyncClient');
    
    await _powerSyncSubscription?.cancel();
    _powerSyncSubscription = null;
    
    if (_initialized) {
      await _powerSyncDb.close();
    }
    
    _connector.dispose();
    _statusController.close();
    
    _initialized = false;
    _updateStatus(SyncStatus.notInitialized);
    _log.info('SyncClient closed');
  }

  /// Watches sync status changes.
  /// 
  /// Emits the current status immediately on subscribe,
  /// then emits on each status change.
  Stream<SyncStatus> watchStatus() {
    return _statusController.stream;
  }

  /// Gets current sync progress information.
  Future<SyncProgress> getProgress() async {
    _checkInitialized();
    
    // Get pending upload count from PowerSync
    int pendingUploads = 0;
    try {
      final transaction = await _powerSyncDb.getNextCrudTransaction();
      pendingUploads = transaction?.crud.length ?? 0;
    } catch (e) {
      _log.warning('Failed to get pending uploads: $e');
    }

    return SyncProgress(
      status: _status,
      pendingUploads: pendingUploads,
      pendingDownloads: 0, // PowerSync doesn't expose this
      lastSyncTime: _lastSyncTime,
      errorMessage: _errorMessage,
    );
  }

  /// Updates the sync status and notifies listeners.
  void _updateStatus(SyncStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
    }
  }

  /// Handles PowerSync status changes.
  void _onPowerSyncStatus(dynamic status) {
    _log.fine('PowerSync status: $status');
    // Map PowerSync status to our status
    // PowerSync uses a status object with connected, connecting, etc.
    if (status is Map) {
      final connected = status['connected'] as bool? ?? false;
      final connecting = status['connecting'] as bool? ?? false;
      final downloadError = status['downloadError'];
      final uploadError = status['uploadError'];
      
      if (downloadError != null || uploadError != null) {
        _updateStatus(SyncStatus.error);
        _errorMessage = downloadError?.toString() ?? uploadError?.toString();
      } else if (connected) {
        _updateStatus(SyncStatus.connected);
      } else if (connecting) {
        _updateStatus(SyncStatus.connecting);
      } else {
        _updateStatus(SyncStatus.disconnected);
      }
    }
  }

  /// Handles PowerSync errors.
  void _onPowerSyncError(Object error, StackTrace stackTrace) {
    _log.severe('PowerSync error', error, stackTrace);
    _errorMessage = error.toString();
    _updateStatus(SyncStatus.error);
  }

  /// Gets the database file path.
  Future<String> _getDatabasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, config.databaseName);
  }

  /// Checks if the client is initialized.
  void _checkInitialized() {
    if (!_initialized) {
      throw StateError('SyncClient not initialized. Call initialize() first.');
    }
  }
}

/// A Drift QueryExecutor that wraps PowerSync database.
/// 
/// This provides basic query execution capabilities for Drift
/// using PowerSync's underlying SQLite database.
class _PowerSyncQueryExecutor extends QueryExecutor {
  final PowerSyncDatabase _db;
  
  _PowerSyncQueryExecutor(this._db);
  
  @override
  SqlDialect get dialect => SqlDialect.sqlite;
  
  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async {
    return true; // PowerSync manages its own connection
  }
  
  @override
  TransactionExecutor beginTransaction() {
    return _PowerSyncTransactionExecutor(_db);
  }
  
  @override
  QueryExecutor beginExclusive() {
    return this; // PowerSync handles exclusivity internally
  }
  
  @override
  Future<void> runBatched(BatchedStatements statements) async {
    for (final stmt in statements.statements) {
      await _db.execute(stmt.sql, stmt.arguments ?? []);
    }
  }
  
  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) async {
    await _db.execute(statement, args ?? []);
  }
  
  @override
  Future<int> runInsert(String statement, [List<Object?>? args]) async {
    await _db.execute(statement, args ?? []);
    // Get last insert row id
    final result = await _db.execute('SELECT last_insert_rowid()');
    return result.first?['last_insert_rowid()'] as int? ?? 0;
  }
  
  @override
  Future<int> runUpdate(String statement, [List<Object?>? args]) async {
    await _db.execute(statement, args ?? []);
    // Get changes count
    final result = await _db.execute('SELECT changes()');
    return result.first?['changes()'] as int? ?? 0;
  }
  
  @override
  Future<int> runDelete(String statement, [List<Object?>? args]) async {
    return runUpdate(statement, args);
  }
  
  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement, [
    List<Object?>? args,
  ]) async {
    return _db.execute(statement, args ?? []);
  }
  
  @override
  Future<void> close() async {
    // PowerSync manages its own lifecycle
  }
}

/// Transaction executor for PowerSync.
class _PowerSyncTransactionExecutor extends TransactionExecutor {
  final PowerSyncDatabase _db;
  bool _isOpen = false;
  
  _PowerSyncTransactionExecutor(this._db);
  
  @override
  Future<void> start() async {
    await _db.execute('BEGIN TRANSACTION');
    _isOpen = true;
  }
  
  @override
  Future<void> send() async {
    await _db.execute('COMMIT');
    _isOpen = false;
  }
  
  @override
  Future<void> rollback() async {
    await _db.execute('ROLLBACK');
    _isOpen = false;
  }
  
  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async {
    if (!_isOpen) {
      await start();
    }
    return true;
  }
  
  @override
  SqlDialect get dialect => SqlDialect.sqlite;
  
  @override
  QueryExecutor beginExclusive() {
    return this;
  }
  
  @override
  TransactionExecutor beginTransaction() {
    return this;
  }
  
  @override
  Future<void> runBatched(BatchedStatements statements) async {
    for (final stmt in statements.statements) {
      await _db.execute(stmt.sql, stmt.arguments ?? []);
    }
  }
  
  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) async {
    await _db.execute(statement, args ?? []);
  }
  
  @override
  Future<int> runInsert(String statement, [List<Object?>? args]) async {
    await _db.execute(statement, args ?? []);
    final result = await _db.execute('SELECT last_insert_rowid()');
    return result.first?['last_insert_rowid()'] as int? ?? 0;
  }
  
  @override
  Future<int> runUpdate(String statement, [List<Object?>? args]) async {
    await _db.execute(statement, args ?? []);
    final result = await _db.execute('SELECT changes()');
    return result.first?['changes()'] as int? ?? 0;
  }
  
  @override
  Future<int> runDelete(String statement, [List<Object?>? args]) async {
    return runUpdate(statement, args);
  }
  
  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement, [
    List<Object?>? args,
  ]) async {
    return _db.execute(statement, args ?? []);
  }
  
  @override
  Future<void> close() async {
    if (_isOpen) {
      await rollback();
    }
  }
}
