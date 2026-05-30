import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reusable error state widget.
///
/// Displays a centered error icon with message and retry button.
/// Use this for consistent error state UI across the app.
class ErrorStateWidget extends StatelessWidget {
  /// Error message to display
  final String? message;

  /// Optional title (defaults to "加载失败")
  final String? title;

  /// Retry button callback
  final VoidCallback? onRetry;

  /// Retry button text (defaults to "重试")
  final String? retryText;

  /// Optional custom icon
  final IconData? icon;

  /// Optional custom icon color
  final Color? iconColor;

  /// Whether to show the full error details
  final bool showDetails;

  /// Optional error object for debugging
  final Object? error;

  const ErrorStateWidget({
    super.key,
    this.message,
    this.title,
    this.onRetry,
    this.retryText,
    this.icon,
    this.iconColor,
    this.showDetails = false,
    this.error,
  });

  /// Factory for network errors
  factory ErrorStateWidget.network({
    Key? key,
    VoidCallback? onRetry,
  }) {
    return ErrorStateWidget(
      key: key,
      icon: Icons.wifi_off_outlined,
      title: '网络连接失败',
      message: '请检查网络连接后重试',
      onRetry: onRetry,
    );
  }

  /// Factory for database errors
  factory ErrorStateWidget.database({
    Key? key,
    String? message,
    VoidCallback? onRetry,
  }) {
    return ErrorStateWidget(
      key: key,
      icon: Icons.storage_outlined,
      title: '数据库错误',
      message: message ?? '无法读取数据',
      onRetry: onRetry,
    );
  }

  /// Factory for permission errors
  factory ErrorStateWidget.permission({
    Key? key,
    String? message,
    VoidCallback? onRetry,
  }) {
    return ErrorStateWidget(
      key: key,
      icon: Icons.lock_outline,
      title: '权限不足',
      message: message ?? '请授予必要的权限',
      onRetry: onRetry,
    );
  }

  /// Factory for not found errors
  factory ErrorStateWidget.notFound({
    Key? key,
    String? message,
    VoidCallback? onRetry,
  }) {
    return ErrorStateWidget(
      key: key,
      icon: Icons.search_off,
      title: '未找到内容',
      message: message ?? '请求的资源不存在',
      onRetry: onRetry,
    );
  }

  /// Factory for generic/unknown errors
  factory ErrorStateWidget.generic({
    Key? key,
    String? message,
    Object? error,
    VoidCallback? onRetry,
  }) {
    return ErrorStateWidget(
      key: key,
      title: '出错了',
      message: message,
      error: error,
      onRetry: onRetry,
    );
  }

  /// Factory for file errors
  factory ErrorStateWidget.file({
    Key? key,
    String? message,
    VoidCallback? onRetry,
    String? retryText,
  }) {
    return ErrorStateWidget(
      key: key,
      icon: Icons.folder_off_outlined,
      title: '文件错误',
      message: message,
      onRetry: onRetry,
      retryText: retryText ?? '选择其他文件',
    );
  }

  /// Factory from AsyncValue error
  factory ErrorStateWidget.fromError({
    Key? key,
    required Object error,
    StackTrace? stackTrace,
    VoidCallback? onRetry,
  }) {
    String message;
    IconData icon = Icons.error_outline;

    // Parse common error types
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') ||
        errorString.contains('socket') ||
        errorString.contains('connection')) {
      return ErrorStateWidget.network(key: key, onRetry: onRetry);
    }

    if (errorString.contains('database') ||
        errorString.contains('sql') ||
        errorString.contains('drift')) {
      return ErrorStateWidget.database(key: key, onRetry: onRetry);
    }

    if (errorString.contains('permission') ||
        errorString.contains('denied')) {
      return ErrorStateWidget.permission(key: key, onRetry: onRetry);
    }

    if (errorString.contains('not found') ||
        errorString.contains('404')) {
      return ErrorStateWidget.notFound(key: key, onRetry: onRetry);
    }

    // Extract meaningful message from error
    message = error.toString();
    if (message.startsWith('Exception: ')) {
      message = message.substring(11);
    }

    return ErrorStateWidget(
      key: key,
      icon: icon,
      title: '加载失败',
      message: message,
      error: error,
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.error;
    final effectiveTitle = title ?? '加载失败';
    final effectiveRetryText = retryText ?? '重试';
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: effectiveIconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.error_outline,
                size: 48,
                color: effectiveIconColor,
              ),
            ),
            const SizedBox(height: 16),
            
            // Title
            Text(
              effectiveTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                color: effectiveIconColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Message
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            
            // Error details (for debugging)
            if (showDetails && error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  error.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            
            // Retry button
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(effectiveRetryText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Animated error state widget with shake effect.
class AnimatedErrorStateWidget extends StatefulWidget {
  final String? message;
  final String? title;
  final VoidCallback? onRetry;
  final String? retryText;
  final IconData? icon;
  final Duration animationDuration;

  const AnimatedErrorStateWidget({
    super.key,
    this.message,
    this.title,
    this.onRetry,
    this.retryText,
    this.icon,
    this.animationDuration = const Duration(milliseconds: 600),
  });

  @override
  State<AnimatedErrorStateWidget> createState() => _AnimatedErrorStateWidgetState();
}

class _AnimatedErrorStateWidgetState extends State<AnimatedErrorStateWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Transform.translate(
            offset: Offset(_shakeAnimation.value, 0),
            child: ErrorStateWidget(
              message: widget.message,
              title: widget.title,
              onRetry: widget.onRetry,
              retryText: widget.retryText,
              icon: widget.icon,
            ),
          ),
        );
      },
    );
  }
}

/// Compact inline error widget for use in lists or cards.
class InlineErrorWidget extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const InlineErrorWidget({
    super.key,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message ?? '加载失败',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onErrorContainer,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 32),
              ),
              child: const Text('重试'),
            ),
        ],
      ),
    );
  }
}

/// Error banner for top of screen/page.
class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;
  final VoidCallback? onRetry;

  const ErrorBanner({
    super.key,
    required this.message,
    this.onDismiss,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Material(
      color: theme.colorScheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 20,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
              if (onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onErrorContainer,
                  ),
                  child: const Text('重试'),
                ),
              if (onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close, size: 20),
                  color: theme.colorScheme.onErrorContainer,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper class for animated builder
class AnimatedBuilder extends AnimatedWidget {
  final Widget child;
  final Widget Function(BuildContext context, Widget? child) builder;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    required this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
