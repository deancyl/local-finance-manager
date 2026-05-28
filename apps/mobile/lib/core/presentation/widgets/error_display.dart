import 'package:flutter/material.dart';
import 'error_message_mapper.dart';

/// Centralized error display widget for user-friendly error messages.
/// 
/// Provides consistent error UI across the app with:
/// - User-friendly Chinese messages
/// - Retry action support
/// - Dismiss functionality
class ErrorDisplay extends StatelessWidget {
  /// The error to display
  final Object error;
  
  /// Optional callback for retry action
  final VoidCallback? onRetry;
  
  /// Optional callback for dismiss action
  final VoidCallback? onDismiss;
  
  /// Whether to show the error icon
  final bool showIcon;
  
  /// Custom error message (overrides automatic mapping)
  final String? customMessage;
  
  /// Whether to use compact layout
  final bool compact;

  const ErrorDisplay({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
    this.showIcon = true,
    this.customMessage,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final message = customMessage ?? ErrorMessageMapper.map(error);
    final errorType = ErrorMessageMapper.getErrorType(error);
    
    if (compact) {
      return _buildCompact(context, message);
    }
    
    return _buildFull(context, message, errorType);
  }

  Widget _buildFull(BuildContext context, String message, AppErrorType errorType) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (showIcon) ...[
                  Icon(
                    _getIconForErrorType(errorType),
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTitleForErrorType(errorType),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onDismiss,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    tooltip: '关闭',
                  ),
              ],
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
              size: 16,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForErrorType(AppErrorType type) {
    return switch (type) {
      AppErrorType.network => Icons.wifi_off,
      AppErrorType.auth => Icons.lock_outline,
      AppErrorType.database => Icons.storage_outlined,
      AppErrorType.validation => Icons.warning_amber,
      AppErrorType.timeout => Icons.timer_off,
      AppErrorType.server => Icons.cloud_off,
      AppErrorType.conflict => Icons.sync_problem,
      AppErrorType.unknown => Icons.error_outline,
    };
  }

  String _getTitleForErrorType(AppErrorType type) {
    return switch (type) {
      AppErrorType.network => '网络错误',
      AppErrorType.auth => '认证错误',
      AppErrorType.database => '数据错误',
      AppErrorType.validation => '验证错误',
      AppErrorType.timeout => '请求超时',
      AppErrorType.server => '服务器错误',
      AppErrorType.conflict => '数据冲突',
      AppErrorType.unknown => '操作失败',
    };
  }
}

/// Error display for empty states with optional retry
class EmptyStateError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData? icon;

  const EmptyStateError({
    super.key,
    required this.message,
    this.onRetry,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.inbox_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
