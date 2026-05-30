import 'package:importers/importers.dart';

/// Error category for import errors.
enum ImportErrorCategory {
  format,      // File format errors
  encoding,    // Encoding detection/decoding errors
  validation,  // Data validation errors
  duplicate,   // Duplicate transaction errors
  permission,  // Permission/access errors
  system,      // System/unknown errors
}

/// Localized error message with Chinese and English support.
class ImportErrorMessage {
  final ImportErrorCategory category;
  final String messageZh;
  final String messageEn;
  final String? suggestionZh;
  final String? suggestionEn;
  final bool isActionable;

  const ImportErrorMessage({
    required this.category,
    required this.messageZh,
    required this.messageEn,
    this.suggestionZh,
    this.suggestionEn,
    this.isActionable = true,
  });

  /// Get message in specified locale.
  String getMessage(bool isZh) => isZh ? messageZh : messageEn;

  /// Get suggestion in specified locale.
  String? getSuggestion(bool isZh) => isZh ? suggestionZh : suggestionEn;

  /// Get full message with suggestion.
  String getFullMessage(bool isZh) {
    final message = getMessage(isZh);
    final suggestion = getSuggestion(isZh);
    if (suggestion != null) {
      return '$message\n\n$suggestion';
    }
    return message;
  }

  /// Get category icon name.
  String get categoryIcon {
    switch (category) {
      case ImportErrorCategory.format:
        return 'description';
      case ImportErrorCategory.encoding:
        return 'code';
      case ImportErrorCategory.validation:
        return 'warning';
      case ImportErrorCategory.duplicate:
        return 'content_copy';
      case ImportErrorCategory.permission:
        return 'lock';
      case ImportErrorCategory.system:
        return 'error';
    }
  }
}

/// Factory for creating localized import error messages.
class ImportErrorMessages {
  /// Whether to use Chinese locale.
  final bool isZh;

  ImportErrorMessages({this.isZh = true});

  /// Create error message for encoding error.
  static ImportErrorMessage encodingError({
    String? detectedEncoding,
    String? details,
  }) {
    return ImportErrorMessage(
      category: ImportErrorCategory.encoding,
      messageZh: '文件编码解析失败${detectedEncoding != null ? ' (检测到: $detectedEncoding)' : ''}',
      messageEn: 'File encoding decode failed${detectedEncoding != null ? ' (detected: $detectedEncoding)' : ''}',
      suggestionZh: '建议：\n'
          '1. 尝试用 Excel 打开后另存为 UTF-8 格式\n'
          '2. 在导入页面手动选择编码格式\n'
          '3. 如问题持续，请反馈给开发者',
      suggestionEn: 'Suggestions:\n'
          '1. Open with Excel and save as UTF-8\n'
          '2. Manually select encoding in import page\n'
          '3. Contact developer if issue persists',
    );
  }

  /// Create error message for format error.
  static ImportErrorMessage formatError({
    String? expectedFormat,
    String? details,
  }) {
    return ImportErrorMessage(
      category: ImportErrorCategory.format,
      messageZh: '文件格式不正确${expectedFormat != null ? '，期望: $expectedFormat' : ''}',
      messageEn: 'Invalid file format${expectedFormat != null ? ', expected: $expectedFormat' : ''}',
      suggestionZh: '支持的格式：\n'
          '• 支付宝、微信支付导出的 CSV/XLS/XLSX\n'
          '• 工商银行、建设银行、中国银行等导出的账单\n'
          '• 确保文件包含正确的表头行',
      suggestionEn: 'Supported formats:\n'
          '• Alipay, WeChat Pay CSV/XLS/XLSX exports\n'
          '• Bank statements from ICBC, CCB, BOC, etc.\n'
          '• Ensure file contains correct header row',
    );
  }

  /// Create error message for validation error.
  static ImportErrorMessage validationError({
    required String field,
    required int row,
    String? value,
  }) {
    return ImportErrorMessage(
      category: ImportErrorCategory.validation,
      messageZh: '第 $row 行数据验证失败: $field 字段无效',
      messageEn: 'Row $row validation failed: invalid $field field',
      suggestionZh: '请检查：\n'
          '• 日期格式是否正确 (如: 2024-01-15)\n'
          '• 金额是否为有效数字\n'
          '• 必填字段是否为空',
      suggestionEn: 'Please check:\n'
          '• Date format is correct (e.g., 2024-01-15)\n'
          '• Amount is a valid number\n'
          '• Required fields are not empty',
    );
  }

  /// Create error message for duplicate transaction.
  static ImportErrorMessage duplicateError({
    required int row,
    String? externalId,
  }) {
    return ImportErrorMessage(
      category: ImportErrorCategory.duplicate,
      messageZh: '第 $row 行为重复交易${externalId != null ? ' (ID: $externalId)' : ''}',
      messageEn: 'Row $row is a duplicate transaction${externalId != null ? ' (ID: $externalId)' : ''}',
      suggestionZh: '重复交易会被自动跳过，不影响导入结果',
      suggestionEn: 'Duplicates will be skipped automatically',
      isActionable: false,
    );
  }

  /// Create error message for permission error.
  static ImportErrorMessage permissionError() {
    return ImportErrorMessage(
      category: ImportErrorCategory.permission,
      messageZh: '文件访问权限不足',
      messageEn: 'Insufficient file access permission',
      suggestionZh: '请尝试：\n'
          '1. 将文件复制到"下载"目录\n'
          '2. 授予应用存储权限\n'
          '3. 重新选择文件',
      suggestionEn: 'Please try:\n'
          '1. Copy file to "Download" directory\n'
          '2. Grant storage permission to app\n'
          '3. Re-select the file',
    );
  }

  /// Create error message for file too large.
  static ImportErrorMessage fileTooLargeError({
    required int sizeMB,
    required int maxMB,
  }) {
    return ImportErrorMessage(
      category: ImportErrorCategory.format,
      messageZh: '文件过大 (${sizeMB}MB)，最大支持 ${maxMB}MB',
      messageEn: 'File too large (${sizeMB}MB), maximum supported: ${maxMB}MB',
      suggestionZh: '建议：\n'
          '1. 将账单分批导出\n'
          '2. 删除不需要的历史记录后重试',
      suggestionEn: 'Suggestions:\n'
          '1. Export records in smaller batches\n'
          '2. Remove unnecessary history and retry',
    );
  }

  /// Create error message for empty file.
  static ImportErrorMessage emptyFileError() {
    return ImportErrorMessage(
      category: ImportErrorCategory.format,
      messageZh: '文件中没有可导入的数据',
      messageEn: 'No importable data in file',
      suggestionZh: '请确保：\n'
          '• 文件包含交易记录\n'
          '• 表头和数据行正确对应',
      suggestionEn: 'Please ensure:\n'
          '• File contains transaction records\n'
          '• Headers and data rows are correctly aligned',
    );
  }

  /// Create error message for missing account.
  static ImportErrorMessage missingAccountError() {
    return ImportErrorMessage(
      category: ImportErrorCategory.validation,
      messageZh: '请先选择目标账户',
      messageEn: 'Please select a target account first',
      suggestionZh: '在导入前选择或创建一个账户',
      suggestionEn: 'Select or create an account before importing',
    );
  }

  /// Create error message for unknown error.
  static ImportErrorMessage unknownError(String error) {
    return ImportErrorMessage(
      category: ImportErrorCategory.system,
      messageZh: '导入过程中发生错误',
      messageEn: 'An error occurred during import',
      suggestionZh: '错误详情: $error\n\n如问题持续，请联系开发者',
      suggestionEn: 'Error details: $error\n\nContact developer if issue persists',
    );
  }

  /// Parse error from exception and return localized message.
  static ImportErrorMessage fromException(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Encoding errors
    if (errorString.contains('gbk') || 
        errorString.contains('encoding') ||
        errorString.contains('codec') ||
        errorString.contains('decode')) {
      return encodingError(details: error.toString());
    }
    
    // Permission errors
    if (errorString.contains('permission') ||
        errorString.contains('access') ||
        errorString.contains('denied')) {
      return permissionError();
    }
    
    // Format errors
    if (errorString.contains('format') ||
        errorString.contains('header') ||
        errorString.contains('column')) {
      return formatError(details: error.toString());
    }
    
    // Unknown error
    return unknownError(error.toString());
  }

  /// Get validation warning message.
  static ImportErrorMessage validationWarning({
    required int warningCount,
    required int duplicateCount,
  }) {
    return ImportErrorMessage(
      category: ImportErrorCategory.validation,
      messageZh: '发现 $warningCount 条警告，$duplicateCount 条重复',
      messageEn: 'Found $warningCount warnings, $duplicateCount duplicates',
      suggestionZh: '警告的交易可以导入，重复的交易将被跳过',
      suggestionEn: 'Warning transactions can be imported, duplicates will be skipped',
      isActionable: false,
    );
  }
}

/// Validation result for import preview.
class ImportValidationResult {
  final List<ValidationError> errors;
  final List<ValidationWarning> warnings;
  final List<int> duplicateRowIndices;
  final int totalRows;
  final int validRows;
  final String detectedEncoding;
  final double encodingConfidence;

  const ImportValidationResult({
    this.errors = const [],
    this.warnings = const [],
    this.duplicateRowIndices = const [],
    this.totalRows = 0,
    this.validRows = 0,
    this.detectedEncoding = 'utf-8',
    this.encodingConfidence = 1.0,
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasDuplicates => duplicateRowIndices.isNotEmpty;
  bool get canImport => errors.isEmpty && validRows > 0;
  
  int get errorCount => errors.length;
  int get warningCount => warnings.length;
  int get duplicateCount => duplicateRowIndices.length;
  
  double get successRate => 
      totalRows > 0 ? validRows / totalRows : 0;
}

/// Validation error for a specific field/row.
class ValidationError {
  final int row;
  final String field;
  final String messageZh;
  final String messageEn;

  const ValidationError({
    required this.row,
    required this.field,
    required this.messageZh,
    required this.messageEn,
  });
  
  String getMessage(bool isZh) => isZh ? messageZh : messageEn;
}

/// Validation warning for a specific issue.
class ValidationWarning {
  final int? row;
  final String messageZh;
  final String messageEn;
  final bool isDuplicate;

  const ValidationWarning({
    this.row,
    required this.messageZh,
    required this.messageEn,
    this.isDuplicate = false,
  });
  
  String getMessage(bool isZh) => isZh ? messageZh : messageEn;
}
