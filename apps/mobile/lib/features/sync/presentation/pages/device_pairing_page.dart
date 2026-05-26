import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sync/sync.dart';

import '../../data/sync_providers.dart';
import '../../data/sync_feature_flag.dart';
import '../../data/device_pairing_providers.dart';
import '../../data/device_pairing_service.dart';
import '../widgets/qr_display_widget.dart';
import '../widgets/qr_scanner_widget.dart';

/// Device pairing page with QR code generation and scanning.
class DevicePairingPage extends ConsumerStatefulWidget {
  const DevicePairingPage({super.key});
  
  @override
  ConsumerState<DevicePairingPage> createState() => _DevicePairingPageState();
}

class _DevicePairingPageState extends ConsumerState<DevicePairingPage> {
  bool _isShowingQR = true;
  
  @override
  void initState() {
    super.initState();
    // Generate pairing token on page load
    Future.microtask(() {
      ref.read(pairingTokenNotifierProvider.notifier).generateToken();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final isSyncEnabled = ref.watch(syncFeatureFlagProvider);
    final pairingTokenAsync = ref.watch(pairingTokenNotifierProvider);
    final deviceIdAsync = ref.watch(currentDeviceIdProvider);
    final syncState = ref.watch(syncStateProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('设备配对'),
        actions: [
          // Device name edit button
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showDeviceNameDialog(context),
            tooltip: '修改设备名称',
          ),
        ],
      ),
      body: isSyncEnabled 
          ? _buildContent(context, pairingTokenAsync, deviceIdAsync, syncState)
          : _buildSyncDisabled(context),
    );
  }
  
  Widget _buildContent(
    BuildContext context,
    AsyncValue<PairingToken?> pairingTokenAsync,
    AsyncValue<String> deviceIdAsync,
    SyncState syncState,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Sync status warning if not connected
          if (syncState != SyncState.connected)
            _buildSyncStatusWarning(context, syncState),
          
          // Toggle buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.qr_code),
                label: const Text('显示二维码'),
                onPressed: _isShowingQR ? null : () => setState(() => _isShowingQR = true),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('扫描二维码'),
                onPressed: _isShowingQR ? () => setState(() => _isShowingQR = false) : null,
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // QR display or scanner
          Expanded(
            child: _isShowingQR 
                ? _buildQRDisplay(context, pairingTokenAsync, deviceIdAsync)
                : _buildQRScanner(context),
          ),
          
          const SizedBox(height: 24),
          
          // Instructions
          Text(
            _isShowingQR 
                ? '在另一台设备上打开应用，进入同步设置，点击"配对设备"，然后扫描此二维码'
                : '扫描另一台设备上显示的配对二维码',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSyncStatusWarning(BuildContext context, SyncState syncState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              syncState == SyncState.disconnected 
                  ? '同步服务未连接，配对可能无法完成'
                  : '同步服务状态异常',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQRDisplay(
    BuildContext context,
    AsyncValue<PairingToken?> pairingTokenAsync,
    AsyncValue<String> deviceIdAsync,
  ) {
    return pairingTokenAsync.when(
      data: (token) {
        if (token == null) {
          return _buildTokenError(context, '无法生成配对码');
        }
        
        return deviceIdAsync.when(
          data: (deviceId) => QRDisplayWidget(
            serverUrl: token.serverUrl,
            pairingToken: token.token,
            deviceId: token.deviceId,
            expiresAt: token.expiresAt,
            onRegenerate: () {
              ref.read(pairingTokenNotifierProvider.notifier).generateToken();
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _buildTokenError(context, '无法获取设备信息'),
        );
      },
      loading: () => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在生成配对码...'),
          ],
        ),
      ),
      error: (e, _) => _buildTokenError(context, '生成配对码失败: $e'),
    );
  }
  
  Widget _buildTokenError(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(pairingTokenNotifierProvider.notifier).generateToken();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQRScanner(BuildContext context) {
    return QRScannerWidget(
      onPairingData: (data) => _handlePairingData(context, data),
      onCancel: () => setState(() => _isShowingQR = true),
    );
  }
  
  Widget _buildSyncDisabled(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sync_disabled,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '同步功能未启用',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '请先在同步设置中启用同步功能',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/settings/sync'),
            child: const Text('前往同步设置'),
          ),
        ],
      ),
    );
  }
  
  void _showDeviceNameDialog(BuildContext context) {
    final deviceName = ref.read(deviceNameNotifierProvider);
    final controller = TextEditingController(text: deviceName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设备名称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '设备名称',
            hintText: '输入设备名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref.read(deviceNameNotifierProvider.notifier).updateName(newName);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('设备名称已更新')),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _handlePairingData(BuildContext context, QRPairingData data) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final result = await ref.read(devicePairingNotifierProvider.notifier).completePairing(
        serverUrl: data.serverUrl,
        pairingToken: data.token,
        remoteDeviceId: data.deviceId,
      );
      
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('配对成功！设备: ${result.pairedDevice?.deviceName ?? "未知设备"}'),
              backgroundColor: Colors.green,
            ),
          );
          // Return to sync settings
          context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('配对失败: ${result.errorMessage ?? "未知错误"}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
          // Reset scanner
          setState(() {});
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('配对失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}