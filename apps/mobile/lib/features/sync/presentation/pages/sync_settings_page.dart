import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sync/sync.dart';
import '../../data/sync_feature_flag.dart';
import '../../data/sync_providers.dart';
import '../widgets/sync_status_card.dart';
import '../widgets/device_list_tile.dart';

/// Sync settings page with feature flag support.
/// 
/// Provides UI for:
/// - Enabling/disabling sync feature
/// - Viewing compatibility status
/// - Viewing diagnostic information
/// - Managing sync connections
class SyncSettingsPage extends ConsumerWidget {
  const SyncSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(syncFeatureFlagProvider);
    final diagnosticAsync = ref.watch(syncDiagnosticProvider);
    final canEnableAsync = ref.watch(canEnableSyncProvider);
    final statusAsync = ref.watch(syncStatusProvider);
    final devicesAsync = ref.watch(registeredDevicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('同步设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Feature toggle section
          _buildFeatureToggleSection(context, ref, isEnabled, canEnableAsync),
          
          const SizedBox(height: 24),
          
          // Compatibility status (shown when trying to enable)
          if (!isEnabled) ...[
            _buildCompatibilitySection(context, ref, canEnableAsync),
            const SizedBox(height: 24),
          ],
          
          // Sync status card (only shown when enabled)
          if (isEnabled) ...[
            SyncStatusCard(
              status: statusAsync,
              progress: ref.watch(syncProgressProvider),
            ),
            const SizedBox(height: 24),
          ],
          
          // Sync actions (only shown when enabled)
          if (isEnabled) ...[
            _buildSyncActionsSection(context, ref, statusAsync),
            const SizedBox(height: 24),
          ],
          
          // Registered devices (only shown when enabled)
          if (isEnabled) ...[
            _buildDevicesSection(context, ref, devicesAsync),
            const SizedBox(height: 24),
          ],
          
          // Diagnostic info
          _buildDiagnosticSection(context, ref, diagnosticAsync),
        ],
      ),
    );
  }

  Widget _buildFeatureToggleSection(
    BuildContext context,
    WidgetRef ref,
    bool isEnabled,
    AsyncValue<SyncEnableCheckResult> canEnableAsync,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sync,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '同步功能',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch(
                  value: isEnabled,
                  onChanged: (value) async {
                    if (value) {
                      // Check if we can enable sync
                      final canEnable = await ref.read(canEnableSyncProvider.future);
                      if (canEnable.canEnable) {
                        await ref.read(syncFeatureFlagProvider.notifier).setEnabled(true);
                      } else {
                        // Show dialog explaining why sync cannot be enabled
                        if (context.mounted) {
                          _showCannotEnableDialog(context, canEnable);
                        }
                      }
                    } else {
                      await ref.read(syncFeatureFlagProvider.notifier).setEnabled(false);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isEnabled 
                  ? '同步功能已启用，可以跨设备同步数据'
                  : '同步功能已禁用，数据仅存储在本地',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (!isEnabled) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '启用同步前需要检查系统兼容性',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompatibilitySection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<SyncEnableCheckResult> canEnableAsync,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '兼容性检查',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            canEnableAsync.when(
              data: (result) {
                if (result.canEnable) {
                  return Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '系统兼容，可以启用同步功能',
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '存在兼容性问题',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (result.reason != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          result.reason!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  );
                }
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Text(
                '检查失败: $error',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncActionsSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<SyncStatus> statusAsync,
  ) {
    final isConnected = statusAsync.when(
      data: (status) => status == SyncStatus.connected,
      loading: () => false,
      error: (_, __) => false,
    );

    final isSyncing = statusAsync.when(
      data: (status) => status == SyncStatus.connecting,
      loading: () => true,
      error: (_, __) => false,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sync,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '同步操作',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isConnected && !isSyncing
                        ? () => _triggerSync(context, ref)
                        : null,
                    icon: isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: const Text('立即同步'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isConnected
                        ? () => _disconnect(context, ref)
                        : () => _connect(context, ref),
                    icon: Icon(
                      isConnected ? Icons.link_off : Icons.link,
                    ),
                    label: Text(
                      isConnected ? '断开连接' : '连接',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<SyncDevice>> devicesAsync,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.devices,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '已注册设备',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            devicesAsync.when(
              data: (devices) {
                if (devices.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.devices_other,
                            size: 48,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '暂无其他设备',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                return Column(
                  children: devices.map((device) => 
                    DeviceListTile(device: device)
                  ).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    '加载设备列表失败: $error',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            ),
            
            const Divider(height: 32),
            
            // Device pairing button
            ListTile(
              leading: const Icon(Icons.devices),
              title: const Text('配对设备'),
              subtitle: const Text('使用二维码添加新设备'),
              onTap: () => context.go('/settings/sync/pairing'),
            ),
            
            // Offline queue button
            ListTile(
              leading: const Icon(Icons.pending_actions),
              title: const Text('查看离线队列'),
              subtitle: const Text('查看待同步数据'),
              onTap: () => context.go('/settings/sync/queue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<SyncDiagnosticReport?> diagnosticAsync,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '诊断信息',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            diagnosticAsync.when(
              data: (report) {
                if (report == null) {
                  return Text(
                    '同步功能未启用，无法获取诊断信息',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDiagnosticItem(
                      context,
                      'PowerSync',
                      report.powerSyncAvailable,
                    ),
                    _buildDiagnosticItem(
                      context,
                      'Schema',
                      report.schemaCompatible,
                    ),
                    _buildDiagnosticItem(
                      context,
                      'Network',
                      report.networkConnected,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      report.summary,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Text(
                '获取诊断信息失败: $error',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticItem(
    BuildContext context,
    String name,
    bool success,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle : Icons.cancel,
            size: 20,
            color: success ? Colors.green : Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Text(name),
        ],
      ),
    );
  }

  void _showCannotEnableDialog(
    BuildContext context,
    SyncEnableCheckResult result,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('无法启用同步'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.reason ?? '存在兼容性问题'),
            if (result.diagnosticReport != null) ...[
              const SizedBox(height: 16),
              Text(
                '失败的检查项:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...result.diagnosticReport!.failedChecks.map(
                (check) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.close, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(check.checkName)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _triggerSync(BuildContext context, WidgetRef ref) {
    ref.read(syncNotifierProvider.notifier).sync();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在同步...')),
    );
  }

  void _connect(BuildContext context, WidgetRef ref) {
    ref.read(syncNotifierProvider.notifier).connect();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在连接...')),
    );
  }

  void _disconnect(BuildContext context, WidgetRef ref) {
    ref.read(syncNotifierProvider.notifier).disconnect();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已断开连接')),
    );
  }
}
