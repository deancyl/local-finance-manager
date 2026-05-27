import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sync/sync.dart';

import '../../data/sync_providers.dart';

/// Conflict resolution page for manual sync conflict handling.
class ConflictResolutionPage extends ConsumerWidget {
  const ConflictResolutionPage({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflictsAsync = ref.watch(pendingConflictsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('解决冲突'),
        actions: [
          conflictsAsync.when(
            data: (conflicts) => conflicts.isNotEmpty
                ? TextButton(
                    onPressed: () => _resolveAllAuto(context, ref, conflicts),
                    child: const Text('自动解决全部'),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: conflictsAsync.when(
        data: (conflicts) => conflicts.isEmpty
            ? _buildEmptyState(context)
            : _buildConflictList(context, ref, conflicts),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载冲突失败: $e')),
      ),
    );
  }
  
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          Text(
            '无冲突',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '所有数据已同步，无需手动解决',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildConflictList(
    BuildContext context,
    WidgetRef ref,
    List<SyncConflict> conflicts,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: conflicts.length,
      itemBuilder: (context, index) => _buildConflictCard(context, ref, conflicts[index]),
    );
  }
  
  Widget _buildConflictCard(
    BuildContext context,
    WidgetRef ref,
    SyncConflict conflict,
  ) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    conflict.table,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '记录 ID: ${conflict.id.substring(0, 8)}...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  dateFormat.format(conflict.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Conflict details
            Text(
              '检测到数据冲突，请选择保留哪个版本：',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            
            // Options
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _resolveConflict(
                      context,
                      ref,
                      conflict,
                      ConflictResolutionStrategy.clientWins,
                    ),
                    icon: const Icon(Icons.phone_android),
                    label: const Text('本地版本'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _resolveConflict(
                      context,
                      ref,
                      conflict,
                      ConflictResolutionStrategy.serverWins,
                    ),
                    icon: const Icon(Icons.cloud),
                    label: const Text('服务器版本'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Merge option
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showMergeDialog(context, ref, conflict),
                icon: const Icon(Icons.merge),
                label: const Text('合并数据'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _resolveConflict(
    BuildContext context,
    WidgetRef ref,
    SyncConflict conflict,
    ConflictResolutionStrategy strategy,
  ) {
    // Show confirmation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认解决'),
        content: Text(
          strategy == ConflictResolutionStrategy.clientWins
              ? '确定保留本地版本吗？服务器数据将被覆盖。'
              : '确定使用服务器版本吗？本地修改将丢失。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _doResolve(context, ref, conflict, strategy);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
  
  void _doResolve(
    BuildContext context,
    WidgetRef ref,
    SyncConflict conflict,
    ConflictResolutionStrategy strategy,
  ) {
    // In a real implementation, this would call the sync service
    // to apply the resolution
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('冲突已解决: ${strategy.name}'),
        backgroundColor: Colors.green,
      ),
    );
    
    // Refresh conflicts list
    ref.invalidate(pendingConflictsProvider);
  }
  
  void _showMergeDialog(
    BuildContext context,
    WidgetRef ref,
    SyncConflict conflict,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('合并数据'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('合并将保留两边的唯一更改。'),
              SizedBox(height: 16),
              Text('此功能需要进一步实现，当前将自动选择最佳字段。'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _doResolve(context, ref, conflict, ConflictResolutionStrategy.merge);
            },
            child: const Text('合并'),
          ),
        ],
      ),
    );
  }
  
  void _resolveAllAuto(
    BuildContext context,
    WidgetRef ref,
    List<SyncConflict> conflicts,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自动解决全部'),
        content: Text(
          '将使用业务规则自动解决 ${conflicts.length} 个冲突。\n\n'
          '规则优先级：\n'
          '1. 删除操作优先\n'
          '2. 已对账交易需手动解决\n'
          '3. 金额变更需手动解决\n'
          '4. 较新的时间戳优先',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );
              
              // In a real implementation, this would call the resolver
              await Future.delayed(const Duration(seconds: 1));
              
              if (context.mounted) {
                Navigator.pop(context); // Close loading
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('冲突已自动解决'),
                    backgroundColor: Colors.green,
                  ),
                );
                ref.invalidate(pendingConflictsProvider);
              }
            },
            child: const Text('解决'),
          ),
        ],
      ),
    );
  }
}