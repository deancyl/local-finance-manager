import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:database/database.dart';
import 'package:finance_app/features/accounts/data/account_provider.dart';
import 'data/export_service.dart';
import 'data/import_service.dart';

/// Export status enum
enum ExportStatus {
  idle,
  exporting,
  success,
  error,
}

/// Export state class
class ExportState {
  final ExportStatus status;
  final String? message;
  final ExportResult? result;
  final double? progress;

  const ExportState({
    this.status = ExportStatus.idle,
    this.message,
    this.result,
    this.progress,
  });

  ExportState copyWith({
    ExportStatus? status,
    String? message,
    ExportResult? result,
    double? progress,
  }) {
    return ExportState(
      status: status ?? this.status,
      message: message ?? this.message,
      result: result ?? this.result,
      progress: progress ?? this.progress,
    );
  }
}

/// Import status enum
enum ImportStatus {
  idle,
  validating,
  previewing,
  importing,
  success,
  error,
}

/// Import state class
class ImportState {
  final ImportStatus status;
  final String? message;
  final ImportPreview? preview;
  final ImportResult? result;
  final String? filePath;

  const ImportState({
    this.status = ImportStatus.idle,
    this.message,
    this.preview,
    this.result,
    this.filePath,
  });

  ImportState copyWith({
    ImportStatus? status,
    String? message,
    ImportPreview? preview,
    ImportResult? result,
    String? filePath,
  }) {
    return ImportState(
      status: status ?? this.status,
      message: message ?? this.message,
      preview: preview ?? this.preview,
      result: result ?? this.result,
      filePath: filePath ?? this.filePath,
    );
  }
}

/// Export notifier for managing export operations
class ExportNotifier extends StateNotifier<ExportState> {
  final Ref _ref;
  late final ExportService _exportService;

  ExportNotifier(this._ref) : super(const ExportState()) {
    final db = _ref.read(databaseProvider);
    _exportService = ExportService(db);
  }

  /// Exports transactions to CSV
  Future<void> exportTransactionsToCSV(ExportFilters filters) async {
    state = ExportState(
      status: ExportStatus.exporting,
      message: '正在导出交易记录为CSV...',
    );

    try {
      final result = await _exportService.exportTransactionsToCSV(
        filters: filters,
      );

      state = ExportState(
        status: ExportStatus.success,
        message: '导出成功！共导出 ${result.transactionCount} 条交易记录',
        result: result,
      );
    } on ExportException catch (e) {
      state = ExportState(
        status: ExportStatus.error,
        message: e.message,
      );
    } catch (e) {
      state = ExportState(
        status: ExportStatus.error,
        message: '导出失败: $e',
      );
    }
  }

  /// Exports transactions to JSON
  Future<void> exportTransactionsToJSON(ExportFilters filters) async {
    state = ExportState(
      status: ExportStatus.exporting,
      message: '正在导出交易记录为JSON...',
    );

    try {
      final result = await _exportService.exportTransactionsToJSON(
        filters: filters,
      );

      state = ExportState(
        status: ExportStatus.success,
        message: '导出成功！共导出 ${result.transactionCount} 条交易记录',
        result: result,
      );
    } on ExportException catch (e) {
      state = ExportState(
        status: ExportStatus.error,
        message: e.message,
      );
    } catch (e) {
      state = ExportState(
        status: ExportStatus.error,
        message: '导出失败: $e',
      );
    }
  }

  /// Exports accounts to JSON
  Future<void> exportAccountsToJSON() async {
    state = ExportState(
      status: ExportStatus.exporting,
      message: '正在导出账户...',
    );

    try {
      final result = await _exportService.exportAccountsToJSON();

      state = ExportState(
        status: ExportStatus.success,
        message: '导出成功！共导出 ${result.accountCount} 个账户',
        result: result,
      );
    } on ExportException catch (e) {
      state = ExportState(
        status: ExportStatus.error,
        message: e.message,
      );
    } catch (e) {
      state = ExportState(
        status: ExportStatus.error,
        message: '导出失败: $e',
      );
    }
  }

  /// Exports categories to JSON
  Future<void> exportCategoriesToJSON() async {
    state = ExportState(
      status: ExportStatus.exporting,
      message: '正在导出分类...',
    );

    try {
      final result = await _exportService.exportCategoriesToJSON();

      state = ExportState(
        status: ExportStatus.success,
        message: '导出成功！共导出 ${result.categoryCount} 个分类',
        result: result,
      );
    } on ExportException catch (e) {
      state = ExportState(
        status: ExportStatus.error,
        message: e.message,
      );
    } catch (e) {
      state = ExportState(
        status: ExportStatus.error,
        message: '导出失败: $e',
      );
    }
  }

  /// Exports full backup
  Future<void> exportFullBackup() async {
    state = ExportState(
      status: ExportStatus.exporting,
      message: '正在创建完整备份...',
    );

    try {
      final result = await _exportService.exportFullBackup();

      state = ExportState(
        status: ExportStatus.success,
        message: '备份成功！\n'
            '交易: ${result.transactionCount} 条\n'
            '账户: ${result.accountCount} 个\n'
            '分类: ${result.categoryCount} 个',
        result: result,
      );
    } on ExportException catch (e) {
      state = ExportState(
        status: ExportStatus.error,
        message: e.message,
      );
    } catch (e) {
      state = ExportState(
        status: ExportStatus.error,
        message: '备份失败: $e',
      );
    }
  }

  /// Shares the exported file
  Future<void> shareResult() async {
    final result = state.result;
    if (result == null) return;

    await _exportService.shareFile(
      result.filePath,
      subject: '财务数据导出 - ${result.format}',
    );
  }

  /// Resets the state
  void reset() {
    state = const ExportState();
  }
}

/// Import notifier for managing import operations
class ImportNotifier extends StateNotifier<ImportState> {
  final Ref _ref;
  late final ImportService _importService;

  ImportNotifier(this._ref) : super(const ImportState()) {
    final db = _ref.read(databaseProvider);
    _importService = ImportService(db);
  }

  /// Picks and validates a file for import
  Future<bool> pickAndValidateFile() async {
    state = ImportState(
      status: ImportStatus.validating,
      message: '正在选择文件...',
    );

    try {
      final filePath = await _importService.pickImportFile();

      if (filePath == null) {
        state = const ImportState();
        return false;
      }

      state = ImportState(
        status: ImportStatus.previewing,
        message: '正在解析文件...',
        filePath: filePath,
      );

      final preview = await _importService.getImportPreview(filePath);

      if (preview.errors.isNotEmpty) {
        state = ImportState(
          status: ImportStatus.error,
          message: preview.errors.first,
          preview: preview,
          filePath: filePath,
        );
        return false;
      }

      state = ImportState(
        status: ImportStatus.previewing,
        message: '文件解析成功',
        preview: preview,
        filePath: filePath,
      );

      return true;
    } catch (e) {
      state = ImportState(
        status: ImportStatus.error,
        message: '文件解析失败: $e',
      );
      return false;
    }
  }

  /// Validates CSV file format
  Future<CSVValidationResult?> validateCSV(String filePath) async {
    return await _importService.validateCSVFormat(filePath);
  }

  /// Imports transactions from CSV
  Future<void> importFromCSV({
    bool skipDuplicates = true,
    String? defaultAccountId,
    String? defaultCurrencyId,
  }) async {
    final filePath = state.filePath;
    if (filePath == null) return;

    state = state.copyWith(
      status: ImportStatus.importing,
      message: '正在导入交易记录...',
    );

    try {
      final result = await _importService.importTransactionsFromCSV(
        filePath,
        skipDuplicates: skipDuplicates,
        defaultAccountId: defaultAccountId,
        defaultCurrencyId: defaultCurrencyId,
      );

      if (result.hasErrors) {
        state = ImportState(
          status: ImportStatus.error,
          message: '导入完成，但有错误:\n${result.errors.take(5).join('\n')}',
          result: result,
        );
      } else {
        state = ImportState(
          status: ImportStatus.success,
          message: '导入成功！共导入 ${result.transactionsImported} 条交易记录',
          result: result,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: ImportStatus.error,
        message: '导入失败: $e',
      );
    }
  }

  /// Imports data from JSON
  Future<void> importFromJSON({
    bool skipDuplicates = true,
    bool mergeAccounts = false,
    bool mergeCategories = false,
  }) async {
    final filePath = state.filePath;
    if (filePath == null) return;

    state = state.copyWith(
      status: ImportStatus.importing,
      message: '正在导入数据...',
    );

    try {
      final result = await _importService.importFromJSON(
        filePath,
        skipDuplicates: skipDuplicates,
        mergeAccounts: mergeAccounts,
        mergeCategories: mergeCategories,
      );

      if (result.hasErrors) {
        state = ImportState(
          status: ImportStatus.error,
          message: '导入完成，但有错误:\n${result.errors.take(5).join('\n')}',
          result: result,
        );
      } else {
        final parts = <String>[];
        if (result.transactionsImported > 0) {
          parts.add('${result.transactionsImported} 条交易');
        }
        if (result.accountsImported > 0) {
          parts.add('${result.accountsImported} 个账户');
        }
        if (result.categoriesImported > 0) {
          parts.add('${result.categoriesImported} 个分类');
        }

        state = ImportState(
          status: ImportStatus.success,
          message: '导入成功！共导入 ${parts.join('、')}',
          result: result,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: ImportStatus.error,
        message: '导入失败: $e',
      );
    }
  }

  /// Resets the state
  void reset() {
    state = const ImportState();
  }
}

/// Provider for export state
final exportProvider = StateNotifierProvider<ExportNotifier, ExportState>((ref) {
  return ExportNotifier(ref);
});

/// Provider for import state
final importProvider = StateNotifierProvider<ImportNotifier, ImportState>((ref) {
  return ImportNotifier(ref);
});

/// Provider for export service
final exportServiceProvider = Provider<ExportService>((ref) {
  final db = ref.watch(databaseProvider);
  return ExportService(db);
});

/// Provider for import service
final importServiceProvider = Provider<ImportService>((ref) {
  final db = ref.watch(databaseProvider);
  return ImportService(db);
});
