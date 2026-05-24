// DISABLED: sync package is temporarily disabled due to PowerSync compatibility issues
/*
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/sync_provider.dart';
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
  String? _pairingToken;
  DateTime? _tokenExpiresAt;
  
  @override
  void initState() {
    super.initState();
    _generatePairingToken();
  }
  
  Future<void> _generatePairingToken() async {
    // Call pairing API to generate token
    // Placeholder - actual implementation would call server API
    setState(() {
      _pairingToken = 'PAIR-${DateTime.now().millisecondsSinceEpoch % 100000000}';
      _tokenExpiresAt = DateTime.now().add(const Duration(minutes: 5));
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final config = ref.watch(syncConfigProvider);
    final deviceId = config?.deviceId ?? '';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('设备配对'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
            if (_isShowingQR && _pairingToken != null)
              QRDisplayWidget(
                serverUrl: config?.serverUrl ?? '',
                pairingToken: _pairingToken!,
                deviceId: deviceId,
                expiresAt: _tokenExpiresAt!,
                onRegenerate: _generatePairingToken,
              )
            else if (!_isShowingQR)
              QRScannerWidget(
                onPairingData: (data) => _handlePairingData(context, data),
                onCancel: () => setState(() => _isShowingQR = true),
              )
            else
              const Center(child: CircularProgressIndicator()),
            
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
      // Call pairing API to complete
      // Placeholder - actual implementation would call server API
      
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('配对成功！'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Return to sync settings
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('配对失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
*/
