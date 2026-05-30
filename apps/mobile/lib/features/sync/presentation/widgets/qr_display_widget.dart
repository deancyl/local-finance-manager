import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// QR code display widget for device pairing.
/// 
/// Shows QR code with pairing token and server URL.
/// 
/// QR payload format:
/// ```json
/// {
///   "type": "finance_app_pairing",
///   "token": "<JWT>",
///   "serverUrl": "https://sync.example.com",
///   "deviceId": "<UUID>",
///   "ts": "<timestamp>"
/// }
/// ```
class QRDisplayWidget extends StatelessWidget {
  /// The server URL for pairing.
  final String serverUrl;
  
  /// The pairing token.
  final String pairingToken;
  
  /// The device ID.
  final String deviceId;
  
  /// Expiration time for the QR code.
  final DateTime expiresAt;
  
  /// Callback to regenerate the QR code when expired.
  final VoidCallback? onRegenerate;

  const QRDisplayWidget({
    super.key,
    required this.serverUrl,
    required this.pairingToken,
    required this.deviceId,
    required this.expiresAt,
    this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final remainingSeconds = expiresAt.difference(DateTime.now()).inSeconds;
    final isExpired = remainingSeconds <= 0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.qr_code_2,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '设备配对',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '使用另一台设备扫描此二维码进行配对',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            
            // QR Code or Expired State
            if (isExpired)
              _buildExpiredState(context)
            else
              _buildQRCode(context, remainingSeconds),
            
            const SizedBox(height: 16),
            
            // Server URL
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.dns,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      serverUrl,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiredState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            '二维码已过期',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (onRegenerate != null)
            ElevatedButton.icon(
              onPressed: onRegenerate,
              icon: const Icon(Icons.refresh),
              label: const Text('重新生成'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQRCode(BuildContext context, int remainingSeconds) {
    return Column(
      children: [
        // QR Code Container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: QrImageView(
            data: _buildQRPayload(),
            version: QrVersions.auto,
            size: 200,
            errorCorrectionLevel: QrErrorCorrectLevel.H,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Expiry countdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getCountdownColor(context, remainingSeconds).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: _getCountdownColor(context, remainingSeconds),
              ),
              const SizedBox(width: 6),
              Text(
                '有效期: ${_formatRemaining(remainingSeconds)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _getCountdownColor(context, remainingSeconds),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        
        // Pairing token (for manual entry)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.vpn_key,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                pairingToken,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getCountdownColor(BuildContext context, int seconds) {
    if (seconds < 30) {
      return Theme.of(context).colorScheme.error;
    } else if (seconds < 60) {
      return const Color(0xFFFF9800); // Warning color
    }
    return Theme.of(context).colorScheme.primary;
  }

  /// Builds the QR payload according to the finance_app_pairing format.
  String _buildQRPayload() {
    final payload = {
      'type': 'finance_app_pairing',
      'token': pairingToken,
      'serverUrl': serverUrl,
      'deviceId': deviceId,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(payload);
  }

  String _formatRemaining(int seconds) {
    if (seconds < 60) return '$seconds 秒';
    final minutes = seconds / 60;
    return '${minutes.round()} 分钟';
  }
}
