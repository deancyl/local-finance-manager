// DISABLED: sync package is temporarily disabled
/*
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sync/sync.dart';
import '../../data/sync_provider.dart';
import '../widgets/sync_status_card.dart';
import '../widgets/device_list_tile.dart';
import 'sync_login_page.dart';

/// Sync settings page.
/// 
/// Provides UI for configuring sync server, viewing sync status,
/// managing devices, and triggering manual sync operations.
class SyncSettingsPage extends ConsumerWidget {
  const SyncSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(syncStatusProvider);
    final progressAsync = ref.watch(syncProgressProvider);
    final devicesAsync = ref.watch(registeredDevicesProvider);
    final isConfigured = ref.watch(isSyncEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('同步设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Server configuration section
          _buildServerConfigSection(context, ref, isConfigured),
          
          const SizedBox(height: 24),
          
          // Sync status card
          SyncStatusCard(
            status: statusAsync,
            progress: progressAsync,
          ),
          
          const SizedBox(height: 24),
          
          // Sync actions
          _buildSyncActionsSection(context, ref, statusAsync),
          
          const SizedBox(height: 24),
          
          // Registered devices
          _buildDevicesSection(context, ref, devicesAsync),
          
          const SizedBox(height: 24),
          
          // Logout button (if authenticated)
          if (isConfigured) _buildLogoutSection(context, ref),
        ],
      ),
    );
  }

  Widget _buildServerConfigSection(
    BuildContext context,
    WidgetRef ref,
    bool isConfigured,
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
                  Icons.dns,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '服务器配置',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (!isConfigured) ...[
              Text(
                '尚未配置同步服务器',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.go('/settings/sync/login'),
                icon: const Icon(Icons.login),
                label: const Text('登录 / 注册'),
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('服务器地址'),
                subtitle: const Text('已配置'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showServerUrlDialog(context, ref),
                ),
              ),
            ],
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
              loading: () => const Center(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
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

  Widget _buildLogoutSection(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.logout,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(
          '退出登录',
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        subtitle: const Text('清除同步配置并退出'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showLogoutDialog(context, ref),
      ),
    );
  }

  void _showServerUrlDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改服务器地址'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '服务器 URL',
            hintText: 'https://sync.example.com',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              // Save new server URL
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('服务器地址已更新')),
              );
            },
            child: const Text('保存'),
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

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出同步账户吗？这将清除所有同步配置。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Logout and clear config
              await SyncConfig.clearStorage();
              ref.invalidate(syncConfigProvider);
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已退出登录')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}
*/