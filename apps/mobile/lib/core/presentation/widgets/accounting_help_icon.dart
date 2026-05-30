import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/accounting_glossary.dart';

/// Help icon widget for accounting terminology.
///
/// Features:
/// - Info icon (ℹ️) that users can tap or long-press
/// - Shows tooltip on tap
/// - Shows bottom sheet with detailed explanation on long-press
/// - Supports both Chinese and English
/// - Accessible via semantic labels
class AccountingHelpIcon extends StatelessWidget {
  /// The glossary entry to display
  final GlossaryEntry entry;
  
  /// Whether to show Chinese (true) or English (false)
  final bool showChinese;
  
  /// Icon size (defaults to 18)
  final double iconSize;
  
  /// Custom icon color (defaults to theme's primary color)
  final Color? iconColor;

  const AccountingHelpIcon({
    super.key,
    required this.entry,
    this.showChinese = true,
    this.iconSize = 18,
    this.iconColor,
  });

  /// Create help icon from glossary key.
  factory AccountingHelpIcon.fromKey({
    Key? key,
    required String glossaryKey,
    bool showChinese = true,
    double iconSize = 18,
    Color? iconColor,
  }) {
    final entry = AccountingGlossary.getByKey(glossaryKey);
    if (entry == null) {
      throw ArgumentError('Unknown glossary key: $glossaryKey');
    }
    return AccountingHelpIcon(
      key: key,
      entry: entry,
      showChinese: showChinese,
      iconSize: iconSize,
      iconColor: iconColor,
    );
  }

  /// Create help icon from account type.
  factory AccountingHelpIcon.fromAccountType({
    Key? key,
    required String accountType,
    bool showChinese = true,
    double iconSize = 18,
    Color? iconColor,
  }) {
    final entry = AccountingGlossary.getByAccountType(accountType);
    if (entry == null) {
      throw ArgumentError('Unknown account type: $accountType');
    }
    return AccountingHelpIcon(
      key: key,
      entry: entry,
      showChinese: showChinese,
      iconSize: iconSize,
      iconColor: iconColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = iconColor ?? theme.colorScheme.primary;
    
    return Semantics(
      label: showChinese 
          ? '${entry.nameZh} 帮助信息'
          : '${entry.nameEn} help information',
      hint: '长按查看详细说明',
      button: true,
      child: GestureDetector(
        onTap: () => _showTooltip(context),
        onLongPress: () => _showBottomSheet(context),
        child: Container(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.info_outline,
            size: iconSize,
            color: color,
          ),
        ),
      ),
    );
  }

  /// Show simple tooltip on tap.
  void _showTooltip(BuildContext context) {
    HapticFeedback.lightImpact();
    
    final message = showChinese ? entry.explanationZh : entry.explanationEn;
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Show detailed bottom sheet on long-press.
  void _showBottomSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GlossaryBottomSheet(
        entry: entry,
        showChinese: showChinese,
      ),
    );
  }
}

/// Bottom sheet showing detailed glossary explanation.
class _GlossaryBottomSheet extends StatelessWidget {
  final GlossaryEntry entry;
  final bool showChinese;

  const _GlossaryBottomSheet({
    required this.entry,
    required this.showChinese,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Header with icon
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _parseColor(entry.iconColor).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIconData(entry.iconData),
                  color: _parseColor(entry.iconColor),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showChinese ? entry.nameZh : entry.nameEn,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      showChinese ? entry.nameEn : entry.nameZh,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Simple explanation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    showChinese ? entry.explanationZh : entry.explanationEn,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Detailed explanation
          if ((showChinese ? entry.detailZh : entry.detailEn) != null) ...[
            const SizedBox(height: 16),
            Text(
              '详细说明',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              showChinese ? entry.detailZh! : entry.detailEn!,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Close button
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: () => Navigator.pop(context),
              child: const Text('了解了'),
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(
        int.parse(hexColor.replaceFirst('#', '0xFF')),
      );
    } catch (_) {
      return Colors.blue;
    }
  }

  IconData _getIconData(IconDataData data) {
    // Map icon names to Flutter icons
    switch (data.name) {
      case 'arrow_forward':
        return Icons.arrow_forward;
      case 'arrow_back':
        return Icons.arrow_back;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      case 'credit_card':
        return Icons.credit_card;
      case 'pie_chart':
        return Icons.pie_chart;
      case 'trending_up':
        return Icons.trending_up;
      case 'shopping_cart':
        return Icons.shopping_cart;
      default:
        return Icons.info_outline;
    }
  }
}

/// Extension for easy widget creation.
extension AccountingHelpIconExtension on Widget {
  /// Add help icon next to this widget.
  Widget withAccountingHelp({
    required String glossaryKey,
    bool showChinese = true,
    double iconSize = 18,
    Color? iconColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        this,
        const SizedBox(width: 4),
        AccountingHelpIcon.fromKey(
          glossaryKey: glossaryKey,
          showChinese: showChinese,
          iconSize: iconSize,
          iconColor: iconColor,
        ),
      ],
    );
  }
}
