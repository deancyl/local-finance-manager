import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import 'package:database/database.dart';
import '../../accounts/data/account_provider.dart';

/// Backup metadata model
class BackupMetadata {
  final String id;
  final String filePath;
  final DateTime createdAt;
  final int sizeBytes;
  final int transactionCount;
  final int accountCount;
  final String? checksum;
  final bool isVerified;

  const BackupMetadata({
    required this.id,
    required this.filePath,
    required this.createdAt,
    required this.sizeBytes,
    required this.transactionCount,
    required this.accountCount,
    this.checksum,
    this.isVerified = false,
  });

  String get fileName => filePath.split('/').last;
  
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'filePath': filePath,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'sizeBytes': sizeBytes,
    'transactionCount': transactionCount,
    'accountCount': accountCount,
    'checksum': checksum,
    'isVerified': isVerified,
  };

  factory BackupMetadata.fromJson(Map<String, dynamic> json) => BackupMetadata(
    id: json['id'] as String,
    filePath: json['filePath'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
    sizeBytes: json['sizeBytes'] as int,
    transactionCount: json['transactionCount'] as int,
    accountCount: json['accountCount'] as int,
    checksum: json['checksum'] as String?,
    isVerified: json['isVerified'] as bool? ?? false,
  );
}

/// Backup settings
class BackupSettings {
  final bool autoBackupEnabled;
  final BackupFrequency frequency;
  final int retentionCount; // Keep last N backups
  final bool includeAttachments;
  final bool compressBackup;

  const BackupSettings({
    this.autoBackupEnabled = true,
    this.frequency = BackupFrequency.daily,
    this.retentionCount = 10,
    this.includeAttachments = true,
    this.compressBackup = true,
  });

  BackupSettings copyWith({
    bool? autoBackupEnabled,
    BackupFrequency? frequency,
    int? retentionCount,
    bool? includeAttachments,
    bool? compressBackup,
  }) {
    return BackupSettings(
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      frequency: frequency ?? this.frequency,
      retentionCount: retentionCount ?? this.retentionCount,
      includeAttachments: includeAttachments ?? this.includeAttachments,
      compressBackup: compressBackup ?? this.compressBackup,
    );
  }
}

enum BackupFrequency {
  daily,
  weekly,
  monthly,
  manual;

  String get label {
    switch (this) {
      case BackupFrequency.daily: return '每天';
      case BackupFrequency.weekly: return '每周';
      case BackupFrequency.monthly: return '每月';
      case BackupFrequency.manual: return '手动';
    }
  }
}

/// Backup service for creating and restoring backups
class BackupService {
  final LocalFinanceDatabase _db;
  final Uuid _uuid = const Uuid();

  BackupService(this._db);

  /// Create a backup of the current database
  Future<BackupMetadata> createBackup({
    required String backupPath,
    bool compress = true,
    bool includeAttachments = true,
  }) async {
    final backupId = _uuid.v4();
    final timestamp = DateTime.now();
    final timestampStr = DateFormat('yyyyMMdd_HHmmss').format(timestamp);
    final fileName = 'backup_${timestampStr}_$backupId.db';
    final filePath = '$backupPath/$fileName';

    // Get database file path
    final dbPath = await _getDatabasePath();
    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      throw Exception('Database file not found');
    }

    // Get statistics
    final transactionCount = await _db.transactionsDao.count();
    final accountCount = (await _db.accountsDao.getAll()).length;

    // Create backup
    if (compress) {
      // Read database file
      final dbBytes = await dbFile.readAsBytes();
      
      // Create archive
      final archive = Archive();
      final dbArchiveFile = ArchiveFile('finance.db', dbBytes.length, dbBytes);
      archive.addFile(dbArchiveFile);
      
      // Add attachments if enabled
      if (includeAttachments) {
        final attachmentsDir = await _getAttachmentsDir();
        if (await attachmentsDir.exists()) {
          await for (final entity in attachmentsDir.list(recursive: true)) {
            if (entity is File) {
              final relativePath = entity.path.substring(attachmentsDir.path.length + 1);
              final bytes = await entity.readAsBytes();
              archive.addFile(ArchiveFile('attachments/$relativePath', bytes.length, bytes));
            }
          }
        }
      }
      
      // Compress and write
      final compressed = ZipEncoder().encode(archive);
      if (compressed == null) {
        throw Exception('Failed to compress backup');
      }
      
      final backupFile = File('$filePath.zip');
      await backupFile.writeAsBytes(compressed);
      
      final sizeBytes = await backupFile.length();
      final checksum = await _calculateChecksum(compressed);
      
      return BackupMetadata(
        id: backupId,
        filePath: backupFile.path,
        createdAt: timestamp,
        sizeBytes: sizeBytes,
        transactionCount: transactionCount,
        accountCount: accountCount,
        checksum: checksum,
        isVerified: true,
      );
    } else {
      // Simple copy without compression
      await dbFile.copy(filePath);
      
      final sizeBytes = await File(filePath).length();
      
      return BackupMetadata(
        id: backupId,
        filePath: filePath,
        createdAt: timestamp,
        sizeBytes: sizeBytes,
        transactionCount: transactionCount,
        accountCount: accountCount,
        isVerified: true,
      );
    }
  }

  /// Restore from a backup
  Future<void> restoreBackup(String backupFilePath) async {
    final backupFile = File(backupFilePath);
    
    if (!await backupFile.exists()) {
      throw Exception('Backup file not found');
    }

    final dbPath = await _getDatabasePath();
    final attachmentsDir = await _getAttachmentsDir();
    
    // Ensure attachments directory exists
    if (!await attachmentsDir.exists()) {
      await attachmentsDir.create(recursive: true);
    }
    
    // Check if compressed
    if (backupFilePath.endsWith('.zip')) {
      final bytes = await backupFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      // Find database file and attachments in archive
      for (final file in archive.files) {
        if (file.name == 'finance.db') {
          final dbFile = File(dbPath);
          await dbFile.writeAsBytes(file.content as List<int>);
        } else if (file.name.startsWith('attachments/')) {
          // Restore attachment files
          final relativePath = file.name.substring('attachments/'.length);
          final attachmentPath = '${attachmentsDir.path}/$relativePath';
          final attachmentFile = File(attachmentPath);
          
          // Ensure parent directory exists
          if (!await attachmentFile.parent.exists()) {
            await attachmentFile.parent.create(recursive: true);
          }
          
          await attachmentFile.writeAsBytes(file.content as List<int>);
        }
      }
    } else {
      // Simple copy
      await backupFile.copy(dbPath);
    }
    
    // Reopen database
    // Note: This requires app restart to take effect
  }

  /// List all backups
  Future<List<BackupMetadata>> listBackups(String backupPath) async {
    final backupDir = Directory(backupPath);
    
    if (!await backupDir.exists()) {
      return [];
    }

    final backups = <BackupMetadata>[];
    
    await for (final entity in backupDir.list()) {
      if (entity is File && (entity.path.endsWith('.db') || entity.path.endsWith('.zip'))) {
        try {
          final stat = await entity.stat();
          final fileName = entity.path.split('/').last;
          
          // Parse backup metadata from filename
          // Format: backup_YYYYMMDD_HHmmss_UUID.db.zip
          final parts = fileName.replaceAll('.db.zip', '').replaceAll('.db', '').split('_');
          if (parts.length >= 4) {
            final dateStr = '${parts[1]}_${parts[2]}';
            final timestamp = DateFormat('yyyyMMdd_HHmmss').parse(dateStr);
            final id = parts.sublist(3).join('_');
            
            backups.add(BackupMetadata(
              id: id,
              filePath: entity.path,
              createdAt: timestamp,
              sizeBytes: stat.size,
              transactionCount: 0, // Unknown without reading backup
              accountCount: 0,
              isVerified: false,
            ));
          }
        } catch (e) {
          // Skip invalid backup files
        }
      }
    }

    // Sort by creation time (newest first)
    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return backups;
  }

  /// Delete old backups based on retention policy
  Future<void> cleanupOldBackups(String backupPath, int keepCount) async {
    final backups = await listBackups(backupPath);
    
    if (backups.length <= keepCount) return;
    
    final toDelete = backups.skip(keepCount);
    
    for (final backup in toDelete) {
      final file = File(backup.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// Verify backup integrity
  Future<bool> verifyBackup(String backupFilePath) async {
    try {
      final backupFile = File(backupFilePath);
      
      if (!await backupFile.exists()) return false;
      
      if (backupFilePath.endsWith('.zip')) {
        final bytes = await backupFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        
        // Check if database file exists in archive
        return archive.files.any((f) => f.name == 'finance.db');
      } else {
        // Check if file is a valid SQLite database
        final bytes = await backupFile.readAsBytes();
        // SQLite files start with "SQLite format 3\0"
        return bytes.length > 16 && 
               String.fromCharCodes(bytes.sublist(0, 15)) == 'SQLite format 3';
      }
    } catch (e) {
      return false;
    }
  }

  Future<String> _getDatabasePath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/finance.db';
  }

  Future<Directory> _getAttachmentsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/attachments');
  }

  Future<String> _calculateChecksum(List<int> bytes) async {
    // Simple CRC32 checksum using archive package
    final crc = Crc32();
    crc.add(bytes);
    final checksumBytes = crc.close();
    // Convert list of bytes to hex string
    return checksumBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Provider for backup service
final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(databaseProvider);
  return BackupService(db);
});

/// Provider for backup settings
final backupSettingsProvider = StateProvider<BackupSettings>((ref) {
  return const BackupSettings();
});

/// Provider for backup list
final backupListProvider = FutureProvider<List<BackupMetadata>>((ref) async {
  final backupService = ref.watch(backupServiceProvider);
  final appDir = await getApplicationDocumentsDirectory();
  final backupPath = '${appDir.path}/backups';
  
  // Ensure backup directory exists
  final backupDir = Directory(backupPath);
  if (!await backupDir.exists()) {
    await backupDir.create(recursive: true);
  }
  
  return backupService.listBackups(backupPath);
});

/// Notifier for backup operations
class BackupNotifier extends StateNotifier<AsyncValue<void>> {
  final BackupService _service;
  final Ref _ref;

  BackupNotifier(this._service, this._ref) : super(const AsyncValue.data(null));

  Future<BackupMetadata?> createBackup() async {
    state = const AsyncValue.loading();
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupPath = '${appDir.path}/backups';
      
      // Ensure backup directory exists
      final backupDir = Directory(backupPath);
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      
      final settings = _ref.read(backupSettingsProvider);
      
      final metadata = await _service.createBackup(
        backupPath: backupPath,
        compress: settings.compressBackup,
        includeAttachments: settings.includeAttachments,
      );
      
      // Cleanup old backups
      await _service.cleanupOldBackups(backupPath, settings.retentionCount);
      
      // Refresh backup list
      _ref.invalidate(backupListProvider);
      
      state = const AsyncValue.data(null);
      return metadata;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> restoreBackup(String backupFilePath) async {
    state = const AsyncValue.loading();
    try {
      await _service.restoreBackup(backupFilePath);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> verifyBackup(String backupFilePath) async {
    return _service.verifyBackup(backupFilePath);
  }

  Future<void> deleteBackup(String backupFilePath) async {
    final file = File(backupFilePath);
    if (await file.exists()) {
      await file.delete();
      _ref.invalidate(backupListProvider);
    }
  }
}

final backupNotifierProvider =
    StateNotifierProvider<BackupNotifier, AsyncValue<void>>((ref) {
  final service = ref.watch(backupServiceProvider);
  return BackupNotifier(service, ref);
});
