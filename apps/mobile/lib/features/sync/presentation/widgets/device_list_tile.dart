import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:sync/sync.dart';

/// List tile widget for displaying a registered sync device.
/// 
/// Shows device name, last sync time, and provides
/// options to manage the device.
class DeviceListTile extends StatelessWidget {
  /// The device to display.
  final SyncDevice device;
  
  /// Callback when device is tapped.
  final VoidCallback? onTap;
  
  /// Callback when device is removed.
  final VoidCallback? onRemove;

  const DeviceListTile({
    super.key,
    required this.device,
    this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Device icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getDeviceIcon(),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              
              // Device info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Device name
                    Text(
                      device.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    // Last sync time
                    Text(
                      _getLastSyncText(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    
                    // Public key indicator
                    if (device.hasPublicKey) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.verified_user,
                            size: 14,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '已加密',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              // Actions
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onRemove,
                  color: Theme.of(context).colorScheme.error,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getDeviceIcon() {
    final name = device.name.toLowerCase();
    
    if (name.contains('iphone') || name.contains('ios')) {
      return Icons.phone_iphone;
    }
    if (name.contains('android')) {
      return Icons.phone_android;
    }
    if (name.contains('ipad') || name.contains('tablet')) {
      return Icons.tablet;
    }
    if (name.contains('desktop') || name.contains('mac') || 
        name.contains('windows') || name.contains('linux')) {
      return Icons.computer;
    }
    
    return Icons.devices;
  }

  String _getLastSyncText() {
    if (device.lastSyncAt == null) {
      return '从未同步';
    }
    
    final now = DateTime.now();
    final difference = now.difference(device.lastSyncAt!);
    
    if (difference.inMinutes < 1) {
      return '刚刚同步';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} 分钟前同步';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} 小时前同步';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} 天前同步';
    } else {
      return DateFormat('yyyy-MM-dd').format(device.lastSyncAt!);
    }
  }
}