import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:database/database.dart';
import '../../data/transaction_provider.dart';
import '../../../attachments/data/attachment_provider.dart';
import '../../../../core/presentation/widgets/gesture_controls.dart';
import '../../../../core/presentation/widgets/gesture_config_provider.dart';

class TransactionCard extends ConsumerWidget {
  final Transaction transaction;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onCategorize;
  final VoidCallback? onAddNote;
  final VoidCallback? onArchive;

  const TransactionCard({
    super.key,
    required this.transaction,
    required this.onTap,
    required this.onDelete,
    this.onEdit,
    this.onDuplicate,
    this.onCategorize,
    this.onAddNote,
    this.onArchive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splitsAsync = ref.watch(splitsForTransactionProvider(transaction.id));
    final attachmentCountAsync = ref.watch(attachmentCountProvider(transaction.id));
    final gestureConfig = ref.watch(gestureConfigProvider);

    return splitsAsync.when(
      data: (splits) {
        if (splits.isEmpty) return const SizedBox.shrink();
        final split = splits.first;
        final amount = split.valueNum / split.valueDenom;
        final isIncome = amount > 0;

        final card = Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Semantics(
            label: '${isIncome ? "收入" : "支出"}: ${transaction.description ?? "未分类交易"}',
            value: '¥${amount.abs().toStringAsFixed(2)}',
            hint: '点击查看详情，长按显示更多选项',
            button: true,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isIncome
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isIncome ? Colors.green : Colors.red,
                        semanticLabel: isIncome ? '收入' : '支出',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                transaction.description ?? '未分类交易',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              attachmentCountAsync.when(
                                data: (count) {
                                  if (count > 0) {
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Icon(
                                        Icons.attach_file,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                              ),
                            ],
                          ),
                          if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              transaction.notes!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('HH:mm').format(
                              DateTime.fromMillisecondsSinceEpoch(transaction.postDate),
                            ),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isIncome ? '+' : '-'}¥${amount.abs().toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isIncome ? Colors.green : Colors.red,
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: onDelete,
                          color: Theme.of(context).colorScheme.error,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: '删除交易',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        return SwipeableAction(
          leftAction: gestureConfig.swipeLeft,
          rightAction: gestureConfig.swipeRight,
          onLeftSwipe: _getActionCallback(gestureConfig.swipeLeft),
          onRightSwipe: _getActionCallback(gestureConfig.swipeRight),
          enableHapticFeedback: gestureConfig.enableHapticFeedback,
          threshold: gestureConfig.swipeThreshold,
          child: LongPressMenu(
            itemBuilder: (context) => GestureMenuItems.standardTransactionMenu(),
            onSelected: (action) => _handleMenuAction(action),
            enableHapticFeedback: gestureConfig.enableHapticFeedback,
            longPressDuration: gestureConfig.longPressDuration,
            child: DoubleTapAction(
              action: gestureConfig.doubleTap,
              onDoubleTap: _getActionCallback(gestureConfig.doubleTap),
              enableHapticFeedback: gestureConfig.enableHapticFeedback,
              child: card,
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  VoidCallback? _getActionCallback(GestureAction action) {
    switch (action) {
      case GestureAction.delete:
        return onDelete;
      case GestureAction.edit:
        return onEdit;
      case GestureAction.duplicate:
        return onDuplicate;
      case GestureAction.categorize:
        return onCategorize;
      case GestureAction.addNote:
        return onAddNote;
      case GestureAction.archive:
        return onArchive;
      case GestureAction.transfer:
      case GestureAction.none:
        return null;
    }
  }

  void _handleMenuAction(GestureAction action) {
    final callback = _getActionCallback(action);
    callback?.call();
  }
}
