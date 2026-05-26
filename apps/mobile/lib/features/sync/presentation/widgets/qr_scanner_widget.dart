import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// QR code scanner widget for device pairing.
class QRScannerWidget extends StatefulWidget {
  final Function(QRPairingData) onPairingData;
  final VoidCallback? onCancel;
  
  const QRScannerWidget({
    super.key,
    required this.onPairingData,
    this.onCancel,
  });
  
  @override
  State<QRScannerWidget> createState() => _QRScannerWidgetState();
}

class _QRScannerWidgetState extends State<QRScannerWidget> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  
  bool _scanned = false;
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '扫描配对二维码',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          '将另一台设备上的二维码放入框内',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        
        SizedBox(
          height: 300,
          width: 300,
          child: MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_scanned) return;
              
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleQRCode(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
        ),
        
        const SizedBox(height: 16),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.flash_off),
              onPressed: () => _controller.toggleTorch(),
            ),
            IconButton(
              icon: const Icon(Icons.cameraswitch),
              onPressed: () => _controller.switchCamera(),
            ),
            if (widget.onCancel != null)
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('取消'),
              ),
          ],
        ),
      ],
    );
  }
  
  void _handleQRCode(String data) {
    _scanned = true;
    _controller.stop();
    
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      
      // Validate QR payload
      if (json['v'] != 1) {
        _showError('无效的二维码版本');
        return;
      }
      
      final pairingData = QRPairingData(
        serverUrl: json['serverUrl'] as String,
        token: json['token'] as String,
        deviceId: json['deviceId'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int),
      );
      
      // Check if expired (5 minutes)
      final age = DateTime.now().difference(pairingData.timestamp);
      if (age.inMinutes > 5) {
        _showError('二维码已过期');
        return;
      }
      
      widget.onPairingData(pairingData);
    } catch (e) {
      _showError('无法解析二维码: ${e.toString()}');
    }
  }
  
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
      );
      _scanned = false;
      _controller.start();
    }
  }
}

/// QR pairing data extracted from scanned code.
class QRPairingData {
  final String serverUrl;
  final String token;
  final String deviceId;
  final DateTime timestamp;
  
  QRPairingData({
    required this.serverUrl,
    required this.token,
    required this.deviceId,
    required this.timestamp,
  });
}
