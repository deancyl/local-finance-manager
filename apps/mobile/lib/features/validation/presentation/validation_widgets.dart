import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/validation_provider.dart';

/// Widget to display validation issues
class ValidationIssuesWidget extends StatelessWidget {
  final ValidationResult result;
  final bool showWarnings;
  final bool showInfos;
  final VoidCallback? onDismiss;

  const ValidationIssuesWidget({
    super.key,
    required this.result,
    this.showWarnings = true,
    this.showInfos = false,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final allIssues = [
      ...result.errors,
      if (showWarnings) ...result.warnings,
      if (showInfos) ...result.infos,
    ];

    if (allIssues.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(8),
      color: result.isValid
          ? Colors.orange.shade50
          : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  result.isValid ? Icons.warning : Icons.error,
                  color: result.isValid
                      ? Colors.orange.shade700
                      : Colors.red.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  result.isValid ? '警告' : '验证错误',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: result.isValid
                        ? Colors.orange.shade700
                        : Colors.red.shade700,
                  ),
                ),
                if (onDismiss != null) ...[
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onDismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Issues list
            ...allIssues.map((issue) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _getSeverityIcon(issue.severity),
                    color: _getSeverityColor(issue.severity),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          issue.message,
                          style: TextStyle(
                            fontSize: 13,
                            color: _getSeverityColor(issue.severity),
                          ),
                        ),
                        if (issue.field != null)
                          Text(
                            '字段: ${issue.field}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
            
            if (!result.isValid)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '请修复错误后再继续',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getSeverityColor(ValidationSeverity severity) {
    switch (severity) {
      case ValidationSeverity.error:
        return Colors.red.shade700;
      case ValidationSeverity.warning:
        return Colors.orange.shade700;
      case ValidationSeverity.info:
        return Colors.blue.shade700;
    }
  }

  IconData _getSeverityIcon(ValidationSeverity severity) {
    switch (severity) {
      case ValidationSeverity.error:
        return Icons.error_outline;
      case ValidationSeverity.warning:
        return Icons.warning_amber;
      case ValidationSeverity.info:
        return Icons.info_outline;
    }
  }
}

/// Dialog for showing validation issues with options
class ValidationDialog extends StatelessWidget {
  final ValidationResult result;
  final String title;
  final VoidCallback? onFixErrors;
  final VoidCallback? onOverrideWarnings;

  const ValidationDialog({
    super.key,
    required this.result,
    required this.title,
    this.onFixErrors,
    this.onOverrideWarnings,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            result.isValid ? Icons.warning : Icons.error,
            color: result.isValid ? Colors.orange : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: ValidationIssuesWidget(
          result: result,
          showWarnings: true,
          showInfos: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        if (!result.isValid && onFixErrors != null)
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onFixErrors!();
            },
            child: const Text('修复错误'),
          ),
        if (result.isValid && result.warnings.isNotEmpty && onOverrideWarnings != null)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            onPressed: () {
              Navigator.of(context).pop(true);
              onOverrideWarnings!();
            },
            child: const Text('忽略警告继续'),
          ),
      ],
    );
  }

  /// Shows the validation dialog and returns whether to proceed
  static Future<bool?> show(
    BuildContext context,
    ValidationResult result,
    String title,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ValidationDialog(
        result: result,
        title: title,
      ),
    );
  }
}

/// Snackbar for showing validation errors
class ValidationSnackbar {
  static void showErrors(BuildContext context, ValidationResult result) {
    if (result.errors.isEmpty) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '发现 ${result.errors.length} 个错误',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              result.errors.map((e) => e.message).join('\n'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '查看',
          textColor: Colors.white,
          onPressed: () {
            ValidationDialog.show(context, result, '验证错误');
          },
        ),
      ),
    );
  }

  static void showWarnings(BuildContext context, ValidationResult result) {
    if (result.warnings.isEmpty) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '警告: ${result.warnings.first.message}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// Validation indicator for forms
class ValidationIndicator extends StatelessWidget {
  final ValidationResult? result;
  final bool isValidating;

  const ValidationIndicator({
    super.key,
    this.result,
    this.isValidating = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isValidating) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (result == null) {
      return const SizedBox.shrink();
    }

    if (result!.isValid && result!.warnings.isEmpty) {
      return Icon(
        Icons.check_circle,
        color: Colors.green,
        size: 20,
      );
    }

    if (!result!.isValid) {
      return Icon(
        Icons.error,
        color: Colors.red,
        size: 20,
      );
    }

    return Icon(
      Icons.warning,
      color: Colors.orange,
      size: 20,
    );
  }
}

/// Field-level validation indicator
class FieldValidationIndicator extends StatelessWidget {
  final String? field;
  final ValidationResult result;

  const FieldValidationIndicator({
    super.key,
    required this.field,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    if (field == null) return const SizedBox.shrink();

    final fieldIssues = result.issues.where((i) => i.field == field).toList();
    
    if (fieldIssues.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasError = fieldIssues.any((i) => i.severity == ValidationSeverity.error);
    
    return Tooltip(
      message: fieldIssues.map((i) => i.message).join('\n'),
      child: Icon(
        hasError ? Icons.error_outline : Icons.warning_amber,
        color: hasError ? Colors.red : Colors.orange,
        size: 18,
      ),
    );
  }
}