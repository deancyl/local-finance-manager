import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

/// Backup state
enum BackupStatus {
  idle,
  exporting,
  importing,
  success,
  error,
}

/// Backup state class
class BackupState {
  final BackupStatus status;
  final String? message;
  final String? filePath;

  BackupState({
    this.status = BackupStatus.idle,
    this.message,
    this.filePath,
  });

  BackupState copyWith({
    BackupStatus? status,
    String? message,
    String? filePath,
  }) {
    return BackupState(
      status: status ?? this.status,
      message: message ?? this.message,
      filePath: filePath ?? this.filePath,
    );
  }
}

/// Notifier for backup operations
class BackupNotifier extends StateNotifier<BackupState> {
  final Ref ref;

  BackupNotifier(this.ref) : super(BackupState());

  /// Export all data to JSON file
  Future<void> exportData(Map<String, dynamic> data) async {
    state = BackupState(status: BackupStatus.exporting, message: '正在导出数据...');

    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'finance_backup_$timestamp.json';

      // Get directory for saving
      String? filePath;

      if (Platform.isAndroid || Platform.isIOS) {
        // On mobile, use app documents directory
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
        filePath = file.path;

        // Share the file
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: '财务数据备份 $timestamp',
        );
      } else {
        // On desktop, use file picker to select save location
        final result = await FilePicker.platform.saveFile(
          dialogTitle: '保存备份文件',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['json'],
        );

        if (result != null) {
          final file = File(result);
          await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
          filePath = result;
        } else {
          state = BackupState(status: BackupStatus.idle);
          return;
        }
      }

      state = BackupState(
        status: BackupStatus.success,
        message: '数据导出成功',
        filePath: filePath,
      );
    } catch (e) {
      state = BackupState(
        status: BackupStatus.error,
        message: '导出失败: $e',
      );
    }
  }

  /// Import data from JSON file
  Future<Map<String, dynamic>?> importData() async {
    state = BackupState(status: BackupStatus.importing, message: '正在选择文件...');

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '选择备份文件',
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        state = BackupState(status: BackupStatus.idle);
        return null;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        state = BackupState(status: BackupStatus.error, message: '无法获取文件路径');
        return null;
      }

      final file = File(filePath);
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      state = BackupState(
        status: BackupStatus.success,
        message: '文件读取成功',
        filePath: filePath,
      );

      return data;
    } catch (e) {
      state = BackupState(
        status: BackupStatus.error,
        message: '导入失败: $e',
      );
      return null;
    }
  }

  /// Reset state
  void reset() {
    state = BackupState();
  }
}

/// Provider for backup state
final backupProvider = StateNotifierProvider<BackupNotifier, BackupState>((ref) {
  return BackupNotifier(ref);
});
